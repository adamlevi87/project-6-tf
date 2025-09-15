# terraform-main/modules/external-secrets-operator/variables.tf

variable "project_tag" {
  description = "Project tag used for naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/stage/prod)"
  type        = string
}

variable "argocd_namespace" {
  type        = string
  description = "The Kubernetes namespace of ArgoCD - used for SecretConfig & ExternalSecret crds"
}

variable "argocd_service_account_name" {
  type        = string
  description = "The name of the Kubernetes service account to use for the Helm chart"
}

variable "service_account_name" {
  type        = string
  description = "The name of the Kubernetes service account to use for the Helm chart"
}

variable "namespace" {
  type        = string
  description = "The Kubernetes namespace to install the Helm release into"
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "argocd_github_sso_secret_name" {
  description = "Name of the GitHub SSO secret for ArgoCD"
  type        = string
}

variable "argocd_secret_name" {
  description = "Name of ArgoCD's secret in AWS Secrets Manager"
  type        = string
}

variable "release_name" {
  type        = string
  description = "The Helm release name"
}

variable "chart_version" {
  type        = string
  description = "Version of the ESO Helm chart"
}

variable "set_values" {
  type = list(object({
    name  = string
    value = string
  }))
  default = []
  description = "Extra Helm values to set"
}

