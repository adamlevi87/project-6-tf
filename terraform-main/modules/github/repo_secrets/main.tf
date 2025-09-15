# terraform-main/modules/repo_secrets/main.tf

terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.6.0"
    }
  }
}

locals {
  env_suffix = upper(var.environment)

  # Remove the SHA suffix from secret values
  cleaned_github_secrets = {
    for k, v in var.github_secrets :
    k => split("--SPLIT--", v)[0]
  }

  cleaned_github_variables = {
    for k, v in var.github_variables :
    k => split("--SPLIT--", v)[0]
  }

  secrets_with_env_suffix = {
    for k, v in local.cleaned_github_secrets :
    "${k}_TF_${local.env_suffix}" => v
  }

  variables_with_env_suffix = {
    for k, v in local.cleaned_github_variables :
    "${k}_TF_${local.env_suffix}" => v
  }
}

resource "github_actions_secret" "secrets" {
  for_each        = local.secrets_with_env_suffix
  repository      = var.repository_name
  secret_name     = each.key
  plaintext_value = each.value
}

resource "github_actions_variable" "variables" {
  for_each        = local.variables_with_env_suffix
  repository      = var.repository_name
  variable_name   = each.key
  value           = each.value
}
