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

      # vim-style pane focus and resizing alongside tmux's built-in arrow
      # bindings. Focus takes no -r: within repeat-time a letter typed right
      # after switching panes would be read as another switch rather than reach
      # the shell. Resize keeps it, as prefix + shift + hjkl matches
      # prefix + M-<arrow> (5 cells).
      #
      # l was tmux's last-window, which moves to backtick; herdr binds the same
      # key to its last_tab so both multiplexers share the reflex.
      extraConfig = ''
        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R
        bind ` last-window
        bind -r H resize-pane -L 5
        bind -r J resize-pane -D 5
        bind -r K resize-pane -U 5
        bind -r L resize-pane -R 5
        bind g choose-tree -Z
        bind s set-window-option synchronize-panes
      '';
    };
  };
}
