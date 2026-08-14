{ ... }:

# The login account, defined once for every machine. workstation/users.nix and
# server/users.nix were byte-identical apart from the class they attached to —
# the same drift risk kube-api-lb.nix already solves by binding once and
# assigning to both classes, so this follows that pattern.
#
# The authorizedKeys entry is inert on the workstation (it runs no sshd) and
# load-bearing on the five cluster nodes. Sharing it costs nothing and means
# the key is already in place if sshd is ever enabled there.
let
  user =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      users.users.reclyptor = {
        isNormalUser = true;
        shell = pkgs.bash;
        description = "Reclyptor";

        extraGroups = [
          "reclyptor"
          "networkmanager"
          "wheel"
          "cdrom"
        ]
        # "docker" was previously unconditional even though virtualisation.docker
        # is workstation-only. Harmless in practice — NixOS drops groups that
        # aren't defined on the host when it generates users-groups.json, verified
        # by the store path being identical on a server with and without it — but
        # the declaration claimed something untrue. Now it says what it means.
        ++ lib.optional config.virtualisation.docker.enable "docker";

        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO+1lRwgeyXwQATyVsXL+zXsnkZr5UHqeGGPn+G97yH1"
        ];
      };
    };
in
{
  flake.modules.nixos.server = user;
  flake.modules.nixos.workstation = user;
}
