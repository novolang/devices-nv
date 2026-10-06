# devices-nv

A board carries other vendors' chips on its buses: an accelerometer, a
temperature sensor, a power-management chip, a real-time clock, a
flash. This package names what a program reads from each kind of chip
as a set of traits, so a program is written against "an accelerometer"
rather than against one part's registers, and a driver for a part is a
type that implements the trait. The drivers are written over the I2C
and SPI bus traits of [embedded-hal-nv](https://novo-lang.org/packages/embedded-hal-nv)
and the pins a board gives. The design follows Rust's
[`accelerometer`](https://docs.rs/accelerometer) crate and the device
drivers written against [`embedded-hal`](https://docs.rs/embedded-hal).

## What it is

A **peripheral chip**, or device, is an integrated circuit beside the
microcontroller that it talks to over a bus. On an **I2C** bus a device
answers at a seven-bit address. On an **SPI** bus a device is selected
by a **chip-select** pin, which the controller drives low for the
length of a transaction. A device may also drive an **interrupt line**,
a pin it pulses or holds when it has something to report, such as a new
sample or an alarm. `DeviceWiring` records the bus, the address or the
chip-select pin, and the interrupt pin a device uses.

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
| Thermometer | `Thermometer` | `ThermometerAsync` | `TempMilliC`: milli-degrees Celsius |
| Power manager | `PowerManager` | `PowerManagerAsync` | `MilliVolts`, `MilliAmps`, `BatteryReading` |
| Real-time clock | `RealTimeClock` | `RealTimeClockAsync` | `RtcDateTime`: date and time of day |
| Block storage | embedded-hal-nv's `BlockDevice` | `BlockDeviceAsync` | blocks of bytes |

Each unit is its own type. A voltage cannot be passed where a current
belongs, and a temperature is not an integer a caller has to remember
the scale of. The full-scale range of an accelerometer is the enum
`AccelRange`, so a program cannot ask for a range the parts do not
have.

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

The program below reports whether a board lies face up. `level` takes
any accelerometer, so the same function runs against a driver for a
board's part and, as here, against a recorded sample.

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

## What the package contains

| Module | What is in it |
| --- | --- |
| `dev_bus` | `DeviceWiring` and its constructors; register reads and writes over an I2C bus; one SPI transaction inside the chip-select window; sign extension of a raw count; the `AsyncDeviceReady` trait for an interrupt line. |
| `dev_accel` | The accelerometer traits, `AccelMilliG`, `AccelRange`, and the conversion from a raw count to milli-g. |
| `dev_thermo` | The thermometer traits, `TempMilliC`, the conversion from a raw count, and Fahrenheit for display. |
| `dev_power` | The power-manager traits, `MilliVolts`, `MilliAmps`, `RailState`, `ChargeState`, `BatteryReading`, and the regulator-step calculation. |
| `dev_rtc` | The real-time-clock traits, `RtcDateTime`, BCD conversion, the 12-hour form, leap years, month lengths, validity and the day of the week. |

## How to choose an entry point

- A program reads a device through its sync trait, taking it as a
  parameter of the trait's type.
- A program on a host's scheduler that waits for a sample, a
  conversion or an alarm uses the async trait.
- A program at `@tier(embedded)` arms the device's `AsyncDeviceReady`,
  awaits the Future, and then reads through the sync trait.
- A driver is written over embedded-hal-nv's `I2cBus` or `SpiBus` with
  the functions of `dev_bus`, and implements the trait of its kind.

## The rules a user needs

1. A reading is an optional. `None` means the device did not answer on
   the bus, which is a fault of the wiring or the part and never a
   reading of zero.
2. `accel_read` answers the most recent sample, which may be one the
   program has already read. `accel_read_new` answers only a sample
   completed since the last read, from the part's data-ready flag.
3. A thermometer's conversion takes time. `temp_start` answers it in
   microseconds, and `temp_read_after` refuses a read that comes
   before the time has passed: an early read answers a result that is
   not the one asked for.
4. `rail_set_voltage` sets the nearest step at or below the request and
   answers the voltage it set. A rail is never set above its request.
5. A real-time clock's registers hold a plausible time after its backup
   supply failed. `rtc_now_valid` answers `None` when the oscillator
   stopped since the clock was last set.
6. An `RtcDateTime` is in the 24-hour form, in the proleptic Gregorian
   calendar, with no time zone. `rtc_weekday` numbers the days as
   ISO 8601 does, 1 for Monday to 7 for Sunday.
7. An I2C register read is one transaction, the register address and a
   repeated start. Two transactions with a stop between them would let
   another controller on the bus move the register pointer. NXP's
   I2C-bus specification, UM10204, calls the single transaction the
   combined format.

## Running on a microcontroller

The sync traits and `AsyncDeviceReady` are written for a
microcontroller with no heap: every reading is a value type carried in
the caller's frame, and an optional reading is a flag beside it, so
answering one allocates nothing. The functions of `dev_bus` that move
bytes take and return lists, which a program at `@tier(embedded)`
builds only into storage it owns. The async traits are for a host's
scheduler.

## What is not included

- Drivers for particular parts. Each is a package of its own, which
  anyone may publish, and a program chooses among them with
  `novo pkg add`.
- A display trait. A display moves frames rather than readings, and
  needs its own design.
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
- [i2c-devices-nv](https://novo-lang.org/packages/i2c-devices-nv)
  declares drivers for four I2C sensors over a bus trait of its own.

## Tests

Each suite under `tests/` implements a trait on a test double: an I2C
bus with a register file, an SPI bus that answers fixed bytes, and a
GPIO port that checks the chip-select pin's levels. The drivers in the
suites are laid out as real parts are, an ST LIS3DH accelerometer, a
TI TMP102 thermometer, an Analog Devices DS3231 clock and an Adesto
AT45DB flash, and the suites assert what each register read and write
carries. A second implementation of each trait performs nothing and
supplies no effect. `tests/coverage.sh` merges the suites' line
coverage over `src/`.

```
novo pkg build
novo test tests
bash tests/coverage.sh
```

## Licence

Apache-2.0. See `LICENSE`.
