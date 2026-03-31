# variables.tf
variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "subnet_id" {
  type        = string
  description = "subnet ID for Kibana instance"
}

variable "instance_name" {
  description = "Unique name for this Mosquitto instance"
  type        = string
}

variable "key_name" {
  type        = string
  description = "SSH key name"
}

variable "instance_type" {
  type        = string
  default     = "t3.medium"
}

variable "admin_cidr" {
  type        = string
  description = "CIDR to allow browser/SSH access (your IP)"
  default     = "0.0.0.0/0"
}

variable "region" {
  type        = string
  default     = "us-east-1"
}


variable "elasticsearch_ip" {
  type        = string
  description = "Private IP of Elasticsearch instance"
}

variable "kibana_ip" {
  type        = string
  description = "Private IP of Kibana instance"
}

variable "target_group" {
  type        = string
  description = "Load balance target group"
}


