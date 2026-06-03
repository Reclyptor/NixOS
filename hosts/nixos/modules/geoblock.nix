{ pkgs, lib, ... }:
let
  # ipdeny ISO country codes to drop, inbound and outbound.
  countries = [
    "cn" "in" "ru"
    "dz" "ao" "bj" "bw" "bf" "bi" "cv" "cm" "cf" "td" "km" "cg" "cd" "ci"
    "dj" "eg" "gq" "er" "sz" "et" "ga" "gm" "gh" "gn" "gw" "ke" "ls" "lr"
    "ly" "mg" "mw" "ml" "mr" "mu" "ma" "mz" "na" "ne" "ng" "rw" "st" "sn"
    "sc" "sl" "so" "za" "ss" "sd" "tz" "tg" "tn" "ug" "zm" "zw"
  ];

  # ipdeny publishes no IPv6 aggregated file for these, so they are IPv4-only.
  noV6 = [ "cf" "er" ];

  v4Countries = countries;
  v6Countries = lib.subtractLists noV6 countries;

  setDefs =
    (lib.concatMapStringsSep "\n" (cc: ''
      set ${cc}4 {
        type ipv4_addr
        flags interval
      }
    '') v4Countries)
    + (lib.concatMapStringsSep "\n" (cc: ''
      set ${cc}6 {
        type ipv6_addr
        flags interval
      }
    '') v6Countries);

  saddrRules =
    (lib.concatMapStringsSep "\n" (cc: "ip saddr @${cc}4 counter drop") v4Countries)
    + "\n"
    + (lib.concatMapStringsSep "\n" (cc: "ip6 saddr @${cc}6 counter drop") v6Countries);

  daddrRules =
    (lib.concatMapStringsSep "\n" (cc: "ip daddr @${cc}4 counter drop") v4Countries)
    + "\n"
    + (lib.concatMapStringsSep "\n" (cc: "ip6 daddr @${cc}6 counter drop") v6Countries);

  refresh = pkgs.writeShellApplication {
    name = "geoblock-refresh";
    runtimeInputs = with pkgs; [ curl nftables coreutils gnugrep ];
    text = ''
      for cc in ${lib.concatStringsSep " " v4Countries}; do
        f="$(mktemp)"
        curl -fsS --retry 3 "https://www.ipdeny.com/ipblocks/data/aggregated/$cc-aggregated.zone" -o "$f"
        [ -s "$f" ] || { echo "$cc IPv4 list came back empty" >&2; exit 1; }
        elems="$(grep -vE '^[[:space:]]*$' "$f" | paste -sd,)"
        {
          echo "flush set inet geoblock ''${cc}4"
          echo "add element inet geoblock ''${cc}4 { $elems }"
        } | nft -f -
        rm -f "$f"
      done

      for cc in ${lib.concatStringsSep " " v6Countries}; do
        f="$(mktemp)"
        curl -fsS --retry 3 "https://www.ipdeny.com/ipv6/ipaddresses/aggregated/$cc-aggregated.zone" -o "$f"
        [ -s "$f" ] || { echo "$cc IPv6 list came back empty" >&2; exit 1; }
        elems="$(grep -vE '^[[:space:]]*$' "$f" | paste -sd,)"
        {
          echo "flush set inet geoblock ''${cc}6"
          echo "add element inet geoblock ''${cc}6 { $elems }"
        } | nft -f -
        rm -f "$f"
      done

      echo "geoblock loaded: ${toString (lib.length v4Countries)} IPv4 + ${toString (lib.length v6Countries)} IPv6 country sets"
    '';
  };
in {
  networking.nftables.enable = true;

  networking.nftables.tables.geoblock = {
    family = "inet";
    content = ''
      ${setDefs}

      chain input {
        type filter hook input priority -10; policy accept;
        ${saddrRules}
      }

      chain output {
        type filter hook output priority -10; policy accept;
        ${daddrRules}
      }
    '';
  };

  systemd.services.geoblock = {
    description = "Load geoblocked country IP ranges into nftables sets";
    after = [ "nftables.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    requires = [ "nftables.service" ];
    partOf = [ "nftables.service" ];
    wantedBy = [ "multi-user.target" "nftables.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = lib.getExe refresh;
    };
  };

  systemd.timers.geoblock = {
    description = "Refresh geoblocked country IP ranges daily";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
