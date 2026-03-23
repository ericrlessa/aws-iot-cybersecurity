output "kibana_public_ip" {
  value = aws_instance.mosquitto.public_ip
}