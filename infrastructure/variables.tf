variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}


variable "key_name" {
  type        = string
  description = "SSH key name"
  default = "iot-project-keys"
}
