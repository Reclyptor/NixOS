{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    jetbrains.clion
    jetbrains.datagrip
    jetbrains.goland
    jetbrains.idea
    jetbrains.phpstorm
    jetbrains.pycharm
    jetbrains.ruby-mine
    jetbrains.rust-rover
    jetbrains.webstorm
  ];
}
