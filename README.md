# devices-nv

A board carries other vendors' chips on its buses: an accelerometer, a
gyroscope, a temperature or humidity sensor, a power-management chip, a
real-time clock, a flash. This package names what a program reads from
each kind of chip as a set of traits, so a program is written against
"an accelerometer" rather than against one part's registers, and a
driver for a part is a type that implements the trait. The drivers are
written over the I2C and SPI bus traits of
[embedded-hal-nv](https://novo-lang.org/packages/embedded-hal-nv) and
the pins a board gives. The design follows Rust's
[`accelerometer`](https://docs.rs/accelerometer) crate and the device
drivers written against [`embedded-hal`](https://docs.rs/embedded-hal).

## What it is

A **peripheral chip**, or device, is an integrated circuit beside the
microcontroller that it talks to over a bus. On an **I2C** bus a device
answers at a seven-bit address. On an **SPI** bus a device is selected
by a **chip-select** pin, which the controller drives low for the
length of a transaction. A device may also drive an **interrupt line**,
a pin it pulses or holds when it has something to report, such as a new
sample or an alarm. `DeviceWiring` records the bus, and as optionals
the address or the chip-select pin and the interrupt pin: a device on
I2C has `addr` and `cs` is `None`, one on SPI the reverse, and `irq` is
`None` when the board wires no interrupt line. The record is a value
with no allocation, so a driver at the embedded tier holds it.

A **trait** is a named set of method signatures, and a **driver** is a
type that implements one for a particular part. A program that takes a
parameter of the trait's type works with any driver, and with a test
double that answers from fixed data. Each trait here takes an **effect
parameter** (SPEC § 5.6): a driver for real hardware supplies `[hw]`,
and a double supplies nothing, so a caller that reads a double declares
no effect.

The kinds of device, and what a reading carries:

| Kind | Sync trait | Async trait | Reading |
| --- | --- | --- | --- |
| Accelerometer | `Accelerometer` | `AccelerometerAsync` | `AccelMilliG`: milli-g per axis |
| Gyroscope | `Gyroscope` | `GyroscopeAsync` | `GyroMilliDps`: milli-degrees per second per axis |
| Magnetometer | `Magnetometer` | `MagnetometerAsync` | `MagNanoT`: nanotesla per axis |
| Thermometer | `Thermometer` | `ThermometerAsync` | `TempMilliC`: milli-degrees Celsius |
| Hygrometer | `Hygrometer` | `HygrometerAsync` | `MilliPercentRh`: thousandths of a percent of relative humidity |
| Barometer | `Barometer` | `BarometerAsync` | `Pascals`: air pressure |
| Power manager | `PowerManager` | `PowerManagerAsync` | `MilliVolts`, `MilliAmps`, `BatteryReading`, `PowerSource` |
| Real-time clock | `RealTimeClock` | `RealTimeClockAsync` | `RtcDateTime`: date and time of day |
| Block storage | embedded-hal-nv's `BlockDevice` | `BlockDeviceAsync` | blocks of bytes |

Each unit is its own type. A voltage cannot be passed where a current
belongs, and a temperature is not an integer a caller has to remember
the scale of. A full-scale range is an enum, `AccelRange` or
`GyroRange`, so a program cannot ask for a range the parts do not have.

An **inertial measurement unit** (IMU) is an accelerometer and a
gyroscope in one part, and sometimes a magnetometer too. Its driver
implements each kind's trait, and also `Imu`, or `Imu9` for nine axes,
whose one method answers a sample of all the kinds latched at one
instant and read in one bus transaction. Most parts also hold an
identification byte, which ST calls WHO_AM_I; `Identifiable` reads it.

The **sync** traits return when the operation is done. The **async**
traits, spelled with `async fn`, let the calling task wait while others
run on a host's scheduler. On a microcontroller at `@tier(embedded)` an
`async fn` is refused, and a device's interrupt line is awaited through
`AsyncDeviceReady` instead: the program arms a wait on a `Future` it
owns, awaits the Future, and then reads the device through its sync
trait.

## Install

```
novo pkg add devices-nv
```

## Example

The program below reports whether a board lies face up. `face_up`
takes any accelerometer, so the same function runs against a driver for
a board's part and, as here, against a recorded sample.

```novo
use dev_accel.{ AccelMilliG, AccelRange, Accelerometer }

// A sample recorded from a board lying flat: 1 g on the z axis.
struct Recorded
    z: Int

// The recording performs no input or output, so it supplies no effect.
impl Accelerometer[] for Recorded
    fn accel_read(self) -> ?AccelMilliG
        Some(AccelMilliG { x: 0, y: 0, z: self.z })

    fn accel_ready(self) -> Bool
        true

    fn accel_range(self) -> AccelRange
        AccelRange.AccelRange2g

    fn accel_set_range(self, r: AccelRange) -> Bool
        false

    fn accel_rate_hz(self) -> Int
        0

// Whether the board lies face up: most of 1 g on the z axis.
fn face_up<A: Accelerometer[e]>(a: A) -> Bool [e]
    match a.accel_read()
        Some(s) => s.z > 800
        None => false

fn main() [io]
    println("${face_up(Recorded { z: 1000 })}")   // true
```

A driver for a real part has the same shape. It holds the board's bus
and the device's wiring, moves the part's bytes with the functions of
`dev_bus`, and converts them with the kind's helper. This one is for a
TI TMP102 thermometer, whose register 0 holds a 12-bit count of 62.5
milli-degrees, left-justified in two bytes:

```novo norun:fragment
use dev_bus.{ DeviceWiring, DevBytes }
use dev_thermo.{ TempMilliC, Thermometer }
use embedded_hal.{ BoardI2c }

@value
struct Tmp102
    bus: BoardI2c
    w: DeviceWiring

impl Thermometer[hw] for Tmp102
    // The part converts continuously.
    fn temp_start(self) -> Int [hw]
        0

    fn temp_read(self) -> ?TempMilliC [hw]
        var b: DevBytes = Vec.new()
        if not dev_bus.wiring_read_into(self.bus, self.w, 0, 2, b)
            return None
        let raw = ((b[0] as Int) << 4) | ((b[1] as Int) >> 4)
        Some(dev_thermo.temp_of_raw(raw, 12, 62500))
```

## What the package contains

| Module | What is in it |
| --- | --- |
| `dev_bus` | `DeviceWiring` and its constructors; register reads and writes over an I2C bus at one-byte and two-byte register addresses; one SPI transaction inside the chip-select window, with the filler byte a read clocks out; the same through `DevBytes` buffers the caller owns; sign extension of a raw count; the `AsyncDeviceReady` trait for an interrupt line. |
| `dev_id` | `DeviceId`, a part's identification byte and its revision when it reports one, the `Identifiable` trait with its probe, and the identification byte read from an I2C or SPI part with no driver. |
| `dev_accel` | The accelerometer traits, `AccelMilliG`, `AccelRange`, and the conversion from a raw count to milli-g. |
| `dev_gyro` | The gyroscope traits, `GyroMilliDps`, `GyroRange`, and the conversion from a raw count at the part's sensitivity. |
| `dev_mag` | The magnetometer traits, `MagNanoT`, and the conversion from a raw count. |
| `dev_imu` | `ImuSample`, `ImuSample9`, and the `Imu` and `Imu9` traits that answer them. |
| `dev_thermo` | The thermometer traits, `TempMilliC`, the conversion from a raw count, and Fahrenheit for display. |
| `dev_hygro` | The hygrometer traits, `MilliPercentRh`, and the conversion from a linear count. |
| `dev_baro` | The barometer traits, `Pascals`, and the conversion from a linear count. |
| `dev_power` | The power-manager traits, `MilliVolts`, `MilliAmps`, `RailState`, `ChargeState`, `BatteryReading` with its optional state of charge, `PowerSource`, and the regulator-step calculation. |
| `dev_rtc` | The real-time-clock traits, `RtcDateTime`, `AlarmMatch`, BCD conversion, the 12-hour form, leap years, month lengths, validity, the day of the week, an alarm's match and Unix time. |

## How to choose an entry point

- A program reads a device through its sync trait, taking it as a
  parameter of the trait's type.
- A program that needs an IMU's kinds at one instant takes `Imu` or
  `Imu9`, and adds the kinds' traits as further bounds to configure
  them: `<D: Imu[e] + Accelerometer[ea] + Gyroscope[eg]>`. Each bound
  binds an effect parameter of its own.
- A program on a host's scheduler that waits for a sample, a
  conversion or an alarm uses the async trait.
- A program at `@tier(embedded)` arms the device's `AsyncDeviceReady`,
  awaits the Future, and then reads through the sync trait.
- A board's bring-up reads each part's identification byte with
  `id_read_i2c` or `id_read_spi`, before any driver exists.
- A driver is written over embedded-hal-nv's `I2cBus` or `SpiBus` with
  the functions of `dev_bus`, and implements the trait of its kind.

## The rules a user needs

1. A reading is an optional. `None` means the device did not answer on
   the bus, which is a fault of the wiring or the part and never a
   reading of zero.
2. `accel_read`, `gyro_read` and `mag_read` answer the most recent
   sample, which may be one the program has already read. The
   `_read_new` forms answer only a sample completed since the last
   read, from the part's data-ready flag.
3. A thermometer's, a hygrometer's and a barometer's conversion takes
   time. `temp_start`, `rh_start` and `baro_start` answer it in
   microseconds, and the `_read_after` forms refuse a read that comes
   before the time has passed: an early read answers a result that is
   not the one asked for.
4. `rail_set_voltage` sets the nearest step at or below the request and
   answers the voltage it set. A rail is never set above its request.
5. A real-time clock's registers hold a plausible time after its backup
   supply failed. `rtc_now_valid` answers `None` when the oscillator
   stopped since the clock was last set.
6. An `RtcDateTime` is in the 24-hour form, in the proleptic Gregorian
   calendar, with no time zone. `rtc_weekday` numbers the days as
   ISO 8601 does, 1 for Monday to 7 for Sunday. `rtc_to_unix` and
   `rtc_from_unix` count seconds from 1970-01-01 with no leap seconds,
   as Unix time does.
7. An I2C register read is one transaction, the register address and a
   repeated start, at a one-byte or a two-byte address. Two
   transactions with a stop between them would let another controller
   on the bus move the register pointer. NXP's I2C-bus specification,
   UM10204, calls the single transaction the combined format.
8. An async trait only waits for an event: a sample, a conversion or an
   alarm. Configuration, such as a range, a rate or an alarm's time,
   goes through the sync trait, which a driver always implements beside
   the async one.
9. `accel_set_rate_hz` sets the slowest rate the part has at or above
   the request and answers the rate the part took. A part's rates are a
   fixed list, so the answer is rarely the request.
10. An alarm fires when the fields its `AlarmMatch` selects match the
    clock. `AlarmEveryDay` at 07:00:00 fires each morning at seven;
    `rtc_set_alarm` is the `AlarmOnce` form.
11. A transfer through a `DevBytes` buffer holds at most 32 bytes. A
    longer one is refused rather than cut short.
12. An SPI read clocks out a filler byte for each byte it reads, 0xFF
    unless the driver passes another. A part that reads 0xFF as a
    command takes 0x00 through `wiring_spi_exchange_fill_into`.
13. `device_probe` answers `false` both for a part that does not answer
    and for one that answers another identification byte. Either way
    the board does not carry the expected part at that place.
14. An IMU's paired sample is read in one bus transaction, so its kinds
    describe one instant. Two reads, one per kind, may straddle a new
    sample.

`Imu` and `Imu9` do not name the kinds as supertraits, because a
supertrait cannot carry an effect argument. A driver implements the
kinds beside the bundle all the same, so it keeps building if the
bundle later names them as supertraits.

## Running on a microcontroller

The sync traits and `AsyncDeviceReady` are written for a
microcontroller with no heap: every reading is a value type carried in
the caller's frame, and an optional reading is a flag beside it, so
answering one allocates nothing. The async traits are for a host's
scheduler.

A driver moves a device's bytes with the functions of `dev_bus`, which
come in two forms:

- `wiring_read`, `wiring_write` and `wiring_spi_exchange` take and
  return lists. On a microcontroller a list is built only inside a
  `system` block, and these build theirs there, each of a known size,
  so a driver may call them; a driver that writes a list of its own
  needs a `system` block for it.
- The `_into` and `_from` forms move the bytes through a `DevBytes`, a
  buffer of up to 32 bytes the driver keeps in its own frame, so the
  driver builds no list. The SPI transactions build none at all. The
  I2C forms hand the bus a list, because embedded-hal-nv's `I2cBus`
  takes and answers lists, and release it before returning.

`dev_bus` checks clean at the embedded, rt and system tiers. It builds
its lists in `system` blocks, which the wasm and app tiers refuse, so
the registry lists it without wasm and app. Every other module checks
clean at every tier. `tests/embedded_probe.sh` builds a firmware image
that uses every module, with a driver of the TMP102's shape, for
`--target=nrf52-qemu` and `--target=frdm-mcxn947`, and runs the first
under QEMU.

## What is not included

- Drivers for particular parts. Each is a package of its own, which
  anyone may publish, and a program chooses among them with
  `novo pkg add`.
- A fused orientation. Combining an IMU's kinds into a heading or an
  attitude is a filter with its own tuning, which belongs to the
  application or a package of its own.
- Altitude from pressure. It needs the pressure at sea level where the
  board is, which changes with the weather.
- Byte memory such as an EEPROM, a GPIO expander and a light sensor.
  Each needs its own design.
- A display trait. A display moves frames rather than readings.
- A block-storage trait of its own. Block storage is embedded-hal-nv's
  `BlockDevice`, the trait the runtime's block hooks and the
  filesystems already sit on, and a storage driver implements it over
  `SpiBus` as the other drivers implement theirs.
- Floating-point readings. Every reading is an integer in a stated
  unit, which a microcontroller without a floating-point unit handles
  at full speed.

## Related packages

- [embedded-hal-nv](https://novo-lang.org/packages/embedded-hal-nv)
  names the microcontroller's own peripherals: GPIO, UART, timers, the
  I2C and SPI buses this package's drivers are written over, and block
  storage.

## Tests

Each suite under `tests/` implements a trait on a test double: an I2C
bus with a register file, an SPI bus that answers fixed bytes, and a
GPIO port that checks the chip-select pin's levels. The drivers in the
suites are laid out as real parts are: an ST LIS3DH accelerometer, an
ST LSM6DSO accelerometer and gyroscope with its FIFO, an ST LIS3MDL
magnetometer, a TI TMP102 thermometer, a Bosch BME280 humidity,
pressure and temperature sensor computed with its data sheet's integer
formulas, an Analog Devices DS3231 clock with its alarm masks, and an
Adesto AT45DB flash. The suites assert what each register read and
write carries, and the BME280's readings of the data sheet's worked
example. A second implementation of each trait performs nothing and
supplies no effect.

Each numbered rule above is a requirement in `devices.req.nv`, and the
tests that check it carry `@satisfies` with its identifier, so
`novo req check` names a rule that no test checks. `tests/coverage.sh`
merges the suites' line coverage over `src/`, and
`tests/embedded_probe.sh` builds the package for two microcontroller
boards and runs it on the emulated one.

```
novo pkg build
novo test tests
novo req check
bash tests/coverage.sh
bash tests/embedded_probe.sh
```

## Licence

Apache-2.0. See `LICENSE`.
