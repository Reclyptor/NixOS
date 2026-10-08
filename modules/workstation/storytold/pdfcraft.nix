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
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "pdfcraft";
          version = "0.4.0";
          hash = "sha256-Fkzo9qb9obrXa1X4klio+gRgM2UZIO8QwfI0/xSYwmo=";
          cargoHash = "sha256-2y4jFVHDHUYoKo9gzRb7uq2dhtLa97P1iffRrMw46IQ=";
          releaseDate = "2026-10-08";
          description = "PDF editor to read, organize, combine, split and secure PDFs";

          # Signed PDFs go through rustls, whose crypto provider here is aws-lc.
          # aws-lc-sys builds C and generates its bindings, so it needs cmake and
          # a libclang on top of rustc. The only app in the suite that does.
          extraNativeBuildInputs = [
            pkgs.cmake
            pkgs.rustPlatform.bindgenHook
          ];

          # pdfcraft-engine -> pdfcraft-ocr -> ocrs -> rten -> rten-gemm, which
          # calls _mm512_dpbusd_epi32. rustc 1.97.1 cannot codegen that intrinsic
          # — its own stdarch declares the LLVM intrinsic with the wrong vector
          # types — so the build fails outright, and OCR is not optional here
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
        })
      ];
    };
}
