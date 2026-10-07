# Changelog

All notable changes to devices-nv are recorded here. The format is
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
with the pre-1.0 rule that a breaking change bumps the MINOR number.

## 0.2.0 — unreleased

New kinds of device, the IMU bundles, a part's identification, and
registers at 16-bit addresses.  Absence in the records is an optional
rather than -1, which takes novo-lang 0.19.1, the first release whose
`@value` structs hold an optional field.

### Breaking changes and migrations

- **`DeviceWiring.addr`, `cs` and `irq` are `?Int`.**  A device on I2C
  has `addr: Some(a)` and `cs: None`, one on SPI `addr: None` and
  `cs: Some(pin)`, and `irq` is `None` when the board wires no
  interrupt line, where 0.1.x wrote -1 for each.  `wiring_i2c`,
  `wiring_spi` and `wiring_irq` keep their signatures and build the new
  shape.  *Migration:* read a field with `match`, `if let`, `let … else`
  or `??` where it was compared with -1: `w.addr ?? -1` gives 0.1.x's
  value, `let Some(addr) = w.addr else return None` takes the address or
  leaves, and `wiring_is_spi(w)` and `wiring_has_irq(w)` still answer
  the two questions.  A record literal writes `Some(n)` and `None`.
- **`BatteryReading.percent` is `?Int`.**  It is `None` for a part with
  no fuel gauge, where 0.1.x answered -1.  *Migration:* a driver for a
  part without a gauge writes `percent: None`, one with a gauge
  `percent: Some(p)`; a reader writes `b.percent ?? -1` for 0.1.x's
  value, or matches.

### Added

- **`dev_gyro`**: the `Gyroscope` and `GyroscopeAsync` traits, the
  reading `GyroMilliDps` in milli-degrees per second per axis, the range
  `GyroRange` from ±250 to ±2000 dps, `gyro_full_scale`,
  `gyro_range_for`, and `gyro_milli_dps` from a count at the part's
  sensitivity.
- **`dev_mag`**: the `Magnetometer` and `MagnetometerAsync` traits, the
  reading `MagNanoT` in nanotesla per axis, and `mag_nano_t`.
- **`dev_imu`**: `ImuSample`, `ImuSample9`, and the `Imu` and `Imu9`
  traits that answer an IMU's kinds latched at one instant and read in
  one transaction; `imu_six_of_nine`.  The bundles do not name the kinds
  as supertraits, because a supertrait cannot carry an effect argument;
  a driver implements the kinds beside them.
- **`dev_hygro`**: the `Hygrometer` and `HygrometerAsync` traits, with
  the thermometer's conversion-time contract (`rh_start`,
  `rh_read_after`); the reading `MilliPercentRh`; `rh_of_raw`.
- **`dev_baro`**: the `Barometer` and `BarometerAsync` traits, with the
  same contract (`baro_start`, `baro_read_after`); the reading
  `Pascals`; `baro_of_raw`.  No altitude: it needs the local sea-level
  pressure.
- **`dev_id`**: `DeviceId`, a part's identification byte `who` and
  its revision `rev`, `None` for a part that reports none; the
  `Identifiable` trait with its default `device_probe`, which compares
  `who` alone; and `id_read_i2c` and `id_read_spi`, which read a part's
  identification byte with no driver and leave `rev` `None`.
- **`dev_bus`**: `wiring_read16_into`, `wiring_write16_from` and their
  low-byte-first twins `wiring_read16le_into` and
  `wiring_write16le_from`, for registers at 16-bit addresses, each one
  transaction in the combined format; `wiring_spi_exchange_fill_into`,
  whose reads clock out a filler byte the driver chooses, for a part
  that needs 0x00.  `wiring_spi_exchange_into` keeps 0xFF.  `DevBytes`
  stays 32 bytes: every transfer the kinds name fits, the largest a
  humidity and pressure sensor's 26-byte calibration block, and a FIFO
  is drained a sample at a time.
- **`Accelerometer`**: `accel_set_rate_hz`, answering the rate the part
  took; `accel_fifo_count` and `accel_fifo_read` into a
  `Vec[AccelMilliG; 32]`.  Each has a body for a part without the
  feature, so an existing driver builds unchanged.
- **`RealTimeClock`**: `AlarmMatch` and `rtc_set_alarm_match`, whose
  body passes the once form to `rtc_set_alarm` and refuses the
  repeating forms; `rtc_alarm_matches`, `rtc_to_unix` and
  `rtc_from_unix`.
- **`PowerManager`**: `PowerSource` and `power_source`, and
  `rail_current`, each with a body for a part that cannot tell.
- **`devices.req.nv`**: the README's rules as requirements, each
  checked by the tests that carry its `@satisfies`.
- Test drivers laid out as an ST LSM6DSO with its FIFO, an ST LIS3MDL
  and a Bosch BME280, the last checked against its data sheet's worked
  example; `tests/embedded_probe.sh` also runs the image under QEMU and
  checks its score.

### Changed

- The README's first example names `face_up`, the function it shows,
  and the TMP102 driver stands beside it as the shape a real driver
  takes.  The rules gain the async traits' contract: an async trait
  only waits, and configuration goes through the sync trait.
- `DeviceWiring.bus` is documented as the board file's index, which no
  function here reads.

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
