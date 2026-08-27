{ config, lib, ... }:

let
  # Evaluate a synthetic option so the test covers the shared helper, including
  # its file attribution, without depending on any one module's warning list.
  eval = lib.evalModules {
    modules = [
      {
        options.demo = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
        };
      }
      (lib.setDefaultModuleLocation "/fake/offender.nix" {
        demo.PATH = "$HOME/bin:$PATH";
        demo.FINE = "/plain/value";
      })
      (lib.setDefaultModuleLocation "/fake/other.nix" { demo.ALSO_FINE = "\${PATH:-/bin}"; })
    ];
  };

  warnings = config.lib.shell.selfReferenceWarnings {
    option = eval.options.demo;
    optionPath = "demo";
    rationale = "Because reasons.";
  };
in
{
  assertions = [
    {
      assertion = builtins.length warnings == 1;
      message = "expected exactly one warning, got ${toString (builtins.length warnings)}";
    }
    {
      # Only the growing value is reported; the converging one is not.
      assertion = lib.hasInfix "PATH" (builtins.head warnings);
      message = "warning did not name PATH";
    }
    {
      assertion = !lib.hasInfix "FINE" (builtins.head warnings);
      message = "warning wrongly named a value that does not self-reference";
    }
    {
      assertion = lib.hasInfix "/fake/offender.nix" (builtins.head warnings);
      message = "warning did not attribute the defining file";
    }
    {
      assertion = lib.hasInfix "Because reasons." (builtins.head warnings);
      message = "warning dropped the caller-supplied rationale";
    }
  ];

  nmt.script = ''
    echo "self-reference warning checked" >/dev/null
  '';
}
