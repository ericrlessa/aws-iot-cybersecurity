import time
import board
import logging
import adafruit_ahtx0
from pubsub_aws_iot import publish, get_connection
from mosquitto import EC2MQTTClient

logging.basicConfig(level=logging.DEBUG)



def main():
    sensor = adafruit_ahtx0.AHTx0(board.I2C())

    ec2client = EC2MQTTClient()
    ec2client.connect()

    while True:
        try:
            temperature = sensor.temperature
            humidity = sensor.relative_humidity
            
            logging.info(f"Temperature: {temperature:.2f}C")
            logging.info(f"Humidity: {humidity:.2f}%")
            
            for _ in range(50):  # Flood to trigger Suricata "High MQTT Traffic Rate" 
                ec2client.publish("DDoS Attack!") 
                logging.info("DDoS simulation sent to EC2.") 
                time.sleep(0.1)  # Short burst 

        except Exception as e:
            logging.error(f"Error reading sensor or publishing data: {e}")
            time.sleep(5) # Wait for a bit before retrying

if __name__ == "main":
    main()