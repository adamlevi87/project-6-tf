# terraform-main/modules/helm/kube-prometheus-stack/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
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

resource "helm_release" "kube_prometheus_stack" {
  name       = var.release_name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.chart_version
  namespace  = var.namespace
  
  create_namespace = false
  wait            = true
  timeout         = 600  # 10 minutes - monitoring stack can take time

  values = [
    yamlencode({
      # Global settings
      global = {
        rbac = {
          create = true
        }
      }

      # Prometheus configuration
      prometheus = {
        prometheusSpec = {
          retention = var.prometheus_retention
          retentionSize = var.prometheus_retention_size
          
          # Storage configuration
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.storage_class
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.prometheus_storage_size
                  }
                }
              }
            }
          }
          
          # Resource limits
          resources = {
            requests = {
              cpu    = var.prometheus_cpu_requests
              memory = var.prometheus_memory_requests
            }
            limits = {
              cpu    = var.prometheus_cpu_limits
              memory = var.prometheus_memory_limits
            }
          }
          
          # Service monitor selector (important for ArgoCD integration)
          serviceMonitorSelectorNilUsesHelmValues = false
          serviceMonitorSelector = {}
          
          # Rule selector
          ruleSelectorNilUsesHelmValues = false
          ruleSelector = {}
          
          # Pod monitor selector
          podMonitorSelectorNilUsesHelmValues = false
          podMonitorSelector = {}
        }
        
        # Ingress for Prometheus
        ingress = {
          enabled = true
          ingressClassName = "${var.ingress_controller_class}"
          hosts = ["${var.prometheus_domain}"]
          path = "/"
          pathType = "Prefix"
          annotations = {
            "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
            "alb.ingress.kubernetes.io/target-type" = "ip"
            "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
            "alb.ingress.kubernetes.io/ssl-redirect" = "443"
            "alb.ingress.kubernetes.io/group.name"  = "${var.alb_group_name}"
            "alb.ingress.kubernetes.io/security-groups" = "${var.alb_security_groups}"
            "alb.ingress.kubernetes.io/certificate-arn" = "${var.acm_certificate_arn}"
            "external-dns.alpha.kubernetes.io/hostname" = "${var.prometheus_domain}"
            # Restrict access to specific IPs
            "alb.ingress.kubernetes.io/conditions.${var.release_name}-prometheus" = jsonencode([{
              field = "source-ip"
              sourceIpConfig = {
                values = "${var.prometheus_allowed_cidr_blocks}"
              }
            }])
          }
        }
      }

      # Grafana configuration
      grafana = {
        enabled = true
        
        # Admin credentials
        adminPassword = var.grafana_admin_password
        
        # Persistence
        persistence = {
          enabled          = true
          storageClassName = var.storage_class
          size             = var.grafana_storage_size
        }
        
        # Resource limits
        resources = {
          requests = {
            cpu    = var.grafana_cpu_requests
            memory = var.grafana_memory_requests
          }
          limits = {
            cpu    = var.grafana_cpu_limits
            memory = var.grafana_memory_limits
          }
        }
        
        # Grafana configuration
        "grafana.ini" = {
          server = {
            root_url = "https://${var.grafana_domain}"
          }
          security = {
            disable_gravatar = true
          }
        }
        
        # Ingress configuration
        ingress = {
          enabled = true
          ingressClassName = "${var.ingress_controller_class}"
          hosts = ["${var.grafana_domain}"]
          path = "/"
          pathType = "Prefix"
          annotations = {
            "alb.ingress.kubernetes.io/scheme" = "internet-facing"
            "alb.ingress.kubernetes.io/target-type" = "ip"
            "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
            "alb.ingress.kubernetes.io/ssl-redirect" = "443"
            "alb.ingress.kubernetes.io/group.name" = "${var.alb_group_name}"
            "alb.ingress.kubernetes.io/security-groups" = "${var.alb_security_groups}"
            "alb.ingress.kubernetes.io/certificate-arn" = "${var.acm_certificate_arn}"
            "external-dns.alpha.kubernetes.io/hostname" = "${var.grafana_domain}"
            "alb.ingress.kubernetes.io/conditions.${var.release_name}-grafana" = jsonencode([
              {
                field = "source-ip"
                sourceIpConfig = {
                  values = "${var.grafana_allowed_cidr_blocks}"
                }
              }
            ])
          }
        }
        
        # Default dashboards
        defaultDashboardsEnabled = true
        
        # Additional dashboards
        dashboardProviders = {
          "dashboardproviders.yaml" = {
            apiVersion = 1
            providers = [{
              name = "default"
              orgId = 1
              folder = ""
              type = "file"
              disableDeletion = false
              editable = true
              options = {
                path = "/var/lib/grafana/dashboards/default"
              }
            }]
          }
        }
      }

      # AlertManager configuration
      alertmanager = {
        enabled = true
        
        alertmanagerSpec = {
          # Storage
          storage = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.storage_class
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.alertmanager_storage_size
                  }
                }
              }
            }
          }
          
          # Resource limits
          resources = {
            requests = {
              cpu    = var.alertmanager_cpu_requests
              memory = var.alertmanager_memory_requests
            }
            limits = {
              cpu    = var.alertmanager_cpu_limits  
              memory = var.alertmanager_memory_limits
            }
          }
        }
        
        # Basic AlertManager configuration
        config = {
          global = {
            smtp_smarthost = "localhost:587"
            smtp_from = "alertmanager@${var.domain_name}"
          }
          
          route = {
            group_by = ["alertname"]
            group_wait = "10s"
            group_interval = "10s"
            repeat_interval = "1h"
            receiver = "web.hook"
          }
          
          receivers = [{
            name = "web.hook"
            # Add your notification channels here
            # slack_configs, email_configs, webhook_configs, etc.
          }]
        }
      }

      # Node Exporter
      nodeExporter = {
        enabled = true
      }
      "prometheus-node-exporter" = {
        affinity = {
          nodeAffinity = {
            requiredDuringSchedulingIgnoredDuringExecution = {
              nodeSelectorTerms = [
                {
                  matchExpressions = [
                    {
                      key = "kubernetes.io/os"
                      operator = "In"
                      values = ["linux"]
                    }
                  ]
                }
              ]
            }
          }
        }
      }
      # Kube State Metrics
      kubeStateMetrics = {
        enabled = true
      }

      # CoreDNS monitoring
      coreDns = {
        enabled = true
      }

      # Kubelet monitoring
      kubelet = {
        enabled = true
        serviceMonitor = {
          metricRelabelings = [
            # Drop high-cardinality metrics to save storage
            {
              sourceLabels = ["__name__"]
              regex = "(apiserver_audit_.*|apiserver_cel_.*)"
              action = "drop"
            }
          ]
        }
      }

      # etcd monitoring (if accessible)
      kubeEtcd = {
        enabled = false  # Usually not accessible on managed EKS
      }

      # Controller Manager monitoring (if accessible)
      kubeControllerManager = {
        enabled = false  # Usually not accessible on managed EKS
      }

      # Scheduler monitoring (if accessible)  
      kubeScheduler = {
        enabled = false  # Usually not accessible on managed EKS
      }

      # API Server monitoring
      kubeApiServer = {
        enabled = true
      }

      # Proxy monitoring
      kubeProxy = {
        enabled = true
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.monitoring
  ]
}

# Create monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.namespace
    
    labels = {
      name                                 = var.namespace
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}
