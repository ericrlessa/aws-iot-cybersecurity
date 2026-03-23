import paho.mqtt.client as mqtt  # For EC2 Mosquitto 
import logging

EC2_HOST = "<IP>"
EC2_PORT = 1883 
EC2_TOPIC = "temp/data"

class EC2MQTTClient:
    def __init__(self):
        self.client = mqtt.Client()
        self.client.on_connect = self.on_connect
        self.connected = False

    def on_connect(self, client, userdata, flags, rc):
        self.connected = True

    def connect(self):
        self.client.connect(EC2_HOST, EC2_PORT)
        self.client.loop_start()

    def publish(self, payload):
        if not self.connected:
            raise Exception("Not connected")
        self.client.publish(EC2_TOPIC, payload)
