#!/usr/bin/env bash
# tests/embedded_probe.sh — builds tests/embedded_probe.nv for two
# microcontroller boards, which is the claim that every module of the
# package checks clean at `@tier(embedded)`.
#
# The probe is a firmware `main`, so it is built as the `main` of a
# scratch package that depends on this one by path, the way a program
# on a device depends on it.  The targets are an emulated Cortex-M4,
# `nrf52-qemu`, and NXP's FRDM-MCXN947, a Cortex-M33 board whose I2C
# and SPI buses reach real drivers.  Nothing is flashed.  The emulated
# board's image is then run under QEMU, where no device answers on the
# buses, and its score line must be the one the probe's arithmetic gives
# with every bus read refused.
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

# The score the image reports under QEMU.  No I2C device answers there,
# and the SPI bus reads 0xFF for every byte, so the terms are: the
# refused thermometer read 2, sign extension 4, the three-byte SPI read
# 3, the wiring's optional fields 1081 (the chip select 4, the interrupt
# pin 5, the address 72 and 1000 for the absent address), the
# accelerometer count 3998, the regulator step 1800, the charger 32, the
# weekday and BCD 62, the day after by Unix time 8, the alarm 256, the
# refused I2C identification 512, the SPI identification 255 and 7 for
# its absent revision, the SPI read with a 0x00 filler 1, the gyroscope
# 8, the magnetometer 100, the hygrometer 50, the barometer 101, the
# gyroscope's range 500 and the paired sample 3.
SCORE=8783

fail=0
for target in nrf52-qemu frdm-mcxn947; do
  rm -f "$WORK/main.elf"
  ( cd "$WORK" && NOVO_LEAK_CHECK=0 timeout 900 "$NOVO" build --target="$target" src/main.nv ) \
    > "$WORK/$target.log" 2>&1
  if [ -f "$WORK/main.elf" ]; then
    echo "  ✓ tests/embedded_probe.nv builds for --target=$target"
    cp "$WORK/main.elf" "$WORK/$target.elf"
  else
    echo "  ✗ tests/embedded_probe.nv does not build for --target=$target"
    grep -vE '^novo:' "$WORK/$target.log" | head -20 | sed 's/^/      /'
    fail=1
  fi
done

# The emulated board: an MPS2 AN386 Cortex-M4, whose UART output reaches
# the host through semihosting.  The image parks after its score line,
# so QEMU is stopped by the timeout.
if ! command -v qemu-system-arm >/dev/null 2>&1; then
  echo "  - the image is not run: qemu-system-arm is not installed"
elif [ -f "$WORK/nrf52-qemu.elf" ]; then
  out=$(timeout 20 qemu-system-arm -machine mps2-an386 -nographic -semihosting \
          -kernel "$WORK/nrf52-qemu.elf" 2>&1 | head -20)
  line=$(printf '%s\n' "$out" | grep -m1 'devices-nv: score' | tr -d '\r')
  if [ "$line" = "devices-nv: score $SCORE" ]; then
    echo "  ✓ the image runs under QEMU and reports the score $SCORE"
  else
    echo "  ✗ the image under QEMU did not report the score $SCORE"
    printf '%s\n' "$out" | head -10 | sed 's/^/      /'
    fail=1
  fi
fi
exit "$fail"
