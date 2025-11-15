{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    jetbrains.clion
    jetbrains.datagrip
    jetbrains.goland
    jetbrains.idea-ultimate
    jetbrains.phpstorm
    jetbrains.pycharm-professional
    jetbrains.ruby-mine
    jetbrains.rust-rover
    jetbrains.webstorm
  ];
}
