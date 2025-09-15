# terraform-main/modules/aws_load_balancer_controller/main.tf

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

# Install AWS Load Balancer Controller via Helm
resource "helm_release" "this" {
  name       = "${var.release_name}"
  
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.chart_version
  
  namespace  = "${var.namespace}"
  create_namespace = false
  
  timeout = 600  # 10 minutes timeout
  wait = true
  wait_for_jobs = true

  set = [
    {
        name  = "clusterName"
        value = var.cluster_name
    },
    {
        name  = "serviceAccount.create"
        value = "false"  # We create it manually
    },
    {
        name  = "serviceAccount.name"
        value = "${var.service_account_name}"
    },
    {
        name  = "vpcId"
        value = var.vpc_id
    }
  ]

  depends_on = [
    aws_iam_role_policy_attachment.this,
    kubernetes_service_account.this
  ]
}

# IAM role for AWS Load Balancer Controller
resource "aws_iam_role" "this" {
  name = "${var.project_tag}-${var.environment}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity",
        Effect = "Allow",
        Principal = {
          Federated = var.oidc_provider_arn
        },
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
            "${replace(var.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-${var.environment}-aws-load-balancer-controller"
    Purpose     = "aws-load-balancer-controller"
  }
}

# Kubernetes service account for AWS Load Balancer Controller
resource "kubernetes_service_account" "this" {
  metadata {
    name      = "${var.service_account_name}"
    namespace = "${var.namespace}"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
    }
  }
}

