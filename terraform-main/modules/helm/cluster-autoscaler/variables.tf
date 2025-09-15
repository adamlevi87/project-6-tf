# terraform-main/modules/cluster-autoscaler/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "release_name" {
  type        = string
  description = "The Helm release name"
}

variable "chart_version" {
  description = "Version of the AWS Load Balancer Controller Helm chart to deploy"
  type        = string
}

variable "namespace" {
  type        = string
  description = "The Kubernetes namespace to install the Helm release into"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
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

variable "autoscaling_group_arns" {
  description = "List of Auto Scaling Group ARNs to grant permissions to"
  type        = list(string)
}
