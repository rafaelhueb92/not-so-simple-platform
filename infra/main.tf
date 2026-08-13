module "eks" {
  source             = "git::https://github.com/rafaelhueb92/terraform-module-eks-poc.git//?ref=feat/taint-argocd"
  cluster_name       = var.cluster_name
  install_argocd     = true
  install_monitoring = true
  additional_admin_arns = [
    "arn:aws:iam::${local.account_id}:user/admin"
  ]

  argocd_application_manifests = [
  {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "hello-app"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/rafaelhueb92/not-so-simple-platform.git"
        targetRevision = "HEAD"
        path           = "app/manifest"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "default"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
      syncOptions = [
        "CreateNamespace=true"
      ]
    }
  }
]

  kubernetes_version = "1.35"

}

resource "aws_ecr_repository" "hello" {
  name = "hello-app"
}
