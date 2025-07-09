data "aws_lb" "prometheus" {
  tags = {
    Target = "dlframe-prometheus"
  }
}

data "aws_lb" "tempo" {
  tags = {
    Target = "dlframe-tempo"
  }
}

data "aws_lb" "loki" {
  tags = {
    Target = "dlframe-loki"
  }
}

module "managed_grafana" {
  source = "terraform-aws-modules/managed-service-grafana/aws"

  # Workspace
  name                     = "dlframe"
  description              = "AWS Managed Grafana service workspace for dlframe client"
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "SERVICE_MANAGED"
  data_sources             = []
  associate_license        = false

  # vpc configuration
  vpc_configuration = {
    subnet_ids = var.vpc_private_subnets
  }

  security_group_rules = {
    egress_prometheus = {
      description = "Allow Prometheus traffic"
      from_port   = 9090
      to_port     = 9090
      protocol    = "tcp"
      cidr_blocks = var.vpc_private_subnets_cidr_blocks
    }
    egress_http = {
      description = "Allow all http traffic to k8s."
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = var.vpc_private_subnets_cidr_blocks
    }
  }

  #   Workspace service accounts
  workspace_service_accounts = {
    terraform = {
      grafana_role = "ADMIN"
    }
  }
  # TODO: Important! This token will be expired after 24 hours and you should renew it manually or recreate it via terraform
  workspace_service_account_tokens = {
    terraform = {
      service_account_key = "terraform"
      seconds_to_live     = 2592000 # 30 days. Keys can be valid for up to 30 days.
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
    Project     = "staging"
  }
}

#### Grafana settings
resource "grafana_data_source" "prometheus" {
  provider = grafana.cloud

  name               = "prometheus"
  type               = "prometheus"
  url                = "http://${data.aws_lb.prometheus.dns_name}"
  basic_auth_enabled = false
  is_default         = true
}

resource "grafana_data_source" "loki" {
  provider = grafana.cloud

  name               = "loki"
  type               = "loki"
  url                = "http://${data.aws_lb.loki.dns_name}"
    basic_auth_enabled = false
  is_default         = false
}

## Dashboards
resource "grafana_folder" "kube_prometheus_stack" {
  provider = grafana.cloud

  title = "kube-prometheus-stack"
}

resource "grafana_dashboard" "kube_prometheus_stack" {
  provider = grafana.cloud

  for_each    = fileset("${path.module}/files/grafana/dashboards/kube-prometheus-stack", "*.json")
  config_json = file("${path.module}/files/grafana/dashboards/kube-prometheus-stack/${each.key}")
  folder      = grafana_folder.kube_prometheus_stack.id
}

resource "grafana_folder" "dlframe" {
  provider = grafana.cloud

  title = "lasso"
}

resource "grafana_dashboard" "dlframe" {
  provider = grafana.cloud

  for_each    = fileset("${path.module}/files/grafana/dashboards/lasso", "*.json")
  config_json = file("${path.module}/files/grafana/dashboards/lasso/${each.key}")
  folder      = grafana_folder.lasso.id
}
