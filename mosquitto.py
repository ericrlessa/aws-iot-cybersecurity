import paho.mqtt.client as mqtt  # For EC2 Mosquitto 
import logging
import os

MOSQUITTO_HOST = os.environ.get('MOSQUITTO_HOST', 'localhost')
MOSQUITTO_PORT = 1883 
MOSQUITTO_TOPIC = "temp/data"

class EC2MQTTClient:
    def __init__(self):
        self.client = mqtt.Client()
        self.client.on_connect = self.on_connect
        self.connected = False

    def on_connect(self, client, userdata, flags, rc):
        logging.info("connected to mosquitto broker!")
        self.connected = True

    def connect(self):
        logging.info("Starting connection to mosquitto broker...")
        self.client.connect(MOSQUITTO_HOST, MOSQUITTO_PORT)
        self.client.loop_start()

    def publish(self, payload):
        if not self.connected:
            raise Exception("Not connected")
        self.client.publish(MOSQUITTO_TOPIC, payload)
