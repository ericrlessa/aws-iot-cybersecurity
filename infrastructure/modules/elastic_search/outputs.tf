
# Output private IP
output "elasticsearch_private_ip" {
  value = aws_instance.elasticsearch.private_ip
}

output "elasticsearch_sg_id" {
  value = aws_security_group.elasticsearch_sg.id
}