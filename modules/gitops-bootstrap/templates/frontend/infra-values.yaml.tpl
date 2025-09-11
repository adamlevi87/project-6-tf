# Frontend infrastructure values - managed by Terraform
# digest is managed by the application repo workflow (build-and-push action or update-digest-only)

image:
  repository: "${ecr_frontend_repo_url}"
  digest: "sha256:YOUR_SHA"
  tag: ""
  pullPolicy: Always

namespace:
  name: ${frontend_namespace}
  create: false

service:
  type: "ClusterIP"
  port: 80

serviceAccount:
  create: false
  name: ${frontend_service_account_name}

containerPort: ${frontend_container_port}

ingress:
  enabled: true
  host: "${frontend_ingress_host}"
  ingressControllerClassResourceName: "alb"
  ingressPath: "/"
  annotations:
    alb.ingress.kubernetes.io/scheme: "internet-facing"
    alb.ingress.kubernetes.io/target-type: "ip"
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/group.name: "${alb_group_name}"
    #SG list order argo,frontend
    alb.ingress.kubernetes.io/security-groups: "${alb_security_groups}"
    alb.ingress.kubernetes.io/certificate-arn: "${acm_certificate_arn}"
    # External DNS annotation (optional - helps external-dns identify the record)
    external-dns.alpha.kubernetes.io/hostname: "${frontend_external_dns_hostname}"

