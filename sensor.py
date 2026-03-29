import board
import logging
import adafruit_ahtx0

logging.basicConfig(level=logging.DEBUG)

def main():
    logging.info("Initializing sensor reading...")

    sensor = adafruit_ahtx0.AHTx0(board.I2C())

    temperature = sensor.temperature
    humidity = sensor.relative_humidity
            
    logging.info(f"Sensor reading successful: Temperature={temperature:.2f}°C, Humidity={humidity:.2f}%")

if __name__ == "__main__":
    main()