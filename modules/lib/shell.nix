{ lib }:

let

  sessionSearchShell = import ./session-search-shell.nix { inherit lib; };

  mkShellIntegrationOption =
    name:
    {
      config,
      baseName ? name,
      extraDescription ? "",
    }:
    let
      attrName = "enable${baseName}Integration";
    in
    lib.mkOption {
      default = config.home.shell.${attrName};
      defaultText = lib.literalMD "[](#opt-home.shell.${attrName})";
      example = false;
      description = "Whether to enable ${name} integration.${
        lib.optionalString (extraDescription != "") ("\n\n" + extraDescription)
      }";
      type = lib.types.bool;
    };

  # Produces a Bourne shell like variable export statement.
  export =
    n: v:
    let
      value = if builtins.isBool v then lib.boolToString v else toString v;
    in
    ''export ${n}="${value}"'';

  # Wrap a list of strings to a given line width.
  # Packs as many items as possible per line without exceeding maxWidth.
  # Returns a list of strings, each representing a line.
  #
  # Example: wrapLines ["item1" "item2" "very-long-item" "item3"] 20
  #   => ["item1 item2" "very-long-item" "item3"]
  wrapLines =
    items: maxWidth:
    let
      step =
        acc: item:
        let
          potentialLine = if acc.currentLine == "" then item else "${acc.currentLine} ${item}";
        in
        if lib.stringLength potentialLine <= maxWidth then
          acc // { currentLine = potentialLine; }
        else
          acc
          // {
            finishedLines = acc.finishedLines ++ [ acc.currentLine ];
            currentLine = item;
          };
      foldResult = lib.foldl' step {
        finishedLines = [ ];
        currentLine = "";
      } items;
    in
    foldResult.finishedLines ++ lib.optional (foldResult.currentLine != "") foldResult.currentLine;
  # POSIX sh does not define local variables, so remove every scratch name after
  # all calls.
  mergeScratchVariables = [
    "__hm_mode"
    "__hm_name"
    "__hm_sep"
    "__hm_cur"
    "__hm_add"
    "__hm_entry"
    "__hm_reposition"
    "__hm_work"
    "__hm_pre"
    "__hm_post"
  ];

  # Double-quote entry values so expansions run when the block is sourced.
  mkMergeCall =
    mode: sep: name: values:
    lib.concatStringsSep " " (
      [
        "__hm_merge"
        mode
        name
        ''"${sessionSearchShell.escapeDoubleQuoted sep}"''
      ]
      ++ map (value: ''"${sessionSearchShell.escapeDoubleQuoted value}"'') values
    );

  mergeSearchVariables =
    {
      prepend ? { },
      append ? { },
    }:
    let
      mkCalls =
        mode: variables:
        lib.concatStringsSep "\n" (
          map (name: mkMergeCall mode ":" name variables.${name}) (lib.attrNames variables)
        );
      calls = lib.concatStringsSep "\n" (
        lib.filter (value: value != "") [
          (mkCalls "prepend" prepend)
          (mkCalls "append" append)
        ]
      );
    in
    if prepend == { } && append == { } then
      ""
    else
      ''
        ${builtins.readFile ./session-search-merge.sh}
        ${calls}
        export __HM_SESS_VARS_MERGED=1
        unset -f __hm_merge
        unset ${lib.concatStringsSep " " mergeScratchVariables}
      '';

  /*
    Best-effort check whether a session variable value references the variable
    it defines, such as `PATH = "$HOME/bin:$PATH"`. Such a value gains a copy
    of its previous contents every time the session variables file is applied
    in a new shell.

    Detects the direct forms `$NAME`, `''${NAME}` and `''${NAME:-...}`.
    Backslash escapes are honoured, so `\$NAME` is ignored while `\\$NAME`
    still counts, and `$$NAME` is the shell PID followed by literal text.
    Indirect forms, through `eval` or another variable, are not detected.

    A value that is exactly one default, alternate, or assign expansion of its
    own name, such as `''${NAME:-fallback}`, reaches a fixed point on the first
    application and is therefore not reported.

    # Type

    ```
    isSelfReferential :: String -> Any -> Bool
    ```
  */
  isSelfReferential =
    name: value:
    lib.isString value
    && (
      let
        # `\x` never expands and `$$` is the shell PID, so neither can start a
        # reference; strip them before looking for `$NAME`.
        plainParts = lib.filter lib.isString (builtins.split ''(\\.|[$][$])'' value);
        refers = part: builtins.match ".*[$][{]?${lib.escapeRegex name}([^A-Za-z0-9_].*)?" part != null;
        # The fallback word may itself contain a braced expansion, as in
        # ${NAME:-${HOME}/bin}, so allow one level of nesting there.
        converging =
          builtins.match "[$][{]${lib.escapeRegex name}:?[-+=?]([^{}]|[$][{][^{}]*[}])*[}]" value != null;
      in
      !converging && lib.any refers plainParts
    );

  /*
    Build the warning list for self-referential entries of a session-variable
    option. Shared so every shell that has its own `sessionVariables` reports
    the same thing.

    # Type

    ```
    selfReferenceWarnings :: { option, optionPath, rationale } -> [ String ]
    ```
  */
  selfReferenceWarnings =
    {
      option,
      optionPath,
      rationale,
    }:
    let
      offenders = lib.attrNames (lib.filterAttrs isSelfReferential option.value);
    in
    lib.optional (offenders != [ ]) ''
      The following ${optionPath} reference themselves:

        ${lib.concatStringsSep ", " offenders}

      ${lib.removeSuffix "\n" rationale}

      Use home.sessionPath, home.sessionSearchVariables, or
      home.sessionSearchVariablesAppend for search paths instead. Those add
      only the entries that are missing.

      Defined in ${lib.options.showFiles option.files}.

      This check is best-effort: only direct references such as $NAME,
      ''${NAME} and ''${NAME:-...} are detected.
    '';

