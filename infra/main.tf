module "eks" {
  source                    = "git::https://github.com/rafaelhueb92/terraform-module-eks-poc.git//?ref=feat/taint-argocd"
  cluster_name              = var.cluster_name
  install_argocd            = true
}

resource "aws_ecr_repository" "hello" {
  name = "hello-app"
}
