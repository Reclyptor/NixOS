_: {
  flake.modules.homeManager.base = _: {
    # Global Copilot CLI directives, installed read-only as
    # ~/.copilot/copilot-instructions.md, the user-level instructions file every
    # session loads. Edit ./copilot-instructions.md next to this module.
    home.file.".copilot/copilot-instructions.md".source = ./copilot-instructions.md;
  };
}
