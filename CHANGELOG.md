# Changelog

All notable changes to devices-nv are recorded here. The format is
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
with the pre-1.0 rule that a breaking change bumps the MINOR number.

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
