_: {
  flake.modules.homeManager.base =
    { pkgs, lib, ... }:
    let
      host = "127.0.0.1";
      port = "9222";
      endpoint = "${host}:${port}";
    in
    {
      # The one browser every agent drives. Obscura speaks CDP only, so agents
      # attach to this server instead of launching a browser of their own.
      # Loopback-only and unauthenticated: OBSCURA_CDP_TOKEN is only mandatory
      # off loopback.
      #
      # Each CDP connection gets its own tabs and cookie jar, so concurrent
      # agents never steer each other's pages. Cookies reach the storage dir
      # after every navigation and are loaded when the service starts, so a
      # login survives restarts and is then shared by every agent.
      systemd.user.services.obscura = {
        Unit.Description = "Obscura headless browser (CDP on ${endpoint})";
        Service = {
          # %S is $XDG_STATE_HOME; StateDirectory creates it before start.
          StateDirectory = "obscura";
          ExecStart = lib.concatStringsSep " " [
            (lib.getExe pkgs.obscura)
            "serve"
            "--host ${host}"
            "--port ${port}"
            "--storage-dir %S/obscura"
            # Consistent fingerprint, TLS impersonation and tracker blocking.
            "--stealth"
            # Its SSRF guard blocks loopback and LAN targets by default, which
            # would keep agents off the dev servers they are testing.
            "--allow-private-network"
          ];
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
}
