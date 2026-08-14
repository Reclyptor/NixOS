{ ... }: {
  flake.modules.nixos.workstation = { pkgs, lib, ... }:
  let
    # ipdeny ISO country codes to drop, inbound only.
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

    refresh = pkgs.writeShellApplication {
      name = "geoblock-refresh";
      runtimeInputs = with pkgs; [ curl nftables coreutils gnugrep ];
      # One country failing used to abort the whole run (writeShellApplication
      # adds `set -e`, and the empty-list check exit 1'd outright), so a single
      # ipdeny hiccup left every set after it in the loop unpopulated — silently
      # unblocked until the next daily timer. Now each country is independent:
      # a failure keeps that set's PREVIOUS contents and the run continues.
      # Exit non-zero only if nothing at all loaded, which is the one state worth
      # retrying (see Restart=on-failure on the unit).
      text = ''
        loaded=0
        failed=0

        load_set() {
          local cc="$1" fam="$2" url="$3" setname="$4" f elems
          f="$(mktemp)"
          if ! curl -fsS --retry 3 --max-time 60 "$url" -o "$f"; then
            echo "geoblock: $cc $fam download failed; keeping previous contents" >&2
            rm -f "$f"; return 1
          fi
          if [ ! -s "$f" ]; then
            echo "geoblock: $cc $fam list came back empty; keeping previous contents" >&2
            rm -f "$f"; return 1
          fi
          elems="$(grep -vE '^[[:space:]]*$' "$f" | paste -sd,)"
          if ! printf 'flush set inet geoblock %s\nadd element inet geoblock %s { %s }\n' \
                 "$setname" "$setname" "$elems" | nft -f -; then
            echo "geoblock: $cc $fam failed to load into nftables" >&2
            rm -f "$f"; return 1
          fi
          rm -f "$f"
        }

        for cc in ${lib.concatStringsSep " " v4Countries}; do
          if load_set "$cc" IPv4 \
               "https://www.ipdeny.com/ipblocks/data/aggregated/$cc-aggregated.zone" "''${cc}4"
          then loaded=$((loaded + 1)); else failed=$((failed + 1)); fi
        done

        for cc in ${lib.concatStringsSep " " v6Countries}; do
          if load_set "$cc" IPv6 \
               "https://www.ipdeny.com/ipv6/ipaddresses/aggregated/$cc-aggregated.zone" "''${cc}6"
          then loaded=$((loaded + 1)); else failed=$((failed + 1)); fi
        done

        echo "geoblock: $loaded of ${toString (lib.length v4Countries + lib.length v6Countries)} country sets loaded, $failed failed"

        if [ "$loaded" -eq 0 ]; then
          echo "geoblock: NO sets loaded — nothing is being blocked" >&2
          exit 1
        fi
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
        # Only fires when the run loaded nothing at all (e.g. booted before the
        # network was really up). Without this the sets would sit empty until
        # the next daily timer.
        Restart = "on-failure";
        RestartSec = "60s";
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
  };
}
