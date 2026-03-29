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
  iam_instance_profile = aws_iam_instance_profile.elasticsearch_profile.name


  tags = {
    Name = "elasticsearch-node"
  }

  user_data = <<-EOF
              #!/bin/bash
              set -eux

              wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
              apt-get install apt-transport-https
              echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/9.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-9.x.list
              apt-get update -y && apt-get install elasticsearch -y && apt-get install awscli -y

              sed -i 's/^#network.host:.*/network.host: 0.0.0.0/' /etc/elasticsearch/elasticsearch.yml
              sed -i 's/^#transport.host:.*/transport.host: 0.0.0.0/' /etc/elasticsearch/elasticsearch.yml

              systemctl daemon-reload
              systemctl enable elasticsearch.service

              systemctl start elasticsearch.service

              sleep 5

              # Reset kibana_system password and capture it
              KIBANA_PASSWORD=$(/usr/share/elasticsearch/bin/elasticsearch-reset-password -u kibana_system -b -s)

              ELASTIC_PASSWORD=$(/usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic -b -s)

              # Check if secret exists, update if it does, create if it doesn't
              if aws secretsmanager describe-secret --secret-id "elasticsearch/kibana_password" --region ${var.region} 2>/dev/null; then
                  # Update existing secret
                  aws secretsmanager update-secret \
                      --secret-id "elasticsearch/kibana_password" \
                      --secret-string "{\"username\":\"kibana_system\",\"password\":\"$KIBANA_PASSWORD\"}" \
                      --region ${var.region}
                  echo "Secret updated"
              else
                  # Create new secret
                  aws secretsmanager create-secret \
                      --name "elasticsearch/kibana_password" \
                      --secret-string "{\"username\":\"kibana_system\",\"password\":\"$KIBANA_PASSWORD\"}" \
                      --region ${var.region}
                  echo "Secret created"
              fi

              # Check if secret exists, update if it does, create if it doesn't
              if aws secretsmanager describe-secret --secret-id "elasticsearch/elastic_password" --region ${var.region} 2>/dev/null; then
                  # Update existing secret
                  aws secretsmanager update-secret \
                      --secret-id "elasticsearch/elastic_password" \
                      --secret-string "{\"username\":\"elastic\",\"password\":\"$ELASTIC_PASSWORD\"}" \
                      --region ${var.region}
                  echo "Secret updated"
              else
                  # Create new secret
                  aws secretsmanager create-secret \
                      --name "elasticsearch/elastic_password" \
                      --secret-string "{\"username\":\"elastic\",\"password\":\"$ELASTIC_PASSWORD\"}" \
                      --region ${var.region}
                  echo "Secret created"
              fi
              
              echo "Password stored in Secrets Manager"

              EOF
}


# IAM Role for Elasticsearch instance
resource "aws_iam_role" "elasticsearch_role" {
  name = "elasticsearch-role"
  
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
resource "aws_iam_policy" "elasticsearch_secrets" {
  name        = "elasticsearch-secrets-policy"
  description = "Allow Elasticsearch to create kibana_password secret"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:UpdateSecret",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "elasticsearch_secrets" {
  role       = aws_iam_role.elasticsearch_role.name
  policy_arn = aws_iam_policy.elasticsearch_secrets.arn
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "elasticsearch_profile" {
  name = "elasticsearch-instance-profile"
  role = aws_iam_role.elasticsearch_role.name
}