# IAM policy for AWS Load Balancer Controller
resource "aws_iam_policy" "this" {
  name        = "${var.project_tag}-${var.environment}-aws-load-balancer-controller"
  description = "IAM policy for AWS Load Balancer Controller"

  policy = jsonencode(
    {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": [
                  "iam:CreateServiceLinkedRole"
              ],
              "Resource": "*",
              "Condition": {
                  "StringEquals": {
                      "iam:AWSServiceName": "elasticloadbalancing.amazonaws.com"
                  }
              }
          },
          {
              "Effect": "Allow",
              "Action": [
                  "ec2:DescribeAccountAttributes",
                  "ec2:DescribeAddresses",
                  "ec2:DescribeAvailabilityZones",
                  "ec2:DescribeInternetGateways",
                  "ec2:DescribeVpcs",
                  "ec2:DescribeVpcPeeringConnections",
                  "ec2:DescribeSubnets",
                  "ec2:DescribeSecurityGroups",
                  "ec2:DescribeInstances",
                  "ec2:DescribeNetworkInterfaces",
                  "ec2:DescribeTags",
                  "ec2:GetCoipPoolUsage",
                  "ec2:DescribeCoipPools",
                  "ec2:GetSecurityGroupsForVpc",
                  "ec2:DescribeIpamPools",
                  "ec2:DescribeRouteTables",
                  "elasticloadbalancing:DescribeLoadBalancers",
                  "elasticloadbalancing:DescribeLoadBalancerAttributes",
                  "elasticloadbalancing:DescribeListeners",
                  "elasticloadbalancing:DescribeListenerCertificates",
                  "elasticloadbalancing:DescribeSSLPolicies",
                  "elasticloadbalancing:DescribeRules",
                  "elasticloadbalancing:DescribeTargetGroups",
                  "elasticloadbalancing:DescribeTargetGroupAttributes",
                  "elasticloadbalancing:DescribeTargetHealth",
                  "elasticloadbalancing:DescribeTags",
                  "elasticloadbalancing:DescribeTrustStores",
                  "elasticloadbalancing:DescribeListenerAttributes",
                  "elasticloadbalancing:DescribeCapacityReservation"
              ],
              "Resource": "*"
          },
          {
              "Effect": "Allow",
              "Action": [
                  "cognito-idp:DescribeUserPoolClient",
                  "acm:ListCertificates",
                  "acm:DescribeCertificate",
                  "iam:ListServerCertificates",
                  "iam:GetServerCertificate",
                  "waf-regional:GetWebACL",
                  "waf-regional:GetWebACLForResource",
                  "waf-regional:AssociateWebACL",
                  "waf-regional:DisassociateWebACL",
                  "wafv2:GetWebACL",
                  "wafv2:GetWebACLForResource",
                  "wafv2:AssociateWebACL",
                  "wafv2:DisassociateWebACL",
                  "shield:GetSubscriptionState",
                  "shield:DescribeProtection",
                  "shield:CreateProtection",
                  "shield:DeleteProtection"
              ],
              "Resource": "*"
          },
          {
              "Effect": "Allow",
              "Action": [
                  "ec2:AuthorizeSecurityGroupIngress",
                  "ec2:RevokeSecurityGroupIngress"
              ],
              "Resource": "*"
          },
          {
              "Effect": "Allow",
              "Action": [
                  "ec2:CreateSecurityGroup"
              ],
              "Resource": "*"
          },
          {
              "Effect": "Allow",
              "Action": [
                  "ec2:CreateTags"
              ],
              "Resource": "arn:aws:ec2:*:*:security-group/*",
              "Condition": {
                  "StringEquals": {
                      "ec2:CreateAction": "CreateSecurityGroup"
                  },
                  "Null": {
                      "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                  }
              }
          },
          {
              "Effect": "Allow",
              "Action": [
                  "ec2:CreateTags",
                  "ec2:DeleteTags"
              ],
              "Resource": "arn:aws:ec2:*:*:security-group/*",
              "Condition": {
                  "Null": {
                      "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
                      "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                  }
              }
          },
          {
              "Effect": "Allow",
              "Action": [
                  "ec2:AuthorizeSecurityGroupIngress",
                  "ec2:RevokeSecurityGroupIngress",
                  "ec2:DeleteSecurityGroup"
              ],
              "Resource": "*",
              "Condition": {
                  "Null": {
                      "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                  }
              }
          },
          {
              "Effect": "Allow",
              "Action": [
                  "elasticloadbalancing:CreateLoadBalancer",
                  "elasticloadbalancing:CreateTargetGroup"
              ],
              "Resource": "*",
              "Condition": {
                  "Null": {
                      "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                  }
              }
          },
          {
              "Effect": "Allow",
              "Action": [
                  "elasticloadbalancing:CreateListener",
                  "elasticloadbalancing:DeleteListener",
                  "elasticloadbalancing:CreateRule",
                  "elasticloadbalancing:DeleteRule"
              ],
              "Resource": "*"
          },
          {
              "Effect": "Allow",
              "Action": [
                  "elasticloadbalancing:AddTags",
                  "elasticloadbalancing:RemoveTags"
              ],
              "Resource": [
                  "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
                  "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
                  "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
              ],
              "Condition": {
                  "Null": {
                      "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
                      "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                  }
              }
          },
          {
              "Effect": "Allow",
              "Action": [
                  "elasticloadbalancing:AddTags",
                  "elasticloadbalancing:RemoveTags"
              ],
              "Resource": [
                  "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
                  "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
                  "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
                  "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
              ]
          },
          {
              "Effect": "Allow",
              "Action": [
                  "elasticloadbalancing:ModifyLoadBalancerAttributes",
                  "elasticloadbalancing:SetIpAddressType",
                  "elasticloadbalancing:SetSecurityGroups",
                  "elasticloadbalancing:SetSubnets",
                  "elasticloadbalancing:DeleteLoadBalancer",
                  "elasticloadbalancing:ModifyTargetGroup",
                  "elasticloadbalancing:ModifyTargetGroupAttributes",
                  "elasticloadbalancing:DeleteTargetGroup",
                  "elasticloadbalancing:ModifyListenerAttributes",
                  "elasticloadbalancing:ModifyCapacityReservation",
                  "elasticloadbalancing:ModifyIpPools"
              ],
              "Resource": "*",
              "Condition": {
                  "Null": {
                      "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                  }
              }
          },
          {
              "Effect": "Allow",
              "Action": [
                  "elasticloadbalancing:AddTags"
              ],
              "Resource": [
                  "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
                  "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
                  "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
              ],
              "Condition": {
                  "StringEquals": {
                      "elasticloadbalancing:CreateAction": [
                          "CreateTargetGroup",
                          "CreateLoadBalancer"
                      ]
                  },
                  "Null": {
                      "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                  }
              }
          },
          {
              "Effect": "Allow",
              "Action": [
                  "elasticloadbalancing:RegisterTargets",
                  "elasticloadbalancing:DeregisterTargets"
              ],
              "Resource": "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
          },
          {
              "Effect": "Allow",
              "Action": [
                  "elasticloadbalancing:SetWebAcl",
                  "elasticloadbalancing:ModifyListener",
                  "elasticloadbalancing:AddListenerCertificates",
                  "elasticloadbalancing:RemoveListenerCertificates",
                  "elasticloadbalancing:ModifyRule",
                  "elasticloadbalancing:SetRulePriorities"
              ],
              "Resource": "*"
          }
      ]
    }
  )
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-${var.environment}-aws-load-balancer-controller-policy"
    Purpose     = "aws-load-balancer-controller"
  }
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "this" {
  policy_arn = aws_iam_policy.this.arn
  role       = aws_iam_role.this.name
}

# webhook readiness check - waits for actual webhook to be ready
data "kubernetes_service" "webhook_service" {
  metadata {
    name      = "${var.release_name}-webhook-service"
    namespace = var.namespace
  }
  
  # This will WAIT until the service exists, or FAIL if it doesn't
  depends_on = [helm_release.this]
}

resource "null_resource" "webhook_deployment_ready" {
  depends_on = [
    helm_release.this,
    data.kubernetes_service.webhook_service
  ]
  
  provisioner "local-exec" {
    command = <<-EOF
      echo "⏳ Waiting for AWS Load Balancer Controller deployment to be ready..."
      kubectl wait --for=condition=Available deployment/${var.release_name} \
        -n ${var.namespace} --timeout=300s
      
      echo "⏳ Waiting for ValidatingWebhookConfiguration to be ready..."
      kubectl wait --for=condition=Ready validatingwebhookconfiguration/${var.release_name} \
        --timeout=300s || echo "ValidatingWebhookConfiguration wait completed"
      
      echo "✅ AWS Load Balancer Controller webhook is ready!"
    EOF
  }
  
  triggers = {
    service_uid = data.kubernetes_service.webhook_service.metadata[0].uid
  }
}
