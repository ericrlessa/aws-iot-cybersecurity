# variables.tf
variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "public_subnet_id" {
  type        = string
  description = "Public subnet ID for Kibana instance"
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

variable "elasticsearch_ip" {
  type        = string
  description = "Private IP of Elasticsearch instance"
}

variable "region" {
  type        = string
  default     = "us-east-1"
}