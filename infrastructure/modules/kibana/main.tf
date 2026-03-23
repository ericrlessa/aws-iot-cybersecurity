data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_security_group" "kibana_sg" {
  name        = "kibana-sg"
  description = "Allow Kibana access and connectivity to Elasticsearch"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5601
    to_port     = 5601
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
    description = "Allow Kibana access from admin"
  }

  # SSH access from your IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
    description = "SSH access for admin"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_instance" "kibana" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.kibana_sg.id]
  associate_public_ip_address = true
  tags = { Name = "kibana-server" }

  # user_data = <<-EOF
  #             #!/bin/bash
  #             set -eux

  #             # Update and install dependencies
  #             apt-get update -y
  #             apt-get install -y wget apt-transport-https curl gnupg

  #             # Elasticsearch repo (needed for Kibana)
  #             wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
  #             echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-8.x.list
  #             apt-get update -y

  #             # Install Kibana
  #             apt-get install -y kibana

  #             # Configure Kibana to connect to Elasticsearch
  #             sed -i "s|#elasticsearch.hosts:.*|elasticsearch.hosts: [\"http://${var.elasticsearch_ip}:9200\"]|" /etc/kibana/kibana.yml

  #             # Allow browser access
  #             sed -i "s/#server.host: .*/server.host: 0.0.0.0/" /etc/kibana/kibana.yml

  #             # Enable and start Kibana
  #             systemctl enable kibana
  #             systemctl start kibana
  #             EOF
}

