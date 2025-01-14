variable "region" {
  description = "AWS region"
  default     = "us-east-1"
  type        = string
}

variable "terraform_admin_user_arn" {
  description = "The ARN of the terraform_admin user"
  type        = string
}
