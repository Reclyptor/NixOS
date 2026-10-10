_: {
  # AnyPS5 (github.com/boykopovar/AnyPS5) — a relinker, not an emulator. It
  # rewrites a PS5 executable into a native ELF and ships clean-room
  # reimplementations of the PS5 system `.prx` libraries for the rewritten binary
  # to link against. No emulation, no runtime, no separate process.
  #
  # See SPEC/anyps5-relinker.md for the decisions behind the three unobvious
  # parts of this build: why upstream's `-static` is dropped, why the `.prx` get
  # their RPATH patched, and why the libraries are installed rather than wrapped.
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    let
      # Sonames SDL dlopens at runtime rather than recording as NEEDED. Taken
      # from SDL's own configure output ("dynamic libX11 -> libX11.so.6", and so
      # on) rather than from a dependency list — an upstream package manifest is
      # a conservative superset, so it is not evidence of what is actually
      # loaded. Vulkan is here too: SDL_Vulkan_LoadLibrary dlopens it.
      #
      # Notably absent: libxinerama, libxxf86vm and libxkbcommon. SDL 2.33 with
      # Wayland off asks for none of them.
      dlopenLibraries = with pkgs; [
        libx11
        libxext
        libxcursor
        libxi
        libxfixes
        libxrandr
        libxrender
        libxscrnsaver
        alsa-lib
        libpulseaudio
        pipewire
        udev
        dbus
        vulkan-loader
      ];

      anyps5 = pkgs.stdenv.mkDerivation (finalAttrs: {
        pname = "anyps5";
        version = "0.1.1";

        # A tag, not a branch: this repo takes commits most days, and only two
        # tags exist so far. To bump, set version, set hash to lib.fakeHash,
        # rebuild, and paste back the hash Nix reports.
        src = pkgs.fetchFromGitHub {
          owner = "boykopovar";
          repo = "AnyPS5";
          tag = "v${finalAttrs.version}";
          hash = "sha256-OxdmVcIjxppLKEz9oSdtyLfEW/48gfMVKhWJ6MDlRbA=";
          # SDL2, freetype, glslang, SPIRV-Tools/-Headers, Vulkan-Headers,
          # VulkanMemoryAllocator and LibAtrac9 are all in-tree submodules, built
          # by the top-level CMakeLists. Pinned by gitlink, so still deterministic.
          fetchSubmodules = true;
        };

        nativeBuildInputs = with pkgs; [
          cmake
          ninja
          python3 # several ctest cases are python scripts
          pkg-config
          patchelf
          util-linux # setarch, for the check phase below
        ];

        # libxcb is linked rather than dlopened, so it needs no RPATH help.
        buildInputs = dlopenLibraries ++ [ pkgs.libxcb ];

        # Upstream links every executable fully static so one release asset runs
        # on any distro. That buys nothing in the store, which pins its own
        # libraries, and costs a great deal: `glibc.static` puts a lib directory
        # holding libc.a and no libc.so ahead of real glibc, so every -lc in the
        # tree resolves to the archive — including links that never asked to be
        # static. glslang's find_package(Threads) dies that way, on a link whose
        # command line has no -static at all. -static-libgcc/-static-libstdc++
        # are kept; they are self-contained and harmless.
        postPatch = ''
          substituteInPlace CMakeLists.txt \
            --replace-fail '} -static -static-libgcc' '} -static-libgcc'
        '';

        cmakeFlags = [
          (lib.cmakeBool "BUILD_TESTING" true)
          # Left at upstream's default. Turning it on validates generated SPIR-V
          # in-process, which sounds strictly better and is not: the recompiler
          # currently emits an OpSelect whose condition and result vector widths
          # disagree, so agc_shader_memory fails and, at runtime, that shader
          # would throw instead of reaching the driver. Upstream CI is green only
          # because this is off. Worth revisiting once that codegen is fixed.
          (lib.cmakeBool "ANYPS5_ENABLE_SPIRV_TOOLS" false)
        ];

        # `all` builds the relinker; the patched system libraries are a separate
        # target, exactly as upstream's release workflow runs them. This has to
        # be ninjaFlags: the ninja setup hook ignores buildFlags entirely, and
        # the symptom is a far-away "install: missing file operand" when the
        # .prx glob matches nothing.
        ninjaFlags = [
          "all"
          "libs"
        ];

        doCheck = true;
        # setarch resets the personality Nix's sandbox sets, which disables ASLR.
        # guest_memory maps at an address hint and then looks for free space
        # above it; with the address space laid out deterministically there is
        # none, and it aborts with "No free range above the mapping address
        # hint". Under a normal personality it passes. Randomization is what the
        # test actually needs, so give it that rather than skipping it.
        checkPhase = ''
          runHook preCheck
          setarch ${pkgs.stdenv.hostPlatform.linuxArch} \
            ctest --output-on-failure --timeout 300
          runHook postCheck
        '';

        # The project has no install() rules at all, so the layout here is ours.
        # It mirrors what tools/package_release.py collects for a release.
        installPhase = ''
          runHook preInstall

          install -Dm755 core/relinker/relinker $out/bin/relinker
          install -Dm755 -t $out/lib/anyps5/libs core/libs/libs/*.prx
          install -Dm644 -t $out/share/doc/anyps5 \
            $src/docs/user/*.md $src/README.md

          # Same assertion package_release.py makes: one .prx per directory under
          # core/libs/prx, plus the Prospero variant of libcohtml. A short set
          # means a library failed to patch, and cmake will not have said so.
          expected=$(($(find $src/core/libs/prx -mindepth 1 -maxdepth 1 -type d | wc -l) + 1))
          got=$(find $out/lib/anyps5/libs -name '*.prx' | wc -l)
          if [ "$got" -ne "$expected" ]; then
            echo "expected $expected patched libraries, installed $got" >&2
            exit 1
          fi

          runHook postInstall
        '';

        # A ported game is a plain executable, so nothing wraps it and there is no
        # LD_LIBRARY_PATH to set: each .prx has to carry its own search path or
        # nothing resolves, and on NixOS there is no /usr/lib to fall back on.
        #
        # nid_patcher rewrites each library on its way to libs/, and the rewrite
        # does not preserve a RUNPATH, so what goes in here is all there is. That
        # is why libstdc++ is in the list even though it is linked rather than
        # dlopened: measured with ldd, these libraries resolve libc and libm from
        # the loader's built-in path but libstdc++.so.6 was simply not found.
        #
        # $ORIGIN covers the sibling .prx. The relinker writes DT_RUNPATH, not
        # DT_RPATH (elfpatcher/src/linux/LinuxElfPatcher.cpp:150), and glibc does
        # not inherit RUNPATH down the dependency chain — so a library's own
        # entry is the only thing that can find the library beside it.
        postFixup = ''
          for prx in $out/lib/anyps5/libs/*.prx; do
            patchelf --add-rpath '$ORIGIN':${
              lib.makeLibraryPath (dlopenLibraries ++ [ pkgs.stdenv.cc.cc.lib ])
            } "$prx"
          done
        '';

        meta = {
          description = "Tool for automatic PS5 executables porting to Linux and Windows";
          homepage = "https://github.com/boykopovar/AnyPS5";
          license = lib.licenses.gpl2Only;
          platforms = [ "x86_64-linux" ];
          mainProgram = "relinker";
        };
      });

      # The relinker writes RPATH=$ORIGIN/libs into every executable it produces,
      # so the libraries have to sit beside the output. They cannot live in the
      # store for that purpose: app0/ is the user's own game data, and the ported
      # executable is built from the user's own input file.
      #
      # Copying is deliberate. `relinker --rpath` could point at the store
      # instead, but that bakes a store path into the ported executable, so the
      # next rebuild that changes this package's hash would break every game
      # already ported.
      anyps5-prepare = pkgs.writeShellApplication {
        name = "anyps5-prepare";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          if [ $# -ne 1 ]; then
            echo "usage: anyps5-prepare <game-dir>" >&2
            echo "" >&2
            echo "Creates <game-dir>/libs and <game-dir>/app0 and copies the" >&2
            echo "AnyPS5 system libraries into libs/. Re-run it after an AnyPS5" >&2
            echo "update to refresh them." >&2
            exit 2
          fi

          dir=$1
          mkdir -p "$dir/libs" "$dir/app0"

          # Writable, not the store's read-only copies: a .prx the user needs to
          # swap out by hand is a normal part of testing a game.
          install -m644 ${anyps5}/lib/anyps5/libs/*.prx "$dir/libs/"

          echo "libs/  $(find "$dir/libs" -name '*.prx' | wc -l) libraries"
          echo "app0/  put the game's resources here"
          echo ""
          echo "Then: relinker <eboot.bin> $dir/<name>"
        '';
      };
    in
    {
      environment.systemPackages = [
        anyps5
        anyps5-prepare
      ];
    };
}
