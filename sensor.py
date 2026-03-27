import time
import board
import logging
import adafruit_ahtx0
from pubsub_aws_iot import publish, get_connection
from mosquitto import EC2MQTTClient
import json


logging.basicConfig(level=logging.DEBUG)

sensor = adafruit_ahtx0.AHTx0(board.I2C())

connection = get_connection('pi-aht20-client')

ec2client = EC2MQTTClient()
ec2client.connect()

topic = "devices/iot-temperature-humidity-01/data"

while True:
    try:
        temperature = sensor.temperature
        humidity = sensor.relative_humidity
        
        logging.info(f"Temperature: {temperature:.2f}C")
        logging.info(f"Humidity: {humidity:.2f}%")
        
        payload = json.dumps(
            {
                "temperature": round(temperature, 2),
                "humidity": round(humidity, 2)
            }
        )

        publish(connection, payload, topic)
        logging.info("Message published to AWS IoT Core.")

        ec2client.publish(payload)
        logging.info("Message published to Mosquitto broker.")
        
        time.sleep(5)
    except Exception as e:
        logging.error(f"Error reading sensor or publishing data: {e}")
        time.sleep(5) # Wait for a bit before retrying