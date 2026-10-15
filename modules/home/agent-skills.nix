_: {
  flake.modules.homeManager.base =
    { config, lib, ... }:
    let
      # Each agent's global skill directory. Prime Agent's is its agent dir's
      # skills/; dsh scans $DSH_HOME/skills through its filesystem skill
      # provider; Copilot's is its personal ~/.copilot/skills.
      skillDirs = {
        claude = ".claude/skills";
        codex = ".codex/skills";
        dsh = ".dsh/skills";
        copilot = ".copilot/skills";
        prime = ".prime/agent/skills";
      };
    in
    {
      options.agentSkills = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              source = lib.mkOption {
                type = lib.types.path;
                description = "Directory holding the skill's SKILL.md.";
              };

              excludeAgents = lib.mkOption {
                type = lib.types.listOf (lib.types.enum (lib.attrNames skillDirs));
                default = [ ];
                description = ''
                  Agents the skill is not linked into, such as one that lacks
                  the MCP server the skill drives.
                '';
              };
            };
          }
        );
        default = { };
        description = ''
          Skills linked read-only into every agent's skill directory unless
          the skill excludes it, keyed by the directory name the link gets.
          The slash command comes from each skill's SKILL.md frontmatter name,
          not this key. Linking per skill leaves the parent directories
          writable for hand-placed skills.
        '';
      };

      config.home.file = lib.listToAttrs (
        lib.concatLists (
          lib.mapAttrsToList (
            agent: dir:
            lib.mapAttrsToList (name: skill: {
              name = "${dir}/${name}";
              value.source = skill.source;
            }) (lib.filterAttrs (_: skill: !lib.elem agent skill.excludeAgents) config.agentSkills)
          ) skillDirs
        )
      );
    };
}
