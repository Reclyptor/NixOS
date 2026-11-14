{
  lib,
  stdenv,
  kernel,
  kernelModuleMakeFlags,
  src,
}:
stdenv.mkDerivation {
  pname = "gpu-unlock";
  version = "${lib.trim (builtins.readFile "${src}/VERSION")}-${kernel.version}";

  src = "${src}/kernel/gpu_unlock";

  hardeningDisable = [ "pic" ];
  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = kernelModuleMakeFlags ++ [
    "-C"
    "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "M=$(PWD)"
  ];
  buildFlags = [ "modules" ];
  installFlags = [ "INSTALL_MOD_PATH=$(out)" ];
  installTargets = [ "modules_install" ];

  meta = {
    description = "Kernel module that lifts the tensor core rate cap on GeForce RTX cards before nvidia binds them";
    homepage = "https://github.com/Zagitta/gpu-unlock";
    license = lib.licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
  };
}
