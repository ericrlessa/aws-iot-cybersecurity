# Create an IoT Thing
resource "aws_iot_thing" "temperature_humidity" {
  name = "iot-temperature-humidity-01"
  
  attributes = {
    type         = "sensor"
    model        = "AHT20"
    manufacturer = "Adafruit"
  }
    
}

resource "aws_iot_certificate" "sensor_cert" {
  active = true
}

resource "local_file" "certificate_pem" {
  content  = aws_iot_certificate.sensor_cert.certificate_pem
  filename = "${path.module}/certs/${aws_iot_thing.temperature_humidity.name}_certificate.pem"
  
  depends_on = [aws_iot_certificate.sensor_cert]
}

resource "local_sensitive_file" "private_key" {
  content  = aws_iot_certificate.sensor_cert.private_key
  filename = "${path.module}/certs/${aws_iot_thing.temperature_humidity.name}_private.key"
  
  depends_on = [aws_iot_certificate.sensor_cert]
}

resource "local_file" "public_key" {
  content  = aws_iot_certificate.sensor_cert.public_key
  filename = "${path.module}/certs/${aws_iot_thing.temperature_humidity.name}_public.key"
  
  depends_on = [aws_iot_certificate.sensor_cert]
}

resource "aws_iot_thing_principal_attachment" "attach_cert" {
  thing      = aws_iot_thing.temperature_humidity.name
  principal  = aws_iot_certificate.sensor_cert.arn
}


resource "aws_iot_policy" "send_messages" {
  name = "${aws_iot_thing.temperature_humidity.name}-Policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "iot:Connect"
        Resource = "arn:aws:iot:${var.region}:${data.aws_caller_identity.current.account_id}:client/*"
      },
      {
        Effect = "Allow"
        Action = "iot:Publish"
        Resource = "arn:aws:iot:${var.region}:${data.aws_caller_identity.current.account_id}:topic/devices/${aws_iot_thing.temperature_humidity.name}/data"
      },
      {
        Effect = "Allow"
        Action = "iot:Receive"
        Resource = "arn:aws:iot:${var.region}:${data.aws_caller_identity.current.account_id}:topic/devices/${aws_iot_thing.temperature_humidity.name}/data"
      }
    ]
  })
}

resource "aws_iot_policy_attachment" "attach" {
  policy = aws_iot_policy.send_messages.name
  target = aws_iot_certificate.sensor_cert.arn
}

data "aws_caller_identity" "current" {}