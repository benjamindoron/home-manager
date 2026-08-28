{ realPkgs, ... }:

{
  # A single-quoted string, so nothing appends a trailing newline. `types.lines`
  # does not add one either, and the guarded extra section has to terminate
  # itself regardless of how the value ends.
  home.sessionVariablesExtra = "export NO_EOL=1";

  nmt.script = ''
    hmSessVars=home-path/etc/profile.d/hm-session-vars.sh
    assertFileExists $hmSessVars

    # `fi` fused onto the last line of the extra would leave the guard open.
    assertFileRegex $hmSessVars '^fi$'

    ${realPkgs.dash}/bin/dash -n "$TESTED/$hmSessVars" \
      || fail "an extra without a trailing newline broke the generated file"

    env -u __HM_SESS_VARS_SOURCED -u __HM_SESS_VARS_MERGED \
      ${realPkgs.dash}/bin/dash -uc '
        . "$1"
        [ "$NO_EOL" = 1 ] || { echo "NO_EOL: <$NO_EOL>"; exit 1; }
        exit 0
      ' shell "$TESTED/$hmSessVars" \
      || fail "the extra section did not run"
  '';
}
