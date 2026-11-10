_: {
  # Keeps every coding agent off the user's YubiKey. Agent sessions kept
  # stopping for a touch, from `ssh` through gpg-agent's card-backed key, from
  # `sops decrypt` through the age-plugin-yubikey stub, and from `git commit -S`
  # through gpg. Each agent has its own seam, so this module owns the shared
  # pieces and wires all five (Claude Code, Codex, Copilot CLI, Prime Agent,
  # dsh) the way claude/mascot.nix wires its three.
  #
  # Two layers, because neither holds alone. The environment and the PATH shims
  # make the commands fail closed. The hook refuses them first, with a message
  # naming the alternative, so the agent learns why instead of retrying
  # variations. The hook fails open in some harnesses (Codex and dsh treat any
  # exit but 2 as allow, Copilot allows on timeout), which is why the shims are
  # not optional. None of this is a security boundary: it stops accidental
  # prompts, not a determined agent.
  flake.modules.homeManager.base =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      tokenFile = config.sops.secrets."bash/github-token".path;

      # What each guarded command is refused for. The hook messages and the
      # shim messages both come from here, so the wording lives in one place.
      rules = {
        ssh = {
          names = [
            "ssh"
            "scp"
            "sftp"
            "ssh-add"
          ];
          subject = "ssh";
          instead = "Reach nodes with kubectl exec or a privileged debug pod. Git to GitHub already runs over HTTPS with the token in this session.";
        };
        card = {
          names = [
            "gpg"
            "gpg2"
            "pass"
            "ykman"
            "age-plugin-yubikey"
          ];
          subject = "this command";
          instead = "Find another route, or tell the user what is needed instead of prompting them.";
        };
        sops = {
          names = [ "sops" ];
          subject = "sops decryption";
          instead = "Encrypting needs only the public recipients: take the plaintext from the live cluster Secret (kubectl get secret -o jsonpath | base64 -d) and pipe it into sops encrypt --filename-override <dest>.";
          # The subcommands that never need an identity.
          allowed = [
            "encrypt"
            "-e"
            "--encrypt"
            "--version"
            "filestatus"
          ];
        };
      };

      message =
        subject: instead:
        "Blocked: ${subject} needs the user's YubiKey, and agents must never cause a YubiKey prompt. ${instead}";

      alternation = lib.concatStringsSep "|";

      # Every agent's PreToolUse payload carries the command at
      # .tool_input.command, so one script serves all of them. Exit 2 blocks in
      # all four hook systems, with stderr as the reason; Copilot reads its
      # reason from a deny decision on stdout instead, which the others ignore.
      hook = pkgs.writeShellApplication {
        name = "agent-yubikey-guard";
        runtimeInputs = [ pkgs.jq ];
        text = ''
          cmd=$(jq -r '.tool_input.command // empty')
          [ -n "$cmd" ] || exit 0

          # Command position: start of the line or after a separator, optionally
          # behind wrappers that run their argument as a command.
          lead='(^|[;&|`(]|\$\()[[:space:]]*((sudo|env|exec|time|nohup|command|xargs|timeout[[:space:]]+[^[:space:]]+)[[:space:]]+)*'

          deny() {
            local msg="$1"
            printf '%s\n' "$msg" >&2
            jq -n --arg r "$msg" '{permissionDecision: "deny", permissionDecisionReason: $r}'
            exit 2
          }

          if grep -Eq "''${lead}(${alternation rules.ssh.names})([[:space:]]|$)" <<<"$cmd"; then
            deny ${lib.escapeShellArg (message rules.ssh.subject rules.ssh.instead)}
          fi
          if grep -Eq "''${lead}(${alternation rules.card.names})([[:space:]]|$)" <<<"$cmd"; then
            deny ${lib.escapeShellArg (message rules.card.subject rules.card.instead)}
          fi
          if grep -Eq "''${lead}sops([[:space:]]|$)" <<<"$cmd" \
            && ! grep -Eq "''${lead}sops[[:space:]]+(${alternation rules.sops.allowed})([[:space:]]|$)" <<<"$cmd"; then
            deny ${lib.escapeShellArg (message rules.sops.subject rules.sops.instead)}
          fi
          exit 0
        '';
      };

      # Stand-ins for the guarded commands, placed ahead of the real ones on
      # PATH. They catch what the hook cannot see: Prime Agent has no hook at
      # all, its model runs Python, and `subprocess.run(["ssh", ...])` still
      # resolves through PATH. Exit 126 is "found but cannot execute".
      refuse =
        name: rule:
        pkgs.writeShellScriptBin name ''
          echo ${lib.escapeShellArg (message name rule.instead)} >&2
          exit 126
        '';

      refusing = lib.concatMap (rule: map (name: refuse name rule) rule.names) [
        rules.ssh
        rules.card
      ];

      # sops encrypts with the recipients in .sops.yaml alone, so it keeps
      # working. The age identity file is pinned here rather than only in the
      # environment because Codex and dsh strip any variable whose name
      # contains KEY before a command starts; without it sops would fall back
      # to ~/.config/sops/age/keys.txt, whose first identity is the yubikey
      # stub, which is the very prompt this exists to prevent.
      sopsShim = pkgs.writeShellScriptBin "sops" ''
        case "''${1:-}" in
          ${alternation rules.sops.allowed})
            SOPS_AGE_KEY_FILE=/dev/null exec ${lib.getExe pkgs.sops} "$@"
            ;;
        esac
        echo ${lib.escapeShellArg (message rules.sops.subject rules.sops.instead)} >&2
        exit 126
      '';

      shims = pkgs.symlinkJoin {
        name = "agent-yubikey-shims";
        paths = refusing ++ [ sopsShim ];
      };

      # Every GitHub remote is SSH. Rewriting to HTTPS and answering
      # credentials from the token file makes plain fetch, push and clone work
      # without the YubiKey. The helper reads the file at call time, so the
      # token is never in the store. Carried by GIT_CONFIG_GLOBAL rather than
      # GIT_CONFIG_COUNT/KEY/VALUE: Codex and dsh strip the *_KEY_n names but
      # keep the count, which makes every git command fail with "missing config
      # key". The include keeps the user's own identity and lfs settings.
      #
      # gpg.program matters because `git commit -S` and `git tag -s` reach the
      # card through gpg without ever naming it on the command line, so the
      # hook cannot see them. A store file also makes `git config --global`
      # writes fail, which is fine for an agent.
      gitConfig = pkgs.writeText "agent-gitconfig" ''
        [include]
        	path = ${config.xdg.configHome}/git/config
        [url "https://github.com/"]
        	insteadOf = git@github.com:
        	insteadOf = ssh://git@github.com/
        [credential "https://github.com"]
        	helper = "!f() { test \"$1\" = get || exit 0; echo username=x-access-token; printf 'password=%s\\n' \"$(cat ${tokenFile})\"; }; f"
        [gpg]
        	program = ${shims}/bin/gpg
      '';

      env = {
        # A dead but non-empty path. An empty SSH_AUTH_SOCK looks equivalent,
        # but /etc/set-environment refills it from gpgconf in any login shell
        # that starts without the inherited __NIXOS_SET_ENVIRONMENT_DONE guard,
        # which brings back the card-backed key. ssh just reports it cannot
        # reach an agent and falls back to identity files, and ~/.ssh has none.
        SSH_AUTH_SOCK = "/dev/null";
        # No identities, so sops fails at once instead of launching the plugin.
        SOPS_AGE_KEY_FILE = "/dev/null";
        GIT_CONFIG_GLOBAL = "${gitConfig}";
        # gpg cannot create its homedir here, so a direct call by absolute path
        # fails before it talks to the card.
        GNUPGHOME = "/var/empty";
      };

      # For agents with no env seam of their own. Wraps every launcher in the
      # package with the env and the shims.
      wrap =
        pkg:
        pkgs.symlinkJoin {
          name = "${pkg.name}-yubikey-guarded";
          paths = [ pkg ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            for exe in $out/bin/*; do
              wrapProgram "$exe" ${
                lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "--set ${k} ${lib.escapeShellArg v}") env)
              } --prefix PATH : ${shims}/bin
            done
          '';
          inherit (pkg) meta;
          passthru = (pkg.passthru or { }) // {
            unwrapped = pkg;
          };
        };

      # The Claude Code hook shape, shared by Claude, Codex and the dsh bridge.
      claudeShapedHook = matcher: [
        {
          inherit matcher;
          hooks = [
            {
              type = "command";
              command = lib.getExe hook;
            }
          ];
        }
      ];
    in
    {
      options.yubikeyGuard = lib.mkOption {
        type = lib.types.attrs;
        readOnly = true;
        description = "The guard's building blocks: hook, shims, gitConfig, env and wrap.";
      };

      config = {
        yubikeyGuard = {
          inherit
            hook
            shims
            gitConfig
            env
            wrap
            ;
        };

        programs.claudeCode.hooks.PreToolUse = claudeShapedHook "Bash";
        programs.claudeCode.settings.env = env;

        programs.codexCli.hooks.PreToolUse = claudeShapedHook "Bash";
        programs.codexCli.shellEnvironment.set = env;

        programs.copilotCli.hooks.PreToolUse = [
          {
            type = "command";
            bash = lib.getExe hook;
            matcher = "Bash";
            timeoutSec = 10;
          }
        ];

        # dsh mounts no hook runner by default. The Claude Code bridge is in the
        # installation's closure, and its bash tool is named in lowercase.
        deepseek.insertRows = [
          {
            id = "yubikey-guard";
            name = "@deepseek-ai/dsh-hooks-claude-code";
            config.configPath = "${pkgs.writeText "dsh-yubikey-guard-hooks.json" (
              builtins.toJSON { hooks.PreToolUse = claudeShapedHook "bash"; }
            )}";
          }
        ];

        # Copilot, Prime Agent and dsh read their environment from the process,
        # so they are launched through the wrapper. The bare binaries are gone
        # from environment.systemPackages (workstation/devtools.nix) so nothing
        # can reach an unguarded copy.
        home.packages = map wrap [
          pkgs.github-copilot-cli
          pkgs.prime-agent
          pkgs.dsh
        ];
      };
    };
}
