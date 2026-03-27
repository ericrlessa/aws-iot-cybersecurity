import time
import board
import logging
import adafruit_ahtx0
from pubsub_aws_iot import publish, get_connection
from mosquitto import EC2MQTTClient
import json
from threading import Thread

logging.basicConfig(level=logging.DEBUG)

sensor = adafruit_ahtx0.AHTx0(board.I2C())

ec2client = EC2MQTTClient()
ec2client.connect()

def send_ddos():
    while True:
        try:
            for _ in range(50):  # Flood to trigger Suricata "High MQTT Traffic Rate" 
                ec2client.publish("DDoS Attack!") 
                logging.info("DDoS simulation sent to EC2.") 
                time.sleep(0.1)  # Short burst 
        except Exception as e: 
            logging.error(f"Error in DDoS simulation: {e}") 
            time.sleep(5) 

def send_malformed():
    while True: 
        try: 
            ec2client.publish("{malformed: data")  # Invalid JSON to trigger Suricata
            logging.info("Malformed payload sent to EC2.") 
            time.sleep(2) 
        except Exception as e: 
            logging.error(f"Error in malformed payload simulation: {e}") 
            time.sleep(5) 

def send_normal_data(): 
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

            ec2client.publish(payload)
            logging.info("Message published to Mosquitto broker.")
            
            time.sleep(5)
        except Exception as e:
            logging.error(f"Error reading sensor or publishing data: {e}")
            time.sleep(5) # Wait for a bit before retrying

def main():


    while not ec2client.is_connected():
        logging.debug("Waiting for connection to broker...")
        time.sleep(2)
    
    logging.debug("Connected to the broker")

    Thread(target=send_normal_data).start() 
    Thread(target=send_ddos).start() 
    Thread(target=send_malformed).start() 

    while True: 
        time.sleep(1) 

if __name__ == "__main__":
    main()