in
{
  inherit
    export
    wrapLines
    isSelfReferential
    selfReferenceWarnings
    ;

  /**
    Generate a complete POSIX shell block that merges entries into
    colon-delimited search variables.

    Prepends run before appends. The generated block exports a process marker
    so later blocks preserve inherited entry positions.

    Entries are evaluated in a double-quoted shell context. Parameter and
    arithmetic expansions and both command-substitution forms stay active.
    Write `\"` for a literal `"`. Plain glob and tilde characters remain
    literal while the surrounding double-quoted context is intact.

    Returns an empty string when both attribute sets are empty.

    # Inputs

    `prepend`

    : Attribute set that maps variable names to entries added at the front

    `append`

    : Attribute set that maps variable names to entries added at the end

    # Type

    ```
    mergeSearchVariables :: { prepend ? AttrSet [ String ], append ? AttrSet [ String ] } -> String
    ```
  */
  inherit mergeSearchVariables;

  # Given an attribute set containing shell variable names and their
  # assignment, this function produces a string containing an export
  # statement for each set entry.
  exportAll =
    vars:
    lib.concatStringsSep "\n" (lib.mapAttrsToList export (lib.filterAttrs (_k: v: v != null) vars));

  # Formats a list of items for shell array content with intelligent width optimization.
  # IMPORTANT: This formats the CONTENTS of an array (what goes inside parentheses),
  # not a complete array definition. Use lib.hm.zsh.define for complete definitions.
  #
  # Uses lib.escapeShellArg for robust shell escaping (handles spaces, quotes, special chars).
  # Packs multiple items per line to optimize terminal width (~78 chars per line).
  # Short arrays (≤3 items, ≤80 chars total) use single-line format.
  #
  # Example outputs:
  #   Empty:       ""
  #   Simple:      item1 item2 item3
  #   With spaces: 'item one' 'item two' 'item three'
  #   Long arrays: \n  item1 item2 item3\n  item4 item5\n
  #
  # Built from composable helpers: wrapLines, formatMultiLine
  formatShellArrayContent =
    items:
    let
      quotedItems = lib.map lib.escapeShellArg items;
      formatMultiLine = lines: "\n  ${lib.concatStringsSep "\n  " lines}\n";
      wrapped = wrapLines quotedItems 78;
    in
    formatMultiLine wrapped;

  mkBashIntegrationOption = mkShellIntegrationOption "Bash";
  mkFishIntegrationOption = mkShellIntegrationOption "Fish";
  mkIonIntegrationOption = mkShellIntegrationOption "Ion";
  mkNushellIntegrationOption = mkShellIntegrationOption "Nushell";
  mkZshIntegrationOption = mkShellIntegrationOption "Zsh";
}
