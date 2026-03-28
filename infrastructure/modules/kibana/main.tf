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
  iam_instance_profile = aws_iam_instance_profile.kibana_profile.name

  tags = { Name = "kibana-server" }


  user_data = <<-EOF
              #!/bin/bash
              set -eux

              apt-get update -y

              apt-get install -y awscli jq

              wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
              apt-get install apt-transport-https
              echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/9.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-9.x.list
              apt-get update -y && apt-get install kibana -y

              sed -i 's/^#server.host:.*/server.host: 0.0.0.0/' /etc/kibana/kibana.yml

              # Get password from Secrets Manager
              KIBANA_PASSWORD=$(aws secretsmanager get-secret-value \
                --secret-id "elasticsearch/kibana_password" \
                --query 'SecretString' \
                --region ${var.region} \
                --output text | jq -r '.password')

              # Uncomment and set elasticsearch.hosts
              sed -i 's|^#elasticsearch.hosts:.*|elasticsearch.hosts: ["https://'"${var.elasticsearch_ip}"':9200"]|' /etc/kibana/kibana.yml

              # Add credentials if they don't exist (or uncomment existing)
              grep -q "^elasticsearch.username:" /etc/kibana/kibana.yml || echo "elasticsearch.username: \"kibana_system\"" >> /etc/kibana/kibana.yml
              grep -q "^elasticsearch.password:" /etc/kibana/kibana.yml || echo "elasticsearch.password: \"$KIBANA_PASSWORD\"" >> /etc/kibana/kibana.yml
              grep -q "^elasticsearch.ssl.verificationMode:" /etc/kibana/kibana.yml || echo "elasticsearch.ssl.verificationMode: \"none\"" >> /etc/kibana/kibana.yml

              systemctl daemon-reload
              systemctl enable kibana.service

              systemctl start kibana.service

              EOF

}


resource "aws_iam_role" "kibana_role" {
  name = "kibana-role"
  
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
resource "aws_iam_policy" "kibana_secrets" {
  name        = "kibana-secrets-policy"
  description = "Allow Kibana to get kibana_password secret"
  
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
resource "aws_iam_role_policy_attachment" "kibana_secrets" {
  role       = aws_iam_role.kibana_role.name
  policy_arn = aws_iam_policy.kibana_secrets.arn
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "kibana_profile" {
  name = "kibana-instance-profile"
  role = aws_iam_role.kibana_role.name
}

