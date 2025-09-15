# Frontend application values - static configuration
# This file is created once during bootstrap and maintained in Git

replicaCount: 1

# HPA Configuration
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 3
  targetCPUUtilizationPercentage: 70
  # targetMemoryUtilizationPercentage: 80  # Optional

# Resource requests/limits for HPA to work
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
