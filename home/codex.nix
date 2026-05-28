{ config, lib, pkgs, ... }: {
  home.activation.codexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    CODEX_CFG="$HOME/.codex/config.toml"

    $DRY_RUN_CMD mkdir -p "$HOME/.codex"

    PRESERVED=""
    if [ -f "$CODEX_CFG" ]; then
      PRESERVED=$(${pkgs.gawk}/bin/awk '
        /^\[projects\./ { p = 1; print; next }
        /^\[/           { p = 0; next }
        p               { print }
      ' "$CODEX_CFG")
    fi

    {
      cat <<'BASE_EOF'
# Managed declaratively by home/codex.nix.
# Edits to top-level keys and [features] will be overwritten on the next
# home-manager activation. [projects.*] sections (trust levels) are preserved
# from codex's own writes across rebuilds.

model = "gpt-5.5"
model_reasoning_effort = "high"

[features]
goals = true
memories = true
BASE_EOF
      if [ -n "$PRESERVED" ]; then
        printf '\n%s\n' "$PRESERVED"
      fi
    } > "$CODEX_CFG.tmp"

    $DRY_RUN_CMD mv "$CODEX_CFG.tmp" "$CODEX_CFG"
    $DRY_RUN_CMD chmod 600 "$CODEX_CFG"
  '';
}
