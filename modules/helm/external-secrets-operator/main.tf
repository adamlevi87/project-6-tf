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

# locals (keeps the helm_release as tidy as possible)
locals {
  eso_extra_objects = [
    # --- RBAC: we create a role with permissions (role must exist where the permissions are needed)
    # role is bound to the ESO service account in the ESO namespace
    # this allows the ESO controller to operate the Secret store/ externalstore in the argocd ns
    # basically get/ and use argoCD service account to generate tokens
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
    },




    # create a SecretStore in argocd namespace, using the argocd SA (SecretStore is a template\config for ExternalSecret)
    {
      apiVersion = "external-secrets.io/v1beta1"
      kind       = "SecretStore"
      metadata   = {
        name      = "aws-sm-argocd"
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
            auth    = {
              jwt = {
                serviceAccountRef = {
                  name      = "${var.argocd_service_account_name}"      # the SA you IRSA-bound
                }
              }
            }
          }
        }
      }
    },

    # ExternalSecret for repository connection with minimal keys in it -> K8s Secret
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
        # using the secret store we created before
        secretStoreRef  = {
          name = "aws-sm-argocd"
          kind = "SecretStore"
        }
        target = {
          # K8s Secret name
          name           = "${var.project_tag}-${var.environment}-argocd-secrets-gitops-repo"
          creationPolicy = "Owner"
          template       = {
            metadata = {
              labels = {
                # label so argoCD will use this automatically
                "argocd.argoproj.io/secret-type" = "repository"
              }
            }
          }
        }
        data = [
          # Github authentication requires:
          # type,url,githubAppID,githubAppInstallationID,githubAppPrivateKey
          {
            secretKey = "type"
            remoteRef = {
              key      = "${var.argocd_secret_name}"
              property = "type"
            } 
          },
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
          }
        ]
      }
    },
    
    # ExternalSecret for repository connection with minimal keys in it -> K8s Secret
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
        # using the secret store we created before
        secretStoreRef  = {
          name = "aws-sm-argocd"
          kind = "SecretStore"
        }
        target = {
          # K8s Secret name
          name           = "${var.project_tag}-${var.environment}-argocd-secrets-app-repo"
          creationPolicy = "Owner"
          template       = {
            metadata = {
              labels = {
                # label so argoCD will use this automatically
                "argocd.argoproj.io/secret-type" = "repository"
              }
            }
          }
        }
        data = [
          # Github authentication requires:
          # type,url,githubAppID,githubAppInstallationID,githubAppPrivateKey
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
        # using the secret store we created before
        secretStoreRef  = {
          name = "aws-sm-argocd"
          kind = "SecretStore"
        }
        target = {
          # K8s Secret name
          name           = "${var.argocd_github_sso_secret_name}"
          creationPolicy = "Owner"
          template       = {
            metadata = {
              labels = {
                # label so argoCD will use this automatically
                "app.kubernetes.io/part-of" = "argocd"
              }
            }
          }
        }
        data = [
          # SSO requires:
          # clientID, clientSecret
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
      }
    }
  ]
}

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

  depends_on = [
    kubernetes_service_account.this
  ]
}


resource "kubernetes_service_account" "this" {
  metadata {
    name      = var.service_account_name
    namespace = var.namespace
  }
}
