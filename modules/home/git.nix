_: {
  flake.modules.homeManager.base = _: {
    programs.git = {
      enable = true;
      signing.format = null;

      # Global excludes (~/.config/git/ignore). Was a hand-written file holding
      # a single **/.claude/settings.local.json line — now declared here so it
      # is reproducible instead of drifting per machine.
      #
      # These are per-session agent working state, never part of a project.
      # Ignoring the directories subsumes that old settings.local.json rule.
      # Note this is a machine-wide default: a repo that genuinely wants to
      # track its own .claude/ (shared skills, team settings) needs `git add -f`
      # or a negating rule in its local .gitignore.
      ignores = [
        ".claude/"
        ".codex/"
        ".crush/"
      ];
      settings = {
        user.name = "Reclyptor";
        user.email = "5952751+Reclyptor@users.noreply.github.com";
        user.signingkey = "0A839138373B99EE";
        init.defaultBranch = "master";
        commit.gpgsign = false;
        gpg.program = "gpg";
        core.editor = "nvim";
      };
    };
  };
}
