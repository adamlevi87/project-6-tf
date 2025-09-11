# modules/external-secrets-operator/main.tf

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0.2"
    }
  }
}

# locals (keeps the helm_release tidy)
locals {
  eso_extra_objects = [
    # SecretStore in argocd ns, using the argocd SA
    {
      apiVersion = "external-secrets.io/v1beta1"
      kind       = "SecretStore"
      metadata   = {
        name      = "aws-sm-argocd"       # name it however you like
        namespace = "${var.argocd_namespace}"
        annotations = {
          "helm.sh/hook"            = "post-install,post-upgrade"
          "helm.sh/hook-weight"     = "5"
          "helm.sh/hook-delete-policy" = "before-hook-creation"
        }
      }
      spec = {
        provider = {
          aws = {
            service = "SecretsManager"
            region  = "${var.aws_region}"
            #role = "${var.argocd_service_account_role_arn}"
            auth    = {
              jwt = {
                serviceAccountRef = {
                  name      = "${var.argocd_service_account_name}"      # the SA you IRSA-bound
                  #namespace = "${var.argocd_namespace}"
                }
              }
            }
          }
        }
      }
    },

    # 2) ExternalSecret for repository connection with minimal keys in it -> K8s Secret
    # (access to the gitops repo)
    {
      apiVersion = "external-secrets.io/v1beta1"
      kind       = "ExternalSecret"
      metadata   = {
        name      = "argocd-repo-github-gitops-repo"
        namespace = "${var.argocd_namespace}"
        annotations = {
          "helm.sh/hook"            = "post-install,post-upgrade"
          "helm.sh/hook-weight"     = "10"
          "helm.sh/hook-delete-policy" = "before-hook-creation"
        }
      }
      spec = {
        refreshInterval = "1m"
        secretStoreRef  = {
          name = "aws-sm-argocd"
          kind = "SecretStore"
        }
        target = {
          name           = "${var.project_tag}-${var.environment}-argocd-secrets-gitops-repo"   # K8s Secret name
          creationPolicy = "Owner"
          template       = {
            metadata = {
              labels = {
                "argocd.argoproj.io/secret-type" = "repository"
              }
            }
          }
        }
        data = [
          {
            secretKey = "url"
            remoteRef = {
              key      = "${var.argocd_secret_name}"
              property = "REPO_URL_GITOPS"
            } 
          },
          {
            secretKey = "githubAppID"
            remoteRef = {
              key      = "${var.argocd_secret_name}"
              property = "githubAppID"
            } 
          },
          {
            secretKey = "githubAppInstallationID"
            remoteRef = {
              key      = "${var.argocd_secret_name}"
              property = "githubAppInstallationID"
            } 
          },
          {
            secretKey = "githubAppPrivateKey"
            remoteRef = {
              key      = "${var.argocd_secret_name}"
              property = "githubAppPrivateKey"
            } 
          },
          {
            secretKey = "type"
            remoteRef = {
              key      = "${var.argocd_secret_name}"
              property = "type"
            } 
          }
        ]
        # Pass-through: copies ALL JSON properties from the AWS secret
        # dataFrom = [
        #   { 
        #     extract = {
        #       key = "${var.argocd_secret_name}" 
        #     }
        #   }
        # ]
      }
    },
    
    # 3) ExternalSecret for repository connection with minimal keys in it -> K8s Secret
    # (access to the application repo)
    {
      apiVersion = "external-secrets.io/v1beta1"
      kind       = "ExternalSecret"
      metadata   = {
        name      = "argocd-repo-github-app-repo"
        namespace = "${var.argocd_namespace}"
        annotations = {
          "helm.sh/hook"            = "post-install,post-upgrade"
          "helm.sh/hook-weight"     = "10"
          "helm.sh/hook-delete-policy" = "before-hook-creation"
        }
      }
      spec = {
        refreshInterval = "1m"
        secretStoreRef  = {
          name = "aws-sm-argocd"
          kind = "SecretStore"
        }
        target = {
          name           = "${var.project_tag}-${var.environment}-argocd-secrets-app-repo"   # K8s Secret name
          creationPolicy = "Owner"
          template       = {
            metadata = {
              labels = {
                "argocd.argoproj.io/secret-type" = "repository"
              }
            }
          }
        }
        data = [
          {
            secretKey = "url"
            remoteRef = {
              key      = "${var.argocd_secret_name}"
              property = "REPO_URL_APP"
            } 
          },
          {
            secretKey = "githubAppID"
            remoteRef = {
              key      = "${var.argocd_secret_name}"
              property = "githubAppID"
            } 
          },
          {
            secretKey = "githubAppInstallationID"
            remoteRef = {
              key      = "${var.argocd_secret_name}"
              property = "githubAppInstallationID"
            } 
          },
          {
            secretKey = "githubAppPrivateKey"
            remoteRef = {
              key      = "${var.argocd_secret_name}"
              property = "githubAppPrivateKey"
            } 
          },
          {
            secretKey = "type"
            remoteRef = {
              key      = "${var.argocd_secret_name}"
              property = "type"
            } 
          }
        ]
        
        # Pass-through: copies ALL JSON properties from the AWS secret
        # dataFrom = [
        #   { 
        #     extract = {
        #       key = "${var.argocd_secret_name}" 
        #     }
        #   }
        # ]
      }
    },

    # 4) ExternalSecret for argocd SSO -> K8s Secret
    # (integration with Github)
    {
      apiVersion = "external-secrets.io/v1beta1"
      kind       = "ExternalSecret"
      metadata   = {
        name      = "argocd-github-sso"
        namespace = "${var.argocd_namespace}"
        annotations = {
          "helm.sh/hook"            = "post-install,post-upgrade"
          "helm.sh/hook-weight"     = "10"
          "helm.sh/hook-delete-policy" = "before-hook-creation"
        }
      }
      spec = {
        refreshInterval = "1m"
        secretStoreRef  = {
          name = "aws-sm-argocd"
          kind = "SecretStore"
        }
        target = {
          name           = "${var.argocd_github_sso_secret_name}"   # K8s Secret name
          creationPolicy = "Owner"
          template       = {
            metadata = {
              labels = {
                "app.kubernetes.io/part-of" = "argocd"
              }
            }
          }
        }
        data = [
          {
            secretKey = "clientID"
            remoteRef = {
              key      = "${var.argocd_secret_name}"
              property = "argocdOidcClientId"
            } 
          },
          {
            secretKey = "clientSecret"
            remoteRef = {
              key      = "${var.argocd_secret_name}"
              property = "argocdOidcClientSecret"
            } 
          }
        ]
        
        # Pass-through: copies ALL JSON properties from the AWS secret
        # dataFrom = [
        #   { 
        #     extract = {
        #       key = "${var.argocd_secret_name}" 
        #     }
        #   }
        # ]
      }
    },

    # --- RBAC: allow ESO controller SA to create TokenRequest in argocd ns ---
    {
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "Role"
      metadata = {
        name      = "eso-allow-tokenrequest"
        namespace = "${var.argocd_namespace}"
        annotations = {
          "helm.sh/hook"            = "post-install,post-upgrade"
          "helm.sh/hook-weight"     = "3"
          #"helm.sh/hook-delete-policy" = "before-hook-creation"
        }
      }
      rules = [
        {
          apiGroups     = [""]
          resources     = ["serviceaccounts"]
          verbs         = ["get"]
          resourceNames = ["${var.argocd_service_account_name}"]
        },
        {
          apiGroups     = ["authentication.k8s.io"]
          resources     = ["serviceaccounts/token"]
          verbs         = ["create"]
          resourceNames = ["${var.argocd_service_account_name}"] 
        }
      ]        
    },
    {
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "RoleBinding"
      metadata = {
        name      = "eso-allow-tokenrequest"
        namespace = "${var.argocd_namespace}"
        annotations = {
          "helm.sh/hook"            = "post-install,post-upgrade"
          "helm.sh/hook-weight"     = "4"
          #"helm.sh/hook-delete-policy" = "before-hook-creation"
        }
      }
      subjects = [
        {
          kind      = "ServiceAccount"
          name      = var.service_account_name         # ESO controller SA name
          namespace = var.namespace                    # ESO release namespace
        }
      ]
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io"
        kind     = "Role"
        name     = "eso-allow-tokenrequest"
      }
    }
  ]
}


