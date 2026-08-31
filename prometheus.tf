# Comment out Amazon Managed Prometheus due to high cost --- about $2,800 monthly 

/*

#######################################################################################################
## 1. Workspace 
## Manages an Amazon Managed Service for Prometheus (AMP) Workspace
#######################################################################################################
resource "aws_prometheus_workspace" "dlframe" {
  alias       = "dlframe"

  tags = {
    Environment = var.environment
  }
}

#######################################################################################################
## 2. Workspace Configuration
## Manages an Amazon Managed Service for Prometheus (AMP) Workspace
#######################################################################################################
resource "aws_prometheus_workspace_configuration" "dlframe" {
  workspace_id             = aws_prometheus_workspace.dlframe.id
  retention_period_in_days = 60

  limits_per_label_set {
    label_set = {
      "env" = var.environment
    }
    limits {
      max_series =  400000
    }
  }
}

#######################################################################################################
## 3. Prometheus Scraper
## Provides an Amazon Managed Service for Prometheus fully managed collector (scraper).
#######################################################################################################
resource "aws_prometheus_scraper" "dlframe" {
  source {
    eks {
      cluster_arn = data.aws_eks_cluster.dlframe.arn
      subnet_ids  = data.aws_eks_cluster.dlframe.vpc_config[0].subnet_ids
    }
  }

  destination {
    amp {
      workspace_arn = aws_prometheus_workspace.dlframe.arn
    }
  }

  scrape_configuration = <<EOT
global:
  scrape_interval: 30s
scrape_configs:
      - job_name: 'dcgm-exporter'
        scrape_interval: 30s
        static_configs:
          - targets: ['dcgm-exporter.monitoring.svc.cluster.local:9400']    

      # well as HA API server deployments.
      - job_name: 'kubernetes-apiservers'
        kubernetes_sd_configs:
          - role: endpoints
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          insecure_skip_verify: true
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
          - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
            action: keep
            regex: default;kubernetes;https  

      - job_name: 'kubernetes-nodes'
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          insecure_skip_verify: true
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token

        kubernetes_sd_configs:
          - role: node

        relabel_configs:
          - action: labelmap
            regex: __meta_kubernetes_node_label_(.+)
          - target_label: __address__
            replacement: kubernetes.default.svc:443
          - source_labels: [__meta_kubernetes_node_name]
            regex: (.+)
            target_label: __metrics_path__
            replacement: /api/v1/nodes/$1/proxy/metrics

      - job_name: 'kubernetes-nodes-cadvisor'

        # Default to scraping over https. If required, just disable this or change to
        # `http`.
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          insecure_skip_verify: true
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token

        kubernetes_sd_configs:
          - role: node
        relabel_configs:
          - action: labelmap
            regex: __meta_kubernetes_node_label_(.+)
          - target_label: __address__
            replacement: kubernetes.default.svc:443
          - source_labels: [__meta_kubernetes_node_name]
            regex: (.+)
            target_label: __metrics_path__
            replacement: /api/v1/nodes/$1/proxy/metrics/cadvisor
      - job_name: 'kubernetes-service-endpoints'
        honor_labels: true

        kubernetes_sd_configs:
          - role: endpoints

        relabel_configs:
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape_slow]
            action: drop
            regex: true
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
            action: replace
            target_label: __scheme__
            regex: (https?)
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
            action: replace
            target_label: __address__
            regex: (.+?)(?::\d+)?;(\d+)
            replacement: $1:$2
          - action: labelmap
            regex: __meta_kubernetes_service_annotation_prometheus_io_param_(.+)
            replacement: __param_$1
          - action: labelmap
            regex: __meta_kubernetes_service_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: namespace
          - source_labels: [__meta_kubernetes_service_name]
            action: replace
            target_label: service
          - source_labels: [__meta_kubernetes_pod_node_name]
            action: replace
            target_label: node

      - job_name: 'kubernetes-service-endpoints-slow'
        honor_labels: true
        scrape_interval: 5m
        scrape_timeout: 30s
        kubernetes_sd_configs:
          - role: endpoints

        relabel_configs:
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape_slow]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
            action: replace
            target_label: __scheme__
            regex: (https?)
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
            action: replace
            target_label: __address__
            regex: (.+?)(?::\d+)?;(\d+)
            replacement: $1:$2
          - action: labelmap
            regex: __meta_kubernetes_service_annotation_prometheus_io_param_(.+)
            replacement: __param_$1
          - action: labelmap
            regex: __meta_kubernetes_service_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: namespace
          - source_labels: [__meta_kubernetes_service_name]
            action: replace
            target_label: service
          - source_labels: [__meta_kubernetes_pod_node_name]
            action: replace
            target_label: node

      - job_name: 'prometheus-pushgateway'
        honor_labels: true
        kubernetes_sd_configs:
          - role: service
        relabel_configs:
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_probe]
            action: keep
            regex: pushgateway 
      - job_name: 'kubernetes-services'
        honor_labels: true

        metrics_path: /probe
        params:
          module: [http_2xx]

        kubernetes_sd_configs:
          - role: service
        relabel_configs:
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_probe]
            action: keep
            regex: true
          - source_labels: [__address__]
            target_label: __param_target
          - target_label: __address__
            replacement: blackbox
          - source_labels: [__param_target]
            target_label: instance
          - action: labelmap
            regex: __meta_kubernetes_service_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            target_label: namespace
          - source_labels: [__meta_kubernetes_service_name]
            target_label: service 
      - job_name: 'kubernetes-pods'
        honor_labels: true

        kubernetes_sd_configs:
          - role: pod

        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape_slow]
            action: drop
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scheme]
            action: replace
            regex: (https?)
            target_label: __scheme__
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port, __meta_kubernetes_pod_ip]
            action: replace
            regex: (\d+);(([A-Fa-f0-9]{1,4}::?){1,7}[A-Fa-f0-9]{1,4})
            replacement: '[$2]:$1'
            target_label: __address__
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port, __meta_kubernetes_pod_ip]
            action: replace
            regex: (\d+);((([0-9]+?)(\.|$)){4})
            replacement: $2:$1
            target_label: __address__
          - action: labelmap
            regex: __meta_kubernetes_pod_annotation_prometheus_io_param_(.+)
            replacement: __param_$1
          - action: labelmap
            regex: __meta_kubernetes_pod_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: namespace
          - source_labels: [__meta_kubernetes_pod_name]
            action: replace
            target_label: pod
          - source_labels: [__meta_kubernetes_pod_phase]
            regex: Pending|Succeeded|Failed|Completed
            action: drop
          - source_labels: [__meta_kubernetes_pod_node_name]
            action: replace
            target_label: node
      - job_name: 'kubernetes-pods-slow'
        honor_labels: true

        scrape_interval: 30s
        scrape_timeout: 30s

        kubernetes_sd_configs:
          - role: pod

        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape_slow]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scheme]
            action: replace
            regex: (https?)
            target_label: __scheme__
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port, __meta_kubernetes_pod_ip]
            action: replace
            regex: (\d+);(([A-Fa-f0-9]{1,4}::?){1,7}[A-Fa-f0-9]{1,4})
            replacement: '[$2]:$1'
            target_label: __address__
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port, __meta_kubernetes_pod_ip]
            action: replace
            regex: (\d+);((([0-9]+?)(\.|$)){4})
            replacement: $2:$1
            target_label: __address__
          - action: labelmap
            regex: __meta_kubernetes_pod_annotation_prometheus_io_param_(.+)
            replacement: __param_$1
          - action: labelmap
            regex: __meta_kubernetes_pod_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: namespace
          - source_labels: [__meta_kubernetes_pod_name]
            action: replace
            target_label: pod
          - source_labels: [__meta_kubernetes_pod_phase]
            regex: Pending|Succeeded|Failed|Completed
            action: drop
          - source_labels: [__meta_kubernetes_pod_node_name]
            action: replace
            target_label: node  
EOT
}
#######################################################################################################
## 4. Prometheus Alert Manager Definition 
## Manages an Amazon Managed Service for Prometheus (AMP) Alert Manager Definition
#######################################################################################################
resource "aws_prometheus_alert_manager_definition" "dlframe" {
  workspace_id = aws_prometheus_workspace.dlframe.id
  definition   = <<EOF
alertmanager_config: |
  global: {}
    # slack_api_url: ''

  templates:
    - '/etc/alertmanager/*.tmpl'

  receivers:
    # - name: dlframe-alertmanager-notification
    #   webhook_configs:
    #   - url: 'http://prometheus-msteams:2000/alertmanager'
    #     send_resolved: true

    - name: 'DLFrame Application Alerts'
      pagerduty_configs:
      - service_key: '1ec89e66f9b84c0ec0922cce3885eda3'
  
  route:
    group_wait: 10s
    group_interval: 5m
    repeat_interval: 3h
    receiver: dlframe-alertmanager-notification
    routes:
    - match:
       team: dlframe-alertmanager-notification
       severity: "warning|critical"
      receiver: dlframe-alertmanager-notification 
      continue: true  
    - match:
       team: "DLFrame Application Alerts"
       severity: "warning"
      receiver: "DLFrame Application Alerts"   

EOF
}

*/
