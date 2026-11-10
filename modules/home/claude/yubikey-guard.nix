_: {
  flake.modules.homeManager.base =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      tokenFile = config.sops.secrets."bash/github-token".path;

      # Refuses Bash commands that can only finish by asking the user to touch
      # or unlock the YubiKey. The environment below already makes those
      # commands fail; this exists so the agent learns why, and what to use
      # instead, rather than retrying variations.
      guard = pkgs.writeShellApplication {
        name = "claude-yubikey-guard";
        runtimeInputs = [ pkgs.jq ];
        text = ''
          cmd=$(jq -r '.tool_input.command // empty')
          [ -n "$cmd" ] || exit 0

          # Command position: start of the line or after a separator, optionally
          # behind wrappers that run their argument as a command.
          lead='(^|[;&|`(]|\$\()[[:space:]]*((sudo|env|exec|time|nohup|command|xargs|timeout[[:space:]]+[^[:space:]]+)[[:space:]]+)*'

          deny() {
            printf '%s\n' "Blocked: $1 needs the user's YubiKey, and agents must never cause a YubiKey prompt. $2" >&2
            exit 2
          }

          if grep -Eq "''${lead}(ssh|scp|sftp|ssh-add)([[:space:]]|$)" <<<"$cmd"; then
            deny "ssh" "Reach nodes with kubectl exec or a privileged debug pod. Git to GitHub already runs over HTTPS with the token in this session."
          fi
          if grep -Eq "''${lead}(gpg|gpg2|pass|ykman|age-plugin-yubikey)([[:space:]]|$)" <<<"$cmd"; then
            deny "this command" "Find another route, or tell the user what is needed instead of prompting them."
          fi
          if grep -Eq "''${lead}sops([[:space:]]|$)" <<<"$cmd" \
            && ! grep -Eq "''${lead}sops[[:space:]]+(encrypt|-e|--encrypt|--version|filestatus)([[:space:]]|$)" <<<"$cmd"; then
            deny "sops decryption" "Encrypting needs only the public recipients: take the plaintext from the live cluster Secret (kubectl get secret -o jsonpath | base64 -d) and pipe it into sops encrypt --filename-override <dest>."
          fi
          exit 0
        '';
      };
    in
    {
      programs.claudeCode.hooks.PreToolUse = [
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = lib.getExe guard;
            }
          ];
        }
      ];

      programs.claudeCode.settings.env = {
        # With no agent socket, ssh cannot reach the card-backed key at all.
        SSH_AUTH_SOCK = "";
        # The first identity in keys.txt is the age-plugin-yubikey stub, so any
        # decrypt can stop for a touch. Without identities, sops fails at once;
        # encryption needs only the recipients in .sops.yaml and keeps working.
        SOPS_AGE_KEY_FILE = "/dev/null";
        # Every GitHub remote is SSH. Rewriting to HTTPS and answering
        # credentials from the token file makes plain fetch, push and clone work
        # without the YubiKey. The helper reads the file at call time, so the
        # token is never in the store or in settings.json.
        GIT_CONFIG_COUNT = "3";
        GIT_CONFIG_KEY_0 = "url.https://github.com/.insteadOf";
        GIT_CONFIG_VALUE_0 = "git@github.com:";
        GIT_CONFIG_KEY_1 = "url.https://github.com/.insteadOf";
        GIT_CONFIG_VALUE_1 = "ssh://git@github.com/";
        GIT_CONFIG_KEY_2 = "credential.https://github.com.helper";
        GIT_CONFIG_VALUE_2 = ''!f() { test "$1" = get || exit 0; echo username=x-access-token; printf 'password=%s\n' "$(cat ${tokenFile})"; }; f'';
      };
    };
}
