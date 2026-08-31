#===========================================
# VARIABLES
#===========================================

variable "name" {}  
variable "description" {}   
variable "account_access_type" {}                  
variable "authentication_providers" {}
variable "permission_type" {}
variable "data_sources" {}
variable "associate_license" {} 
variable "vpc_private_subnets_cidr_blocks" {}
variable "vpc_private_subnets" {}
variable "grafana_role" {}
variable "project" {}
variable "environment" {}
variable "prometheus_record_name" {}
variable "loki_record_name" {}
variable "auth_username" {}
variable "auth_password" {}
variable "cluster_name" {}

variable "grafana_token" {
  type      = string
  sensitive = true
}
