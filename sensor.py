import board
import logging
import adafruit_ahtx0

logging.basicConfig(level=logging.DEBUG)

def main():
    logging.info("Initializing sensor reading...")

    sensor = adafruit_ahtx0.AHTx0(board.I2C())

    temperature = sensor.temperature
    humidity = sensor.relative_humidity
            
    logging.info("")
    logging.info(f"\tTemperature = {temperature:.2f}°C")
    logging.info(f"\tHumidity    = {humidity:.2f}%")
    logging.info("")

    logging.info("Sensor read successfully!")
    

if __name__ == "__main__":
    main()