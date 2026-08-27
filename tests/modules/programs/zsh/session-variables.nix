{ config, ... }:

{
  programs.zsh = {
    enable = true;

    sessionVariables = {
      PATH = "$HOME/bin:$PATH";
      V1 = "v1";
      V2 = "v2-${config.programs.zsh.sessionVariables.V1}";
      IS_EMPTY = "";
      IS_NULL = null;
      IS_FALSE = false;
      IS_TRUE = true;
    };
  };

  # PATH here is deliberately the self-referential idiom, so this doubles as
  # coverage that the warning fires and names the offending variable.
  test.asserts.warnings.expected = [
    ''
      The following programs.zsh.sessionVariables reference themselves:

        PATH

      Zsh session variables are re-applied for each new Zsh process,
      so a value that includes its own previous contents grows with
      every nested shell.

      Use home.sessionPath, home.sessionSearchVariables, or
      home.sessionSearchVariablesAppend for search paths instead. Those add
      only the entries that are missing.

      Defined in `${toString ./session-variables.nix}'.

      This check is best-effort: only direct references such as $NAME,
      ''${NAME} and ''${NAME:-...} are detected.
    ''
  ];

  nmt.script = ''
    assertFileExists home-files/.zshenv
    assertFileContent $(normalizeStorePaths home-files/.zshenv) ${./session-variables.zshenv}
    assertFileExists home-files/.zprofile
    assertFileContent $(normalizeStorePaths home-files/.zprofile) ${./session-variables.zprofile}
  '';
}
