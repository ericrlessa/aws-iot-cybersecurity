variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "private_subnet_id" {
  type        = string
  description = "Private subnet ID for Elasticsearch"
}

variable "key_name" {
  type        = string
  description = "SSH key name"
}

variable "instance_type" {
  type        = string
  default     = "t3.medium"
}

# variable "filebeat_sg_id" {
#   type        = string
#   description = "Security group ID of Filebeat agents"
# }

# variable "kibana_sg_id" {
#   type        = string
#   description = "Security group ID of Kibana instance"
# }

variable "region" {
  type        = string
  default     = "us-east-1"
}