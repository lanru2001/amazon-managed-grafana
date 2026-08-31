provider "aws" {
  region = "${local.region}"

  default_tags {
    tags = {
      Terraform   = "true"
      Project     = "Amazon Managed Grafana"
    }
  }
}

# provider "grafana" {
#   alias = "amg"   #"cloud"
#   url  = "https://${module.managed_grafana.workspace_endpoint}"
#   auth = module.managed_grafana.workspace_service_account_tokens["terraform"].key #module.managed_grafana.workspace_service_account_tokens.terraform.key
# }

provider "grafana" {
  alias = "cloud"
  url  = "https://${module.managed_grafana.workspace_endpoint}"
  auth = var.grafana_token
  #auth = module.managed_grafana.workspace_service_account_tokens.terraform.key #module.managed_grafana.workspace_service_account_tokens["terraform"].key
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    grafana = {
      source = "grafana/grafana"
      version = "3.25.7"
    }

    helm = {
      source = "hashicorp/helm"
      version = ">=2.11.0"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
      version = ">= 2.23.0"
    }

    kubectl = {
      source = "gavinbunney/kubectl"
      version = "1.14.0"
    }

    time = {
      source = "hashicorp/time"
      version = "0.13.1"
    }
 
    null = {
      source = "hashicorp/null"
      version = "3.2.4"
    }

  }
}


######################################################################################
#K8S and Helm Provider
######################################################################################

provider "kubernetes" {
  host                   = data.aws_eks_cluster.dlframe.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.dlframe.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = [ "eks", "get-token", "--cluster-name", "${var.cluster_name}", "--region", "${local.region}" ]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.dlframe.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.dlframe.certificate_authority[0].data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = [ "eks", "get-token", "--cluster-name", "${var.cluster_name}", "--region", "${local.region}" ]
      command     = "aws"
    }
  }
}

provider "kubectl" {
    host                   = data.aws_eks_cluster.dlframe.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.dlframe.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = [ "eks", "get-token", "--cluster-name", "${var.cluster_name}", "--region", "${local.region}" ]
      command     = "aws"
    }
}
