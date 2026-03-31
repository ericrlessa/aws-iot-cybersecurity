# In your variables.tf or appropriate variables file
variable "public_subnet_ids" {
  description = "List of public subnet IDs for the NLB"
  type        = list(string)
  default     = []
}

# Or if using the VPC module directly:
# variable "public_subnet_ids" {
#   value = aws_subnet.public[*].id
# }

variable "vpc_id" {
}


