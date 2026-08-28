{ realPkgs, ... }:

{
  # Its own test because `types.lines` joins definitions with a newline, which
  # would hide how the value ends. Here the last line is a continuation, so the
  # section terminator has to survive being spliced onto it.
  home.sessionVariablesExtra = ''
    export CONT=1 \
  '';

  nmt.script = ''
    hmSessVars=home-path/etc/profile.d/hm-session-vars.sh
    assertFileExists $hmSessVars

    # A trailing backslash would swallow `fi` as an argument to the last
    # command and leave the guard open.
    assertFileRegex $hmSessVars '^fi$'

    ${realPkgs.dash}/bin/dash -n "$TESTED/$hmSessVars" \
      || fail "an extra ending in a continuation broke the generated file"

    env -u __HM_SESS_VARS_SOURCED -u __HM_SESS_VARS_MERGED \
      ${realPkgs.dash}/bin/dash -uc '
        . "$1"
        [ "$CONT" = 1 ] || { echo "CONT: <$CONT>"; exit 1; }
        exit 0
      ' shell "$TESTED/$hmSessVars" \
      || fail "the extra section did not run"
  '';
}
