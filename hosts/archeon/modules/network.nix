{ pkgs, ... }:

# This node has two NICs on the same 192.168.1.0/24 and BOTH must stay reachable
# simultaneously: eno1 (wired, node IP / k3s path) and wlp2s0 (wireless, OOB
# lifeline). Three things are needed for that to hold across reboots/rebuilds:
#
#  1. dad-timeout=0 — the newer NetworkManager runs DHCP Address Conflict
#     Detection; on the Cilium-managed wired NIC the probe for the node's own
#     reserved IP gets answered, so NM declines the lease ("acd failed") and
#     takes a pool IP. Disabling ACD makes NM accept the reserved address.
#  2. arp_ignore/arp_announce — two NICs on one subnet otherwise answer ARP for
#     each other's IPs (flux), so the switch learns an IP against the wrong MAC.
#     Each NIC now answers ARP only for an address configured on it. Scoped
#     per-interface so Cilium's cilium_*/lxc* datapath is untouched.
#  3. source-based policy routing — with one subnet the main table has a single
#     preferred NIC, so replies sourced from the other NIC egress the wrong
#     interface (asymmetric) and that IP goes dark. A per-NIC table + a
#     `from <ip>` rule sends each address's replies back out its own NIC, so
#     both .10 (wired) and .20 (wireless) are reachable at the same time.

let
  wiredIf = "eno1";
  wirelessIf = "wlp2s0";
  wiredIp = "192.168.1.10";
  wirelessIp = "192.168.1.20";
  gateway = "192.168.1.254";
  lan = "192.168.1.0/24";
  ipBin = "${pkgs.iproute2}/bin/ip";

  pbr = pkgs.writeShellScript "dual-nic-pbr" ''
    setup() {
      dev="$1"; addr="$2"; table="$3"; prio="$4"
      ${ipBin} link show "$dev" >/dev/null 2>&1 || return 0
      # cluster-internal traffic from the node IP must defer to Cilium's routes in
      # the main table — `throw` falls through to the next rule, not the LAN default.
      ${ipBin} route replace throw 10.42.0.0/16 table "$table" || true
      ${ipBin} route replace throw 10.43.0.0/16 table "$table" || true
      ${ipBin} route replace ${lan} dev "$dev" src "$addr" table "$table" || true
      ${ipBin} route replace default via ${gateway} dev "$dev" table "$table" || true
      # delete ONLY our own rule (full match, not by bare priority) ...
      ${ipBin} rule del from "$addr"/32 table "$table" priority "$prio" 2>/dev/null || true
      # ... and add it ABOVE Cilium's local-lookup rule (pref 100) so the node's own
      # IP always resolves via the local table, never out the wire.
      ${ipBin} rule add from "$addr"/32 table "$table" priority "$prio" || true
    }
    setup ${wiredIf} ${wiredIp} 100 1000
    setup ${wirelessIf} ${wirelessIp} 101 1001
  '';
in {
  networking.networkmanager.connectionConfig."ipv4.dad-timeout" = 0;

  boot.kernel.sysctl = {
    "net.ipv4.conf.${wiredIf}.arp_ignore" = 1;
    "net.ipv4.conf.${wiredIf}.arp_announce" = 2;
    "net.ipv4.conf.${wirelessIf}.arp_ignore" = 1;
    "net.ipv4.conf.${wirelessIf}.arp_announce" = 2;
  };

  systemd.services.dual-nic-pbr = {
    description = "Source-based policy routing so both same-subnet NICs stay reachable";
    after = [ "NetworkManager-wait-online.service" ];
    wants = [ "NetworkManager-wait-online.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pbr;
    };
  };

  # Re-run the routing when either NIC comes up (wifi associates late; links can
  # flap). This is a one-liner that ONLY restarts the unit above — it contains no
  # routing logic, unlike the earlier dispatcher that broke styxeon.
  networking.networkmanager.dispatcherScripts = [{
    source = pkgs.writeShellScript "dual-nic-pbr-trigger" ''
      if [ "$2" = "up" ] && { [ "$1" = "${wiredIf}" ] || [ "$1" = "${wirelessIf}" ]; }; then
        ${pkgs.systemd}/bin/systemctl restart dual-nic-pbr.service || true
      fi
    '';
  }];
}
