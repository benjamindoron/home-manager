if [[ ! -o login ]]; then
  # Environment variables
  . "/nix/store/00000000000000000000000000000000-hm-session-vars.sh/etc/profile.d/hm-session-vars.sh"

  # Re-apply Zsh-specific values once per Zsh process, after the
  # generic file. Not exported: a nested Zsh must apply them too, or it
  # would keep whatever the parent had.
  if [[ -z "${__HM_ZSH_SESS_VARS_SOURCED-}" ]]; then
    __HM_ZSH_SESS_VARS_SOURCED=1
    export IS_EMPTY=""
    export IS_FALSE=false
    export IS_TRUE=true
    export PATH="$HOME/bin:$PATH"
    export V1="v1"
    export V2="v2-v1"
  fi
fi
