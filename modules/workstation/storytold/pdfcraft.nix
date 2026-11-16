# PdfCraft — the Acrobat Pro equivalent: read, organize, combine, split, redact
# and sign PDFs.
#
# Shipped as PrintCraft through 0.2.1 and renamed wholesale in 0.4.0 — repo,
# cargo packages, crate prefixes, binaries and the app ID all moved from
# printcraft to pdfcraft. github.com/storytold/printcraft still resolves, but by
# redirect; a pinned build names the new repo.
_: {
  flake.modules.nixos.workstation = import ./_app.nix "pdfcraft" (
    { lib, pkgs }:
    let
      # Scan & OCR's two models, pinned by the sha256s upstream's release build
      # verifies them against. Release packages stage them into share/pdfcraft/models,
      # which crates/ocr looks for beside the binary (../share/pdfcraft/models from
      # bin/); a source build has to fetch them itself, and without them OCR
      # reports its models as not installed. Since 0.15.0 these are the ONNX
      # exports, which rten-onnx loads; crates/ocr still accepts a complete pair
      # of the older .rten files, but no longer ships them.
      ocrModel =
        name: hash:
        pkgs.fetchurl {
          url = "https://ocrs-models.s3-accelerate.amazonaws.com/${name}";
          inherit hash;
        };
      ocrModels = [
        (ocrModel "text-detection.onnx" "sha256-qReyPb2VJLRl336SJkGz/ymBYj303tWgI0AE7y/ufP4=")
        (ocrModel "text-recognition.onnx" "sha256-hsFFwu25bIyu1bHruPRNcGQIkiIRRRwwnGJRV91gYcU=")
      ];
    in
    {
      version = "0.21.1";
      hash = "sha256-2X2ixtr7mxHRpfhcGghKUO7ib0SFBruBmQPIlTFZ8Ds=";
      cargoHash = "sha256-sjnRF9WVDRPrgEgwZEyVIEk3qq3Erkv9cBtlkgb52lc=";
      releaseDate = "2026-11-12";
      description = "PDF editor to read, organize, combine, split and secure PDFs";
      craftFontsRev = "b076417b5880bd4154bd22f00695b1d28c6bea83";

      # The interface translations moved to storytold/craft-i18n in this
      # release, as wordcraft's did in 0.11.0.
      craftI18nRev = "575cfdef63227b14daf173b8cc87928bfdfa325e";

      # pdfcraft-sign uses aws-lc directly for its signature crypto (rustls here
      # runs on ring). nixpkgs' cargoSetupHook exports AWS_LC_SYS_USE_SYSTEM=1
      # (since 44cddf92c4), so aws-lc-sys links the system AWS-LC, found
      # through pkg-config, instead of building its bundled copy.
      extraNativeBuildInputs = [ pkgs.pkg-config ];
      extraBuildInputs = [ pkgs.aws-lc ];

      # pdfcraft-engine -> pdfcraft-ocr -> ocrs -> rten -> rten-gemm, which
      # calls _mm512_dpbusd_epi32. rustc cannot codegen that intrinsic —
      # its own stdarch declares the LLVM intrinsic with the wrong vector
      # types (repro'd on 1.97.1, on 1.98.1 on 2026-10-21 by building
      # unpatched rten-gemm 0.26.0, and on 1.99.0 with LLVM 21.1.8 on
      # 2026-10-28) — so the build fails outright, and OCR is not optional
      # here (apps/pdfcraft/Cargo.toml declares no features at all). The
      # patch emits the instruction as inline asm instead, which is what rten
      # already does for the same instruction in its x86_64 kernel.
      #
      # Still rten-gemm 0.26.0 at this release, so the patch applies unchanged.
      # Delete this once rustc ships the fix.
      vendorPatches = [
        {
          crate = "rten-gemm-0.26.0";
          patch = ./rten-gemm-vpdpbusd-inline-asm.patch;
        }
      ];

      extraPostInstall = ''
        for model in ${lib.escapeShellArgs ocrModels}; do
          install -Dm644 "$model" "$out/share/pdfcraft/models/$(stripHash "$model")"
        done
      '';
    }
  );
}
