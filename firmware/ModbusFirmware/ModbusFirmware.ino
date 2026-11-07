/*
 * Main firmware for the Modbus Room Sensor
 *
 * Reads temperature and humidity from the SHT4x breakout and publishes
 * them as Modbus RTU input registers over RS-485.
 *
 * Board: Arduino Pro or Pro Mini, ATmega328P (3.3V, 8 MHz)
 * Libraries: ModbusRTUSlave and Sensirion I2C SHT4x
 *
 * Modbus settings: 9600 baud, 8N1. The unit ID is set by the jumpers on J6,
 * which are read at power-up. With no jumpers fitted, the unit ID is 1.
 *
 * Modbus only works over RS-485 (J1). The RS-485 receiver drives the UART RX
 * line, so it blocks anything sent from the FTDI header (J2).
 *
 * Input registers (function code 4):
 *
 *   Address  Value
 *   0x0001   Temperature, in tenths of a degree C (signed)
 *   0x0002   Relative humidity, in tenths of a percent
 *
 * Both read 0x8000 if the sensor couldn't be read.
 */

#include <Arduino.h>
#include <ModbusRTUSlave.h>
#include <SensirionI2cSht4x.h>
#include <Wire.h>

// make sure that we use the proper definition of NO_ERROR
#ifdef NO_ERROR
#undef NO_ERROR
#endif
#define NO_ERROR 0

const unsigned long MODBUS_BAUD = 9600;
const uint8_t DEFAULT_UNIT_ID = 1;

// RS-485 transceiver (U3) driver enable (DE) and receiver enable (RE)
const uint8_t TXEN_PIN = 2;
const uint8_t RXEN_PIN = 3;

// Unit ID jumpers on J6, lowest bit first (silkscreen 1, 2, 4, 8).
// A fitted jumper connects the pin to GND and sets that bit.
const uint8_t unitIdPins[] = {A0, A1, A2, A3};

// How often to take readings from the SHT4X sensor
const unsigned long MEASUREMENT_INTERVAL = 2000;  // ms

// Input register addresses
enum {
    REG_TEMPERATURE = 1,
    REG_HUMIDITY = 2,
    NUM_INPUT_REGISTERS
};

// Register value when there is no valid reading
const uint16_t NO_READING = 0x8000;

uint16_t inputRegisters[NUM_INPUT_REGISTERS];

ModbusRTUSlave modbus(Serial, TXEN_PIN, RXEN_PIN);
SensirionI2cSht4x sensor;


uint8_t readUnitId() {
    uint8_t unitId = 0;

    // Turn on the pull-ups, then give the pins time to settle
    for (uint8_t i = 0; i < sizeof(unitIdPins); i++) {
        pinMode(unitIdPins[i], INPUT_PULLUP);
    }
    delay(1);

    // A fitted jumper draws current through its pull-up, so turn that one off;
    // the jumper holds the pin low. The pull-ups on open pins draw nothing and
    // stay on, so those pins don't float.
    for (uint8_t i = 0; i < sizeof(unitIdPins); i++) {
        if (digitalRead(unitIdPins[i]) == LOW) {
            unitId |= 1 << i;
            pinMode(unitIdPins[i], INPUT);
        }
    }

    return unitId;
}

void readSensor() {
    float temperature = 0.0;
    float humidity = 0.0;

    int16_t error = sensor.measureHighPrecision(temperature, humidity);
    if (error != NO_ERROR) {
        inputRegisters[REG_TEMPERATURE] = NO_READING;
        inputRegisters[REG_HUMIDITY] = NO_READING;
        return;
    }

    // The SHT4x can report slightly outside 0-100 %RH, which the datasheet
    // says to crop
    humidity = constrain(humidity, 0.0, 100.0);

    inputRegisters[REG_TEMPERATURE] = (int16_t)round(temperature * 10);
    inputRegisters[REG_HUMIDITY] = round(humidity * 10);
}

// Print details that identify the board, for when an FTDI cable is connected
void printInfo(uint8_t unitId) {
    Serial.println();
    Serial.print(F("Firmware built: "));
    Serial.print(F(__TIME__));
    Serial.print(' ');
    Serial.println(F(__DATE__));

    Serial.print(F("Unit ID: "));
    Serial.println(unitId);

    uint32_t serialNumber = 0;
    int16_t error = sensor.serialNumber(serialNumber);
    if (error == NO_ERROR) {
        // Print all 8 digits, as print(HEX) leaves out leading zeros
        Serial.print(F("SHT4x serial: 0x"));
        for (int8_t shift = 28; shift >= 0; shift -= 4) {
            Serial.print((serialNumber >> shift) & 0xF, HEX);
        }
        Serial.println();
    } else {
        // errorToString() would keep all its messages in RAM, so print the code
        Serial.print(F("SHT4x error: 0x"));
        Serial.println(error, HEX);
    }
}

void setup() {

    // Light the LED while starting up
    pinMode(LED_BUILTIN, OUTPUT);
    digitalWrite(LED_BUILTIN, HIGH);

    uint8_t unitId = readUnitId();
    if (unitId == 0) {
        unitId = DEFAULT_UNIT_ID;
    }

    Wire.begin();
    // Give up on a stuck I2C bus, rather than hang and stop answering Modbus
    Wire.setWireTimeout(25000, true);
    sensor.begin(Wire, SHT41_I2C_ADDR_44);
    sensor.softReset();
    delay(10);

    // Take the first reading now, so the registers are valid from the start
    readSensor();

    // The transceiver's pull-down on DE keeps its driver off until Modbus
    // starts, so this only goes to the FTDI header
    Serial.begin(MODBUS_BAUD, SERIAL_8N1);
    printInfo(unitId);
    // Finish sending it, so none goes onto the bus with the first response
    Serial.flush();

	// Now start Modbus / RS-485
    modbus.configureInputRegisters(inputRegisters, NUM_INPUT_REGISTERS);
    modbus.begin(unitId, MODBUS_BAUD, SERIAL_8N1);

    // Turn off the LED now we are ready to go
    digitalWrite(LED_BUILTIN, LOW);
}

void loop() {
    static unsigned long lastMeasurement = 0;
    if (millis() - lastMeasurement >= MEASUREMENT_INTERVAL) {
        lastMeasurement = millis();
        readSensor();
    }

	modbus.poll();
}
