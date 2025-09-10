# modules/aws_load_balancer_controller/outputs.tf

output "webhook_ready" {
  description = "AWS LBC webhook is actually ready and validated"
  value = {
    service_ready      = data.kubernetes_service.webhook_service.metadata[0].uid
    webhook_config     = data.kubernetes_validating_webhook_configuration_v1.aws_lbc_webhook.metadata[0].uid
    deployment_ready   = null_resource.webhook_deployment_ready.id
  }
  
  # This output will only be available when ALL checks pass
  depends_on = [
    data.kubernetes_service.webhook_service,
    data.kubernetes_validating_webhook_configuration_v1.aws_lbc_webhook,
    null_resource.webhook_deployment_ready
  ]
}

# output "webhook_ready" {
#   description = "Indicates AWS LBC webhook is deployed"
#   value       = helm_release.this.status
#   depends_on  = [helm_release.this]
# }