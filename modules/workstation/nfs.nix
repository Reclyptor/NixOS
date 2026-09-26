# Every entry here mounts a DATASET ROOT and never an individual child
# dataset, and that is a privacy rule before it is a technical one.
#
# The NAS exports each media category under a root as its own ZFS dataset, and
# NFSv4 crosses into an exported child on first access — the client builds the
# submount itself. So enumerating the children would buy nothing: they are all
# reachable through the root regardless. What enumerating them WOULD do is
# write every category name into this file, and this repository is public.
# Mounting only the root keeps the shape of what is stored off the internet.
#
# Mountpoints are <host>/<dataset> so a second dataset on the same NAS has
# somewhere to land. dxp4800's videos used to sit at the bare /data/nfs/dxp4800,
# which left a sibling nowhere to go except inside the videos dataset itself.
#
# Nothing here uses x-systemd.automount, and that is the point. An automount
# leaves a direct autofs trigger in the root filesystem, and touching a trigger
# IS a mount request. Every buildFHSEnv app — discord, steam — starts by
# recursively bind-mounting each top-level directory into a bubblewrap sandbox,
# /data included, which trips every trigger underneath it. With a NAS down that
# mount blocks in autofs_wait in D state: uninterruptible, deaf to SIGKILL, and
# the app never reaches its own first line of code. A plain mountpoint costs
# nothing to bind, so the shares mount at boot and nfs-reconcile below picks up
# whatever was unreachable then.
_: {
  flake.modules.nixos.workstation =
    { pkgs, lib, ... }:
    let
      shares = {
        "/data/nfs/dxp6800/videos" = "192.168.1.2:/mnt/primary/videos";

        # videos and images are siblings under primary, not children of one
        # another, so each needs its own entry. Their categories do not.
        "/data/nfs/dxp4800/videos" = "192.168.1.3:/mnt/primary/videos";
        "/data/nfs/dxp4800/images" = "192.168.1.3:/mnt/primary/images";

        "/data/nfs/asustor" = "192.168.1.5:/volume1/data";
      };

      hostOf = device: lib.head (lib.splitString ":" device);

      reconcile = pkgs.writeShellApplication {
        name = "nfs-reconcile";
        runtimeInputs = with pkgs; [
          coreutils
          systemd
          util-linux
        ];
        # Reachability is checked before the mount, not instead of it. A NAS that
        # is powered off answers nothing, and starting its unit blind would burn
        # the full mount-timeout on every tick. The probe is a bounded TCP connect
        # to the NFS port through bash's /dev/tcp, so it needs no netcat — and it
        # re-enters through $BASH, this script's own interpreter, rather than
        # putting a second bash on PATH.
        #
        # An unreachable host is a normal state, not a failure: it logs and the
        # loop continues, so one down NAS never stops the others from mounting.
        text = ''
          try_mount() {
            local mp="$1" host="$2" unit

            if mountpoint -q "$mp"; then
              return 0
            fi

            if ! timeout 2 "$BASH" -c "exec 3<>/dev/tcp/$host/2049" 2>/dev/null; then
              echo "$mp: $host unreachable, leaving unmounted"
              return 0
            fi

            unit="$(systemd-escape -p --suffix=mount "$mp")"
            if systemctl start "$unit"; then
              echo "$mp: mounted from $host"
            else
              echo "$mp: $host answered but the mount failed"
            fi
          }

          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (mp: device: ''try_mount "${mp}" "${hostOf device}"'') shares
          )}
        '';
      };
    in
    {
      # nofail keeps a down NAS out of boot's way, retry=0 stops mount.nfs4 from
      # retrying for its default two minutes, and mount-timeout caps the unit.
      # hard is already the default and is spelled out because it is a decision:
      # yt-dlp and gallery-dl write here, and a write that waits for the array to
      # come back beats one that soft's EIO truncates silently.
      fileSystems = lib.mapAttrs (_: device: {
        inherit device;
        fsType = "nfs4";
        options = [
          "defaults"
          "_netdev"
          "nofail"
          "hard"
          "retry=0"
          "x-systemd.mount-timeout=10s"
        ];
      }) shares;

      # Without the automount nothing creates these directories until a mount
      # succeeds, so an unreachable share would read as ENOENT rather than as an
      # empty directory. Mode and owner are left as "-" deliberately: when the
      # share IS mounted this path is the NAS's own export root, and tmpfiles
      # must not reach through and restat it.
      systemd.tmpfiles.rules = lib.mapAttrsToList (mp: _: "d ${mp} - - - -") shares;

      systemd.services.nfs-reconcile = {
        description = "Mount NFS shares whose host is reachable";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe reconcile;
          TimeoutStartSec = "90s";
        };
      };

      # A NAS coming back does not change this workstation's link state, so there
      # is no NetworkManager dispatcher event to hook the way dual-nic-pbr does.
      # Polling is the only signal available. It also covers the boot race, where
      # wifi associates after remote-fs.target has already given up.
      systemd.timers.nfs-reconcile = {
        description = "Retry NFS shares that were unreachable at boot";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "1min";
          OnUnitActiveSec = "2min";
        };
      };
    };
}
