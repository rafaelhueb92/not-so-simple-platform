variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default = "not-so-simple-platform"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "install_argocd" {
  description = "Install ArgoCD in cluster"
  type        = bool
  default     = false
}
