_: {
  flake.modules.homeManager.base = _: {
    programs.tmux = {
      enable = true;

      # Without mouse mode tmux never requests wheel events, so the terminal
      # (kitty) sits in the alternate screen and its alternate_scroll fallback
      # translates the wheel into arrow-key sequences that leak into the shell.
      # Turning mouse mode on makes tmux capture the wheel and enter copy-mode
      # over the pane's real scrollback instead.
      mouse = true;

      # vim-style pane resizing alongside tmux's built-in arrow bindings:
      # prefix + shift + hjkl matches prefix + M-<arrow> (5 cells).
      extraConfig = ''
        bind -r H resize-pane -L 5
        bind -r J resize-pane -D 5
        bind -r K resize-pane -U 5
        bind -r L resize-pane -R 5
      '';
    };
  };
}
