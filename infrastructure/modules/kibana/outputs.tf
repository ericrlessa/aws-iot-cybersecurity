output "kibana_public_ip" {
  value = aws_instance.kibana.public_ip
}

output "kibana_private_ip" {
  value = aws_instance.kibana.private_ip
}