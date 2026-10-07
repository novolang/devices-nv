#!/usr/bin/env bash
# tests/embedded_probe.sh — builds tests/embedded_probe.nv for two
# microcontroller boards, which is the claim that every module of the
# package checks clean at `@tier(embedded)`.
#
# The probe is a firmware `main`, so it is built as the `main` of a
# scratch package that depends on this one by path, the way a program
# on a device depends on it.  The targets are an emulated Cortex-M4,
# `nrf52-qemu`, and NXP's FRDM-MCXN947, a Cortex-M33 board whose I2C
# and SPI buses reach real drivers.  Nothing is flashed or run.
#
# Run from anywhere:  bash tests/embedded_probe.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="$(cd "$HERE/.." && pwd)"
NOVO="${NOVO:-$HOME/.novo/bin/novo}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/devices-nv-emb.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/src"
cp "$HERE/embedded_probe.nv" "$WORK/src/main.nv"
cat > "$WORK/novo.toml" <<EOF
[package]
name    = "devices-nv-embedded-probe"
version = "0.1.0"
main    = "src/main.nv"

[dependencies]
devices-nv      = { path = "$PKG" }
embedded-hal-nv = "^0.2.1"
EOF

fail=0
for target in nrf52-qemu frdm-mcxn947; do
  rm -f "$WORK/main.elf"
  ( cd "$WORK" && NOVO_LEAK_CHECK=0 timeout 900 "$NOVO" build --target="$target" src/main.nv ) \
    > "$WORK/$target.log" 2>&1
  if [ -f "$WORK/main.elf" ]; then
    echo "  ✓ tests/embedded_probe.nv builds for --target=$target"
  else
    echo "  ✗ tests/embedded_probe.nv does not build for --target=$target"
    grep -vE '^novo:' "$WORK/$target.log" | head -20 | sed 's/^/      /'
    fail=1
  fi
done
exit "$fail"
