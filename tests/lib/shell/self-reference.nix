{ config, ... }:

let
  f = config.lib.shell.isSelfReferential;

  cases = {
    # Grows on every application.
    "$HOME/bin:$PATH" = true;
    "\${PATH}:/x" = true;
    "\${PATH:-/bin}:/suffix" = true;
    "\${PATH:-\${HOME}/bin}:/x" = true;
    "prefix$PATH" = true;

    # Converges after the first application, so not reported.
    "\${PATH:-/bin}" = false;
    "\${PATH:-\${HOME}/bin}" = false;
    "\${PATH:+:}" = false;
    "\${PATH:=/bin}" = false;

    # Not a reference to PATH at all.
    "$FOOBAR" = false;
    "\${PATH_EXTRA}" = false;
    "$PATHOLOGICAL" = false;
    "\\$PATH" = false;
    "$$PATH" = false;
    "/x/man:" = false;
  };

  wrong = builtins.filter (value: (f "PATH" value) != cases.${value}) (builtins.attrNames cases);
in
{
  # Non-string values are never reported.
  assertions = [
    {
      assertion = !(f "PATH" 42) && !(f "PATH" true) && !(f "PATH" null);
      message = "isSelfReferential reported a non-string value";
    }
    {
      assertion = wrong == [ ];
      message = "isSelfReferential disagreed for: ${toString wrong}";
    }
  ];

  nmt.script = ''
    echo "isSelfReferential checked ${toString (builtins.length (builtins.attrNames cases))} cases" >/dev/null
  '';
}