# resource "kubernetes_namespace" "this" {
#   metadata {
#     name = var.namespace
#   }
# }

resource "helm_release" "this" {
  name       = "${var.release_name}"
  
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.chart_version

  namespace  = "${var.namespace}"
  create_namespace = false

  # Wait for all resources to be ready
  wait                = true
  wait_for_jobs      = true
  timeout            = 300  # 5 minutes
  set = concat([
    {
      name  = "installCRDs"
      value = "true"
    },
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = var.service_account_name
    },
    {
      name  = "webhook.port"
      value = "10250"
    }
  ], var.set_values)

  values = [
    yamlencode({
      extraObjects = local.eso_extra_objects
    })
  ]

  # dynamic "set" {
  #   for_each = var.set_values
  #   content {
  #     name  = set.value.name
  #     value = set.value.value
  #   }
  # }

  depends_on = [
    #aws_iam_role_policy_attachment.this,
    kubernetes_service_account.this#,
    #kubernetes_namespace.this
  ]
}

# resource "aws_iam_role" "this" {
#   name = "${var.project_tag}-${var.environment}-eso"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Action = "sts:AssumeRoleWithWebIdentity",
#       Effect = "Allow",
#       Principal = {
#         Federated = var.oidc_provider_arn
#       },
#       Condition = {
#         StringEquals = {
#           "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
#           "${replace(var.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
#         }
#       }
#     }]
#   })

#   tags = {
#     Name        = "${var.project_tag}-${var.environment}-eso-role"
#     Environment = var.environment
#     Project     = var.project_tag
#     Purpose     = "eso-irsa"
#   }
# }

# resource "aws_iam_policy" "this" {
#   name        = "${var.project_tag}-${var.environment}-eso-policy"
#   description = "Allow ESO to access Secrets Manager"

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect   = "Allow",
#         Action   = [
#           "secretsmanager:GetSecretValue",
#           "secretsmanager:DescribeSecret",
#           "secretsmanager:ListSecrets"
#         ],
#         Resource = "*"
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "this" {
#   role       = aws_iam_role.this.name
#   policy_arn = aws_iam_policy.this.arn
# }

resource "kubernetes_service_account" "this" {
  metadata {
    name      = var.service_account_name
    namespace = var.namespace
    # annotations = {
    #   "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
    #   "meta.helm.sh/release-name"  = var.release_name                # e.g. "external-secrets-dev"
    #   "meta.helm.sh/release-namespace" = var.namespace
    # }
    # labels = {
    #   "app.kubernetes.io/managed-by" = "Helm"
    # }
  }
}
