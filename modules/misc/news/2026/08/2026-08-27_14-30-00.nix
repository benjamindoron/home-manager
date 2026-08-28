{ config, ... }:
{
  time = "2026-08-27T14:30:00+00:00";
  condition = config.programs.bash.enable;
  message = ''
    Interactive non-login Bash shells now apply the session variables file, so
    a new terminal picks up values changed by `home-manager switch` instead of
    keeping whatever the session it started from had.

    If {option}`programs.bash.profileExtra` sets a variable that Home Manager
    also manages, that assignment no longer survives into those shells: Home
    Manager's value is applied again after login. Move the override to
    {option}`programs.bash.initExtra`, which runs after the refresh and only
    for interactive shells.

    Login shells and non-interactive shells are unaffected.
  '';
}
