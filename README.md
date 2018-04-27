# DS18B20-Search-RomIDs on ESP32 ULP

install and test run:

1. git clone https://github.com/fhng/DS18B20-Search-RomIDs.git
2. cd to project file
3. make menuconfig
4. make flash monitor

main project is here https://github.com/fhng/ESP32-ULP-1-Wire, this project has a longer/better readme.

## Example output

Note: GPI015 is connected to GND to disable ROM bootloader output.

Note: I only have 2 DS18B20 so I searched two time.
```
Not ULP wakeup, inititializing ULP
Entering deep sleep
<<<<<< Result: 1 >>>>>>
<<<<<< Total Byte: 16 >>>>>>
<<<<<< Number of Devices: 2 >>>>>>

---- RomID 1 Byte 1--------- 0x28
---- RomID 1 Byte 2--------- 0x20
---- RomID 1 Byte 3--------- 0x24
---- RomID 1 Byte 4--------- 0xb0
---- RomID 1 Byte 5--------- 0x6
---- RomID 1 Byte 6--------- 0x0
---- RomID 1 Byte 7--------- 0x0
---- RomID 1 Byte 8--------- 0xf

---- RomID 2 Byte 1--------- 0x28
---- RomID 2 Byte 2--------- 0x9b
---- RomID 2 Byte 3--------- 0x58
---- RomID 2 Byte 4--------- 0xaf
---- RomID 2 Byte 5--------- 0x6
---- RomID 2 Byte 6--------- 0x0
---- RomID 2 Byte 7--------- 0x0
---- RomID 2 Byte 8--------- 0x1e

Entering deep sleep
```
