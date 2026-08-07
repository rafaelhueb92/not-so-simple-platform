#module "eks" {
#  source             = "git::https://github.com/rafaelhueb92/terraform-module-eks-poc.git//?ref=feat/taint-argocd"
#  cluster_name       = var.cluster_name
#  install_argocd     = true
#  install_monitoring = true
#  additional_admin_arns = [
#    "arn:aws:iam::${local.account_id}:user/admin"
#  ]
#
#  kubernetes_version = "1.35"
#
#}

resource "aws_ecr_repository" "hello" {
  name = "hello-app"
}
