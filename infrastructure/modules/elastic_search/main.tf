# Ubuntu 22.04 LTS
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Security group for Elasticsearch
resource "aws_security_group" "elasticsearch_sg" {
  name        = "elasticsearch-sg"
  description = "Private SG for Elasticsearch node"
  vpc_id      = var.vpc_id

  # Allow Filebeat agents to send logs (port 5044)
  ingress {
    description     = "Filebeat agents send logs"
    from_port       = 5044
    to_port         = 5044
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
   # security_groups = [var.filebeat_sg_id]
  }

  # Allow Kibana to access Elasticsearch API (port 9200)
  ingress {
    description     = "Kibana access"
    from_port       = 9200
    to_port         = 9200
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
    #security_groups = [var.kibana_sg_id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  # Outbound: allow all (needed for updates / cloud-init)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_instance" "elasticsearch" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.medium"
  subnet_id                   = var.private_subnet_id
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.elasticsearch_sg.id]
  associate_public_ip_address = false

  tags = {
    Name = "elasticsearch-node"
  }

  user_data = <<-EOF
               #!/bin/bash
               set -eux

               apt-get update -y

               wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
               apt-get install apt-transport-https
               echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/9.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-9.x.list
               apt-get update -y && apt-get install elasticsearch -y

               sed -i 's/^#network.host:.*/network.host: 0.0.0.0/' /etc/elasticsearch/elasticsearch.yml
               sed -i 's/^#transport.host:.*/transport.host: 0.0.0.0/' /etc/elasticsearch/elasticsearch.yml

               systemctl daemon-reload
               systemctl enable elasticsearch.service

               systemctl start elasticsearch.service

               EOF
}