{
  time = "2026-08-27T14:00:00+00:00";
  condition = true;
  message = ''
    New shells now pick up session variables changed by `home-manager switch`
    without logging out. {file}`hm-session-vars.sh` is safe to apply again:
    plain variables are re-exported and search variables add only missing
    entries. Interactive non-login Bash shells follow in a separate change.

    {option}`home.sessionVariablesExtra` still runs once per session, since it
    holds arbitrary code that cannot be assumed repeatable.

    Removing a variable still requires a new session. Nothing records what a
    previous generation exported, so there is nothing to unset.
  '';
}
