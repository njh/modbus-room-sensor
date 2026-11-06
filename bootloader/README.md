Flashing the Bootloader
=======================

The first step to setting up a new board is to install a bootloader, using ICSP.
I use the [Atmel AVRISP mkII programmer] to do this.
Note that the ISP does not power the board - so power must be provided either using the terminal block (J1) or 3.3v to the FTDI header (J2).

First check that you can connect to the board using ICSP:
```
avrdude -c avrispmkII -P usb -p m328p -B 10 -v
```

The bootloader can then be written to the board using:
```
avrdude -c avrispmkII -P usb -p m328p -B 10 \
  -e \
  -U flash:w:optiboot_atmega328_pro_8MHz.hex:i \
  -U lfuse:w:0xFF:m \
  -U hfuse:w:0xD4:m \
  -U efuse:w:0xFD:m \
  -U lock:w:0x0F:m
```

Note:
- `-B 10` slows SCK to about 100 kHz, which a new chip running at 1 MHz needs.

You can now use the Arduino IDE to write a sketch to the board.


Fuse settings
-------------

We are using the following fuse settings for an ATmega328P at 3.3V with a 8 MHz external crystal.

| Fuse    | Value  | Meaning |
|---------|--------|---------|
| `lfuse` | `0xFF` | External crystal (low-power oscillator, 8 MHz), no clock divide-by-8, no clock output, 16K CK + 65 ms start-up |
| `hfuse` | `0xD4` | ISP enabled, EEPROM preserved through chip erase (`EESAVE`), 1 kB boot section at `0x7C00`, reset vector at bootloader |
| `efuse` | `0xFD` | Brown-out detection at about 2.7 V |
| `lock ` | `0x0F` | Protects the boot section (reads back as `0xCF`, as the unused top bits read as 1) |

`hfuse` must match the bootloader size, otherwise reset jumps to the wrong address.


Re-generating the Bootloader
----------------------------

The included bootloader was created from the optiboot Github repo:
https://github.com/Optiboot/optiboot

It is compatible with the Pro Mini in the Arduino IDE and was created using the following command:
```
cd optiboot/optiboot/bootloaders/optiboot
make atmega328_pro8 BAUD_RATE=57600 BIGBOOT=1 SUPPORT_EEPROM=1 LED_START_FLASHES=3
```

The resulting file is called `optiboot_atmega328_pro_8MHz.hex`.


[Atmel AVRISP mkII programmer]:  https://www.microchip.com/en-us/development-tool/atavrisp2
