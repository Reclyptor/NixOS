{
  lib,
  stdenvNoCC,
  fetchurl,
  python3,
  zstd,
  src,
}:
let
  # The NVIDIA release gpu-unlock extracts its firmware from. It is unrelated
  # to the driver the host runs. Upstream's Makefile names the same release,
  # so a source bump that moves it fails this build on a missing input rather
  # than shipping firmware the module will not ask for.
  nv = "610.43.03";

  inputs = [
    (fetchurl {
      url = "https://download.nvidia.com/XFree86/NVIDIA-kernel-module-source/NVIDIA-kernel-module-source-${nv}.tar.xz";
      hash = "sha256-fhGJI8eiPtw2EU1jJzpG4+BOmvmGlaQiA+esLf6fwdw=";
    })
    (fetchurl {
      url = "https://download.nvidia.com/XFree86/Linux-x86_64/${nv}/NVIDIA-Linux-x86_64-${nv}-no-compat32.run";
      hash = "sha256-4IRFHbcwpt8p09dPZVdJxNI248lF99lLUgXoQxj+L5A=";
    })
  ];

  # What a GA102 card (RTX 3080, 3080 Ti, 3090, 3090 Ti) loads. The module
  # declares firmware for every family it supports, and the initrd carries
  # whichever of those exist, so shipping the rest would put two more GSP
  # images on the ESP for cards this fleet does not have.
  files = [
    "booter_load_ga102.bin"
    "falcon_loader.bin"
    "gsp_ga10x.bin"
    "gsp_boot_ga102.bin"
    "gsp_boot_desc_ga102.bin"
  ];
in
stdenvNoCC.mkDerivation {
  pname = "gpu-unlock-firmware";
  version = nv;

  inherit src;

  nativeBuildInputs = [
    python3
    zstd
  ];

  buildPhase = ''
    runHook preBuild
    mkdir inputs
    ${lib.concatMapStrings (input: ''
      ln -s ${input} inputs/${input.name}
    '') inputs}
    make firmware INPUTS=$PWD/inputs ASSETS=$PWD/assets
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm444 -t $out/lib/firmware/gpu-unlock/${nv} ${
      lib.concatMapStringsSep " " (file: "assets/${file}") files
    }
    install -Dm444 -t $out/share/licenses/gpu-unlock-firmware assets/NVIDIA-LICENSE firmware/NOTICE.md
    runHook postInstall
  '';

  dontFixup = true;

  meta = {
    description = "NVIDIA ${nv} firmware that gpu-unlock loads on GA102 cards";
    homepage = "https://github.com/Zagitta/gpu-unlock";
    license = lib.licenses.unfreeRedistributableFirmware;
    platforms = [ "x86_64-linux" ];
  };
}
