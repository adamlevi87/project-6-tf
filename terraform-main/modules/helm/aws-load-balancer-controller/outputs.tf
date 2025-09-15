# terraform-main/modules/aws_load_balancer_controller/outputs.tf

output "webhook_ready" {
  description = "AWS LBC webhook is actually ready and validated"
  value = {
    service_ready      = data.kubernetes_service.webhook_service.metadata[0].uid
    deployment_ready   = null_resource.webhook_deployment_ready.id
  }
  
  depends_on = [
    data.kubernetes_service.webhook_service,
    null_resource.webhook_deployment_ready
  ]
}
