locals {
  
  region      = "us-east-1"
  name        = "amg-ex-${replace(basename(path.cwd), "_", "-")}"
  description = "AWS Managed Grafana service for ${local.name}"
  oidc_issuer = replace(data.aws_eks_cluster.dlframe.identity[0].oidc[0].issuer, "https://", "")

}
