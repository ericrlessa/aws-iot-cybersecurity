data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_security_group" "access_sg" {
  name        = "mosquitto-sg"
  description = "Allow Mosquitto and SSH access"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 1883
    to_port     = 1883
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
    description = "MQTT access"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
    description = "SSH access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "mosquitto" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.access_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "mosquitto-server"
  }

  user_data = <<-EOF
            #!/bin/bash
            set -eux

            apt-get update -y

            # -----------------------------
            # Install Mosquitto
            # -----------------------------
            apt-get install -y mosquitto mosquitto-clients

            cat <<EOT > /etc/mosquitto/conf.d/default.conf
            listener 1883
            allow_anonymous true
            EOT

            systemctl enable mosquitto
            systemctl restart mosquitto

            # -----------------------------
            # Install Suricata
            # -----------------------------
            apt-get install -y suricata jq

            # Update rules
            suricata-update

            # -----------------------------
            # Get interface
            # -----------------------------
            INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')
            echo "Using interface $INTERFACE for Suricata"

            # -----------------------------
            # Backup and modify main config
            # -----------------------------
            cp /etc/suricata/suricata.yaml /etc/suricata/suricata.yaml.bak

            # Update interface in af-packet section
            sed -i "s/interface: eth0/interface: $INTERFACE/g" /etc/suricata/suricata.yaml

            # Ensure af-packet is used (uncomment if needed)
            sed -i 's/#- af-packet:/  - af-packet:/' /etc/suricata/suricata.yaml

            # Configure outputs if needed
            sed -i 's/#enabled: yes/enabled: yes/' /etc/suricata/suricata.yaml

            # -----------------------------
            # Add custom rules
            # -----------------------------
            cat <<EOT > /etc/suricata/rules/local.rules
            alert tcp any any -> \$HOME_NET 1883 (msg:"High MQTT Traffic Rate"; threshold: type both, track by_dst, count 500, seconds 60; sid:1000001;)
            alert tcp any any -> \$HOME_NET 1883 (msg:"Large MQTT Packet"; dsize:>1024; sid:1000002;)
            EOT

            # Set rule path and include local.rules
            sed -i 's|default-rule-path: /var/lib/suricata/rules|default-rule-path: /etc/suricata/rules|' /etc/suricata/suricata.yaml
            sed -i '/rule-files:/a\  - local.rules' /etc/suricata/suricata.yaml

            # -----------------------------
            # Start Suricata
            # -----------------------------
            systemctl enable suricata
            systemctl restart suricata

            # -----------------------------
            # Install Filebeat
            # -----------------------------
            curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-9.3.2-amd64.deb
            dpkg -i filebeat-9.3.2-amd64.deb || apt-get install -f -y

            systemctl enable filebeat
            systemctl restart filebeat

            EOF
}