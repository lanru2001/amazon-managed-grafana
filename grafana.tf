# Production-Grade Amazon Managed Service for Grafana

module "managed_grafana" {
  source  = "terraform-aws-modules/managed-service-grafana/aws"
  version = "v2.3.0"

  # Workspace
  name                     = var.name
  description              = var.description
  account_access_type      = var.account_access_type
  authentication_providers = var.authentication_providers 
  permission_type          = var.permission_type 
  #data_sources             = var.data_sources
  associate_license        = var.associate_license 
  grafana_version          = "10.4"

  # vpc configuration
  vpc_configuration = {
    subnet_ids = var.vpc_private_subnets
  }

  # Workspace configuration options
  configuration = jsonencode({
    unifiedAlerting = {
      enabled = true
    },
    plugins = {
      pluginAdminEnabled = true
    }
  })

  # Workspace API keys
  workspace_api_keys = {
    viewer = {
      key_name        = "viewer"
      key_role        = "VIEWER"
      seconds_to_live = 2592000
    }
    editor = {
      key_name        = "editor"
      key_role        = "EDITOR"
      seconds_to_live = 2592000
    }
    admin = {
      key_name        = "admin"
      key_role        = "ADMIN"
      seconds_to_live = 2592000
    }
  }

  security_group_rules = {
    egress_grafana = {
      description = "Allow All traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }


  # Workspace service accounts
  workspace_service_accounts = {
    terraform = {
      grafana_role = var.grafana_role
    }
  }
  
  workspace_service_account_tokens = {
    terraform = {
      service_account_key = "terraform"
      seconds_to_live     = 2592000
    }
  }


  # Workspace IAM role
  create_iam_role                = true
  iam_role_name                  = local.name
  use_iam_role_name_prefix       = true
  iam_role_description           = local.description
  iam_role_path                  = "/grafana/"
  iam_role_force_detach_policies = true
  iam_role_max_session_duration  = 7200
  iam_role_tags                  = { role = true }

  tags = {
    Repository = "Dlframe"
    DeployedBy = "sreteam@glidewelldental.com"
    Project    = "dlframe"
    ProjectComponent = "infrastructure"
    TeamOwner  = "sreteam@glidewelldental.com"
    CostCenter = "60150"
    CostCenterDescription = "Infra/Systems"
  }
}

resource "aws_security_group_rule" "prometheus" {
  cidr_blocks              = ["192.168.128.0/17"]
  description              = "Allow all prometheus traffic to k8s"
  from_port                = 9090
  protocol                 = "tcp"
  security_group_id        = module.managed_grafana.security_group_id 
  to_port                  = 9090
  type                     = "ingress"
}

resource "aws_security_group_rule" "loki" {
  cidr_blocks              = ["192.168.128.0/17"]
  description              = "Allow all loki traffic to k8s"
  from_port                = 3100
  protocol                 = "tcp"
  security_group_id        = module.managed_grafana.security_group_id 
  to_port                  = 3100
  type                     = "ingress"
}

resource "aws_security_group_rule" "http" {
  cidr_blocks              = ["192.168.128.0/17"]
  description              = "Allow http traffic to k8s"
  from_port                = 80
  protocol                 = "tcp"
  security_group_id        = module.managed_grafana.security_group_id 
  to_port                  = 80
  type                     = "ingress"
}

resource "aws_security_group_rule" "https" {
  cidr_blocks              = ["192.168.128.0/17"]
  description              = "Allow http traffic to k8s"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = module.managed_grafana.security_group_id 
  to_port                  = 443
  type                     = "ingress"
}

#### Grafana settings

##  Self-hosted Prometheus datasource
resource "grafana_data_source" "prometheus" {
  provider            = grafana.cloud
  name                = "prometheus"
  type                = "prometheus"
  url                 = "https://${var.prometheus_record_name}"
  basic_auth_enabled  = true
  is_default          = false
  basic_auth_username = var.auth_username

  secure_json_data_encoded = jsonencode({
    basicAuthPassword = var.auth_password
  })

  depends_on = [
    module.managed_grafana.workspace_endpoint,
    module.managed_grafana.workspace_service_account_tokens
  ]

}

## Ensure the Grafana workspace IAM role has permissions to query AMP
# resource "aws_iam_role_policy_attachment" "amg_amp_access" {
#   role       =  module.managed_grafana.workspace_iam_role_name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonPrometheusFullAccess"

#   depends_on = [module.managed_grafana.workspace_iam_role_name]
# }

##  Amazon Managed Service for Prometheus datasource
# resource "grafana_data_source" "amp" {
#   provider    = grafana.amg
#   name        = "prometheus"
#   type        = "prometheus"
#   url         = aws_prometheus_workspace.dlframe.prometheus_endpoint
#   is_default  = false

#   json_data_encoded = jsonencode({
#     httpMethod     = "POST"
#     sigV4Auth      = true
#     sigV4AuthType  = "default" 
#     sigV4Region    = "us-east-1"
#   })
# }


resource "grafana_data_source" "loki" {
  provider = grafana.cloud
  name               = "loki"
  type               = "loki"
  url                = "http://${var.loki_record_name}"
  basic_auth_enabled = false
  is_default         = false

  depends_on = [
    module.managed_grafana.workspace_endpoint,
    module.managed_grafana.workspace_service_account_tokens
  ]

}

resource "grafana_folder" "dlframe" {
  provider = grafana.cloud
  title = "dlframe"
  
  depends_on = [
    module.managed_grafana.workspace_endpoint,
    module.managed_grafana.workspace_service_account_tokens
  ]
}

resource "grafana_dashboard" "cluster_status" {
  provider    = grafana.cloud
  config_json = file("${path.module}/files/grafana/dashboards/dlframe/cluster_status.json")
  folder      = grafana_folder.dlframe.id

  depends_on = [
    grafana_folder.dlframe,
    module.managed_grafana.workspace_endpoint,
    module.managed_grafana.workspace_service_account_tokens
  ]
}

resource "grafana_dashboard" "k8s_node" {
  provider    = grafana.cloud
  config_json = file("${path.module}/files/grafana/dashboards/dlframe/k8s_node.json")
  folder      = grafana_folder.dlframe.id

  depends_on = [
    grafana_folder.dlframe,
    module.managed_grafana.workspace_endpoint,
    module.managed_grafana.workspace_service_account_tokens
  ]
}

resource "grafana_dashboard" "k8s_pod" {
  provider    = grafana.cloud
  config_json = file("${path.module}/files/grafana/dashboards/dlframe/k8s_pod.json")
  folder      = grafana_folder.dlframe.id

  depends_on = [
    grafana_folder.dlframe,
    module.managed_grafana.workspace_endpoint,
    module.managed_grafana.workspace_service_account_tokens
  ]
}

resource "grafana_dashboard" "loki" {
  provider    = grafana.cloud
  config_json = file("${path.module}/files/grafana/dashboards/dlframe/loki.json")
  folder      = grafana_folder.dlframe.id

  depends_on = [
    grafana_folder.dlframe,
    module.managed_grafana.workspace_endpoint,
    module.managed_grafana.workspace_service_account_tokens
  ]
}

resource "grafana_dashboard" "node_exporter_full" {
  provider    = grafana.cloud
  config_json = file("${path.module}/files/grafana/dashboards/dlframe/node_exporter_full.json")
  folder      = grafana_folder.dlframe.id

  depends_on = [
    grafana_folder.dlframe,
    module.managed_grafana.workspace_endpoint,
    module.managed_grafana.workspace_service_account_tokens
  ]
}

resource "grafana_dashboard" "pv" {
  provider    = grafana.cloud
  config_json = file("${path.module}/files/grafana/dashboards/dlframe/pv.json")
  folder      = grafana_folder.dlframe.id

  depends_on = [
    grafana_folder.dlframe,
    module.managed_grafana.workspace_endpoint,
    module.managed_grafana.workspace_service_account_tokens
  ]
}

resource "grafana_dashboard" "pvc" {
  provider    = grafana.cloud
  config_json = file("${path.module}/files/grafana/dashboards/dlframe/pvc.json")
  folder      = grafana_folder.dlframe.id

  depends_on = [
    grafana_folder.dlframe,
    module.managed_grafana.workspace_endpoint,
    module.managed_grafana.workspace_service_account_tokens
  ]
}

resource "grafana_dashboard" "kube-event-exporter" {
  provider    = grafana.cloud
  config_json = file("${path.module}/files/grafana/dashboards/dlframe/kube-event-exporter.json")
  folder      = grafana_folder.dlframe.id

  depends_on = [
    grafana_folder.dlframe,
    module.managed_grafana.workspace_endpoint,
    module.managed_grafana.workspace_service_account_tokens
  ]
}

resource "grafana_dashboard" "service" {
  provider    = grafana.cloud
  config_json = file("${path.module}/files/grafana/dashboards/dlframe/service.json")
  folder      = grafana_folder.dlframe.id

  depends_on = [
    grafana_folder.dlframe,
    module.managed_grafana.workspace_endpoint,
    module.managed_grafana.workspace_service_account_tokens
  ]
}

resource "grafana_dashboard" "pod_running" {
  provider    = grafana.cloud
  config_json = file("${path.module}/files/grafana/dashboards/dlframe/pods_running.json")
  folder      = grafana_folder.dlframe.id

  depends_on = [
    grafana_folder.dlframe,
    module.managed_grafana.workspace_endpoint,
    module.managed_grafana.workspace_service_account_tokens
  ]
}

resource "grafana_dashboard" "model" {
  provider    = grafana.cloud
  config_json = file("${path.module}/files/grafana/dashboards/dlframe/model.json")
  folder      = grafana_folder.dlframe.id

  depends_on = [
    grafana_folder.dlframe,
    module.managed_grafana.workspace_endpoint,
    module.managed_grafana.workspace_service_account_tokens
  ]
}

resource "grafana_dashboard" "istio" {
  provider    = grafana.cloud
  config_json = file("${path.module}/files/grafana/dashboards/dlframe/istio.json")
  folder      = grafana_folder.dlframe.id

  depends_on = [
    grafana_folder.dlframe,
    module.managed_grafana.workspace_endpoint,
    module.managed_grafana.workspace_service_account_tokens
  ]
}
