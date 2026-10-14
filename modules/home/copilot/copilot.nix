_: {
  flake.modules.homeManager.base =
    { config, lib, ... }:
    let
      inherit (config.programs.copilotCli) hooks;
    in
    {
      # Per-event Copilot CLI hook lists, the twin of programs.claudeCode.hooks
      # and programs.codexCli.hooks: attrsOf (listOf ...) concatenates, so
      # agentmemory, herdr and the mascot each contribute without knowing about
      # one another.
      #
      # Entries use Copilot's native flat shape ({type, bash, timeoutSec,
      # matcher}). Prefer the PascalCase event names where Copilot has them:
      # those deliver Claude-shaped snake_case payloads (session_id, cwd,
      # tool_name), which every script here already reads. subagentStart and
      # notification exist only in camelCase.
      #
      # A SessionStart hook only reaches the model through JSON
      # {"additionalContext": "..."} on stdout; plain text is silently dropped.
      options.programs.copilotCli.hooks = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.anything);
        default = { };
        description = "Per-event Copilot CLI hook lists, merged across modules and rendered to ~/.copilot/hooks/home-manager.json.";
      };

      config = {
        # Global Copilot CLI directives, installed read-only as
        # ~/.copilot/copilot-instructions.md, the user-level instructions file every
        # session loads. Edit ./copilot-instructions.md next to this module.
        home.file.".copilot/copilot-instructions.md".source = ./copilot-instructions.md;

        # Copilot loads every *.json in ~/.copilot/hooks and combines them with
        # hooks from settings.json, repositories and plugins, so a file of its own
        # leaves settings.json to Copilot and the user.
        home.file.".copilot/hooks/home-manager.json" = lib.mkIf (hooks != { }) {
          text = builtins.toJSON {
            version = 1;
            inherit hooks;
          };
        };
      };
    };
}
