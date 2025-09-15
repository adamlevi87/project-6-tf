# terraform-main/modules/external-dns/variables.tf

variable "project_tag" {
  description = "Project tag used for naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/stage/prod)"
  type        = string
}

variable "release_name" {
  type        = string
  description = "The Helm release name"
}

variable "chart_version" {
  description = "Helm chart version for ExternalDNS"
  type        = string
}

variable "namespace" {
  type        = string
  description = "The Kubernetes namespace to install the Helm release into"
}

variable "txt_owner_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

variable "domain_filter" {
  description = "Domain to manage DNS for (e.g. example.com)"
  type        = string
}

variable "zone_type" {
  description = "public or private"
  type        = string
  default     = "public"
}

variable "service_account_name" {
  type        = string
  description = "The name of the Kubernetes service account to use for the Helm chart"
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN from the EKS module"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC provider URL from the EKS cluster"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID to grant permissions to"
  type        = string
}
