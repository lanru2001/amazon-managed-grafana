data "aws_caller_identity" "current" {}

# Amazon Managed Prometheus IAM role
resource "aws_iam_role" "prometheus" {
  name        = "dlframe-${var.environment}-prometheus-role"
  description = "IAM Role for Prometheus supports ingesting metrics from k8s Prometheus servers"

  force_detach_policies = true

  tags = {
    EstimatedUsage = 180
  }

  assume_role_policy = <<ROLE
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_issuer}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${local.oidc_issuer}:sub": "system:serviceaccount:monitoring:amp-iamproxy-ingest-service-account",
          "${local.oidc_issuer}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
ROLE
}

# Amazon Managed Prometheus IAM Policy
resource "aws_iam_policy"  "prometheus_policy" {
  name        = "dlframe-${var.environment}-prometheus-policy"
  description = "Policy for Prometheus supports ingesting metrics from k8s Prometheus servers"
 
 policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "aps:RemoteWrite", 
                "aps:GetSeries", 
                "aps:GetLabels",
                "aps:GetMetricMetadata",
                "aps:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

# Amazon Managed Prometheus Policy Attachment
resource "aws_iam_role_policy_attachment" "prometheusPolicyAttachment" {
  policy_arn = aws_iam_policy.prometheus_policy.arn
  role       = aws_iam_role.prometheus.name
}

# Amazon Managed Prometheus Service Account
# resource "kubernetes_service_account" "prometheus" {
#   metadata {
#     name = "amp-iamproxy-ingest-service-account"
#     namespace = "monitoring"
#     annotations = {
#     "eks.amazonaws.com/role-arn" = "${aws_iam_role.prometheus.arn}"
#     }
#   }
# }
