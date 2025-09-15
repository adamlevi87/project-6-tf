# modules/gitops/argocd-templates/outputs.tf

output "project_yaml" {
  description = "Rendered Project YAML content"
  value = templatefile("${path.module}/templates/project.yaml.tpl", local.template_vars)
}

output "app_of_apps_yaml" {
  description = "Rendered App-of-Apps YAML content"
  value = templatefile("${path.module}/templates/app_of_apps.yaml.tpl", local.template_vars)
}
