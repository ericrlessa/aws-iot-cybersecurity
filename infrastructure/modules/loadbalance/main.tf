###############################
# NETWORK LOAD BALANCER
###############################

# Target Group for MQTT traffic
resource "aws_lb_target_group" "mqtt" {
  name     = "mqtt-target-group"
  port     = 1883
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    interval            = 30
    port                = 1883
    protocol            = "TCP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  deregistration_delay = 300

  tags = {
    Name = "mqtt-nlb-tg"
  }
}

# Network Load Balancer
resource "aws_lb" "mqtt_nlb" {
  name               = "mqtt-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name        = "mqtt-network-lb"
    Environment = "lab"
  }
}

# Listener for MQTT traffic
resource "aws_lb_listener" "mqtt" {
  load_balancer_arn = aws_lb.mqtt_nlb.arn
  port              = 1883
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mqtt.arn
  }
}



