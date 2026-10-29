# PdfCraft — the Acrobat Pro equivalent: read, organize, combine, split, redact
# and sign PDFs.
#
# Shipped as PrintCraft through 0.2.1 and renamed wholesale in 0.4.0 — repo,
# cargo packages, crate prefixes, binaries and the app ID all moved from
# printcraft to pdfcraft. github.com/storytold/printcraft still resolves, but by
# redirect; a pinned build names the new repo.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
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
      environment.systemPackages = [
        (
          (import ./_artcraft.nix { inherit lib pkgs; } {
            pname = "pdfcraft";
            version = "0.15.0";
            hash = "sha256-9XgS4feVsc+2c6aMi9WbG1NI/SjVhjU3otMU9bmQez0=";
            cargoHash = "sha256-n2hA1QOPUVG65EMCpEWu8kUEHoVV3nTCNq9sja3cNqQ=";
            releaseDate = "2026-10-28";
            description = "PDF editor to read, organize, combine, split and secure PDFs";
            craftFontsRev = "b076417b5880bd4154bd22f00695b1d28c6bea83";

            # pdfcraft-sign uses aws-lc directly for its signature crypto (rustls here
            # runs on ring). aws-lc-sys 0.46.0 needs nothing beyond the C compiler on
            # x86_64-linux: it ships pregenerated bindings and builds with cc, so it
            # reaches for cmake and bindgen only when neither applies.

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
            # Delete this, and the vendorPatches plumbing, once rustc ships the fix.
            vendorPatches = [
              {
                crate = "rten-gemm-0.26.0";
                patch = ./rten-gemm-vpdpbusd-inline-asm.patch;
              }
            ];
          }).overrideAttrs
            (old: {
              postInstall = old.postInstall + ''
                for model in ${lib.escapeShellArgs ocrModels}; do
                  install -Dm644 "$model" "$out/share/pdfcraft/models/$(stripHash "$model")"
                done
              '';
              meta = old.meta // {
                license = old.meta.license ++ [ lib.licenses.cc-by-sa-40 ];
              };
            })
        )
      ];
    };
}
