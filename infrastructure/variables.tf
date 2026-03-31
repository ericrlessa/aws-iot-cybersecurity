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

variable "bucket_vpc_flow_logs_arn" {
  type        = string    
}

variable "bucket_vpc_flow_logs_name" {
  type        = string    
}

