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
      # Scan & OCR's two models, pinned by the sha256s upstream records in
      # ATTRIBUTION.toml. Release packages stage them into share/pdfcraft/models,
      # which crates/ocr looks for beside the binary (../share/pdfcraft/models from
      # bin/); a source build has to fetch them itself, and without them OCR
      # reports its models as not installed.
      ocrModel =
        name: hash:
        pkgs.fetchurl {
          url = "https://ocrs-models.s3-accelerate.amazonaws.com/${name}";
          inherit hash;
        };
      ocrModels = [
        (ocrModel "text-detection.rten" "sha256-8Vz7Vr0CxL9HiiA0OYZQSh8B4WZcKzoK1mNA8FSxtco=")
        (ocrModel "text-recognition.rten" "sha256-5ISGbUzOQDF1vY0AsSj+sIq0LiCN4w5CzZiJ2PFzWm4=")
      ];
    in
    {
      environment.systemPackages = [
        (
          (import ./_artcraft.nix { inherit lib pkgs; } {
            pname = "pdfcraft";
            version = "0.9.0";
            hash = "sha256-pOHCv3K6XfRci1kWhta1gmTZGklSpBJqjLIXvqKq484=";
            cargoHash = "sha256-4zRin04PC+QAeV41qcXHouOXNbwIGYZ/IfXhGKa9Zp8=";
            releaseDate = "2026-10-18";
            description = "PDF editor to read, organize, combine, split and secure PDFs";
            craftFontsRev = "3d9ab3a132ed0eff457e424226a435a901da30d3";

            # pdfcraft-sign uses aws-lc directly for its signature crypto (rustls here
            # runs on ring). aws-lc-sys builds C and generates its bindings, so it
            # needs cmake and a libclang on top of rustc. The only app in the suite
            # that does.
            extraNativeBuildInputs = [
              pkgs.cmake
              pkgs.rustPlatform.bindgenHook
            ];

            # pdfcraft-engine -> pdfcraft-ocr -> ocrs -> rten -> rten-gemm, which
            # calls _mm512_dpbusd_epi32. rustc cannot codegen that intrinsic —
            # its own stdarch declares the LLVM intrinsic with the wrong vector
            # types (repro'd on 1.97.1, and again on 1.98.1 on 2026-10-21 by
            # building unpatched rten-gemm 0.26.0) — so the build fails outright,
            # and OCR is not optional here
            # (apps/pdfcraft/Cargo.toml declares no features at all). The patch emits
            # the instruction as inline asm instead, which is what rten already does
            # for the same instruction in its x86_64 kernel.
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
