# Changelog

All notable changes to devices-nv are recorded here. The format is
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
with the pre-1.0 rule that a breaking change bumps the MINOR number.

## 0.1.1 — 2026-10-07

The package builds for a device.

### Fixed

- **A device build that includes the package is no longer refused at
  the embedded tier.**  The tier check holds every function of a
  dependency's modules at `@tier(embedded)`, and 0.1.0's `dev_bus`
  built lists outside a `system` block: `wiring_read` its one-byte
  register frame, `wiring_write` its frame, grown with `list.push`,
  and `wiring_spi_exchange` its empty answers.  Each list is now built
  in a `system` block, and `wiring_write`'s frame with
  `list.with_capacity` and `list.try_push`, one allocation of the
  frame's exact size.  The signatures are unchanged.

### Added

- **`DevBytes`**, an alias of `Vec[u8; 32]`: a buffer of up to 32
  bytes that a driver keeps in its own frame, with no allocation.
- **`wiring_read_into`, `wiring_write_from` and
  `wiring_spi_exchange_into`**, the register read, the register write
  and the SPI transaction through `DevBytes` buffers the caller owns.
  A driver that uses them builds no list and needs no `system` block.
  The SPI transaction moves every byte through `SpiBus.transfer` and
  builds no list at all.  The I2C pair still hands the bus a list,
  because embedded-hal-nv's `I2cBus` takes and answers lists, and
  releases it before returning.  A transfer longer than 32 bytes is
  refused rather than cut short.
- **`tests/embedded_probe.nv`**, a firmware image that uses every
  module and a TMP102-shaped driver over the buffer forms, and
  `tests/embedded_probe.sh`, which builds it for `--target=nrf52-qemu`
  and `--target=frdm-mcxn947`.

### Changed

- No trait changed.  `Accelerometer`, `Thermometer`, `PowerManager`,
  `RealTimeClock`, their async forms and `AsyncDeviceReady` are as in
  0.1.0, since none of them builds a list.
- `dev_bus` checks clean at the embedded, rt and system tiers, and no
  longer at the wasm and app tiers, which refuse a `system` block.  The
  other four modules check clean at every tier.
- The toolchain floor is 0.19.0.  0.1.0 named 0.18.4, which was never
  released; the fixes it needed shipped in 0.19.0.

## 0.1.0 — 2026-10-06

### Added

- `dev_accel`: the `Accelerometer` and `AccelerometerAsync` traits, the
  reading `AccelMilliG` in milli-g per axis, the range `AccelRange`,
  and `accel_full_scale`, `accel_range_for` and `accel_milli_g`.
- `dev_thermo`: the `Thermometer` and `ThermometerAsync` traits, with a
  conversion time answered by `temp_start` and an early read refused
  by `temp_read_after`; the reading `TempMilliC`; `temp_of_raw` and
  `temp_milli_f`.
- `dev_power`: the `PowerManager` and `PowerManagerAsync` traits over
  numbered rails and a battery; `MilliVolts`, `MilliAmps`, `RailState`,
  `ChargeState` and `BatteryReading`; `power_step` and
  `power_is_charging`.
- `dev_rtc`: the `RealTimeClock` and `RealTimeClockAsync` traits, with
  `rtc_now_valid` refusing a time read after the oscillator stopped;
  `RtcDateTime`; BCD conversion, the 12-hour form, leap years, month
  lengths, validity and the ISO 8601 day of the week.
- `dev_bus`: `DeviceWiring` for a device on I2C or SPI with an optional
  interrupt pin; `wiring_read` and `wiring_write` over an I2C bus;
  `wiring_spi_exchange` inside the chip-select window;
  `dev_sign_extend`; and the `AsyncDeviceReady` trait for an interrupt
  line awaited at `@tier(embedded)`.
- Block storage is embedded-hal-nv's `BlockDevice`, and the package
  defines no trait of its own for it.
