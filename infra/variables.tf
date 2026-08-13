variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "not-so-simple-platform"
}

variable "region" {
  description = "AWS region to deploy the EKS cluster"
  type        = string
  default     = "us-east-1"
}