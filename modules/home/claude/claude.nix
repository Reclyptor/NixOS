{ ... }: {
  flake.modules.homeManager.base = { config, pkgs, lib, ... }: {
    # Declarative source of truth for ~/.claude/settings.json. Every Claude Code
    # feature merges its keys in here (this module's base settings, agentmemory's
    # lifecycle hooks, ...) and the merged attrset is serialized to a single JSON
    # file. Replaces the old runtime jq-merge activation scripts — composition now
    # happens in the module system, not at switch time.
    options.programs.claudeCode.settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Merged, declaratively-composed contents of ~/.claude/settings.json.";
    };

    # Separate list-merging option for hooks so feature modules can each contribute
    # hooks whose per-event lists CONCATENATE — home/agentmemory.nix wires both the
    # lifecycle hooks and the SessionStart directive-injection hook through it.
    # `settings` above is attrsOf-anything, which can't merge two list values at the
    # same path (it conflicts); `attrsOf (listOf ...)` concatenates.
    options.programs.claudeCode.hooks = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.anything);
      default = {};
      description = "Per-event Claude Code hook lists, merged across modules and folded into settings.json.";
    };

    config = {
      # Base Claude Code settings — the source of truth. Change values HERE, not via
      # /model or /config: the file below is a read-only store symlink, so a runtime
      # write can't survive a home-manager switch (same tradeoff as xdg.mimeApps).
      programs.claudeCode.settings = {
        model = "opus[1m]";
        effortLevel = "high";
        editorMode = "vim";
        skipDangerousModePermissionPrompt = true;
        # agentmemory (home/agentmemory.nix) is the only persistent-memory path, so
        # native Auto Memory stays off — otherwise it injects a "# Memory" section +
        # MEMORY.md index every session and writes markdown files under
        # ~/.claude/projects/*/memory/, biasing the agent toward files over the
        # agentmemory MCP tools.
        autoMemoryEnabled = false;
        # Environment injected into every Claude Code session. Agent Teams is an
        # experimental, off-by-default feature gated behind this flag; without it no
        # team spawning happens and no team directories are written.
        env = {
          CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
        };
        # Run teammates in split panes when the terminal supports it (tmux session
        # or iTerm2) instead of the default in-process runtime, falling back to
        # in-process otherwise. tmux on PATH is provided by home/tmux.nix.
        teammateMode = "auto";
      };

      # Serialize the merged attrset (this module + agentmemory + any future feature)
      # to ~/.claude/settings.json as a validated, read-only store file.
      home.file.".claude/settings.json".source =
        (pkgs.formats.json {}).generate "claude-settings.json"
          (config.programs.claudeCode.settings
            // lib.optionalAttrs (config.programs.claudeCode.hooks != {}) {
              hooks = config.programs.claudeCode.hooks;
            });

      # Global Claude Code directives, installed read-only as ~/.claude/CLAUDE.md so
      # they load as the user-level config for every session. Edit ./CLAUDE.md next
      # to this module, not the symlink.
      home.file.".claude/CLAUDE.md".source = ./CLAUDE.md;

      # User-scoped teammate/subagent definitions, installed read-only to
      # ~/.claude/agents/. Recursive so each file is symlinked individually — this
      # keeps the agents dir writable, letting runtime-created agents coexist with
      # these managed ones. Edit the .md files next to this module, not the symlinks.
      home.file.".claude/agents" = {
        source = ./agents;
        recursive = true;
      };
    };
  };
}
