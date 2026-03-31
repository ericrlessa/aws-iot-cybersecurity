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
  subnet_id                   = var.subnet_id
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.access_sg.id]
  associate_public_ip_address = false
  iam_instance_profile = aws_iam_instance_profile.mosquitto_profile.name


  tags = {
    Name = "mosquitto-server"
  }

  user_data = <<-EOF
            #!/bin/bash
            set -eux

            apt-get update -y

            apt-get install -y awscli

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
            sudo apt-get install software-properties-common -y
            sudo add-apt-repository ppa:oisf/suricata-stable -y
            sudo apt update -y
            sudo apt install suricata jq -y

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
            sed -i "s/interface: eth2/interface: $INTERFACE/g" /etc/suricata/suricata.yaml

            # Ensure af-packet is used (uncomment if needed)
            sed -i 's/#- af-packet:/  - af-packet:/' /etc/suricata/suricata.yaml

            # Configure outputs if needed
            sed -i 's/#enabled: yes/enabled: yes/' /etc/suricata/suricata.yaml

            # -----------------------------
            # Add custom rules
            # -----------------------------
            mkdir -p /var/lib/suricata/rules/

            # Use 'EOT' with quotes to preserve $HOME_NET as a literal Suricata variable
            cat <<'EOT' > /var/lib/suricata/rules/local.rules
            alert tcp any any -> $HOME_NET 1883 (msg:"High MQTT Traffic Rate"; flow: stateless; threshold: type both, track by_dst, count 500, seconds 60; sid:1000001;)
            alert tcp any any -> $HOME_NET 1883 (msg:"Large MQTT Packet"; dsize:>1024; sid:1000002;)
            EOT

            # # Set rule path and include local.rules            
            sed -i '/rule-files:/a\  - /var/lib/suricata/rules/local.rules' /etc/suricata/suricata.yaml

            # Update rules
            suricata-update
            suricata-update enable-source et/open

            # -----------------------------
            # Start Suricata
            # -----------------------------
            systemctl enable suricata
            systemctl start suricata

            # -----------------------------
            # Install Filebeat
            # -----------------------------
            curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-9.3.2-amd64.deb
            dpkg -i filebeat-9.3.2-amd64.deb || apt-get install -f -y           
            

            systemctl enable filebeat

            filebeat modules enable suricata

            # Wait a moment to ensure the file is created
            sleep 2


            ELASTIC_PASSWORD=$(aws secretsmanager get-secret-value \
                            --secret-id "elasticsearch/elastic_password" \
                            --query 'SecretString' \
                            --region ${var.region} \
                            --output text | jq -r '.password')

            # Enable the module
            sed -i "s/enabled: false/enabled: true/g" /etc/filebeat/modules.d/suricata.yml

            # Uncomment and set the path
            sed -i "s|#var.paths:|var.paths: [\"/var/log/suricata/eve.json\"]|g" /etc/filebeat/modules.d/suricata.yml

            # Change host from localhost to Elasticsearch server
            sed -i 's|hosts: \["localhost:9200"\]|hosts: ["https://${var.elasticsearch_ip}:9200"]|' /etc/filebeat/filebeat.yml

            # Uncomment and set protocol to https
            sed -i 's|#protocol: "https"|protocol: "https"|g' /etc/filebeat/filebeat.yml

            # Uncomment username line
            sed -i 's|#username: "elastic"|username: "elastic"|g' /etc/filebeat/filebeat.yml

            # Uncomment password line and set the password
            sed -i "s|#password: \"changeme\"|password: \"$ELASTIC_PASSWORD\"|g" /etc/filebeat/filebeat.yml

            # Add SSL verification mode
            sed -i "/password: \"$ELASTIC_PASSWORD\"/a\  ssl.verification_mode: none" /etc/filebeat/filebeat.yml

            # Change Kibana hosts
            sed -i 's|#host: "localhost:5601"|host: "http://${var.kibana_ip}:5601"|' /etc/filebeat/filebeat.yml
            

            systemctl start filebeat

            # Run setup to load dashboards and pipelines
            echo "Running Filebeat setup..."
            filebeat setup -e 2>&1 | tee /var/log/filebeat-setup.log

            EOF
}

resource "aws_iam_role" "mosquitto_role" {
  name = "mosquitto-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Minimal Secrets Manager policy (only create-secret)
resource "aws_iam_policy" "mosquitto_secrets" {
  name        = "mosquitto-secrets-policy"
  description = "Allow mosquitto to get mosquitto_password secret"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "mosquitto_secrets" {
  role       = aws_iam_role.mosquitto_role.name
  policy_arn = aws_iam_policy.mosquitto_secrets.arn
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "mosquitto_profile" {
  name = "mosquitto-instance-profile"
  role = aws_iam_role.mosquitto_role.name
}

# Register the Mosquitto instance with the target group
resource "aws_lb_target_group_attachment" "mosquitto" {
  target_group_arn =  var.target_group
  target_id        = aws_instance.mosquitto.id
  port             = 1883
}
