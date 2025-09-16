#!/bin/bash

# terraform-main/modules/github/self_hosted_runner/user-data.sh

set -e

# Variables from Terraform
GITHUB_ORG="${github_org}"
GITHUB_REPO="${github_repo}"
GITHUB_TOKEN="${github_token}"
RUNNER_NAME="${runner_name}"
RUNNER_LABELS="${runner_labels}"
AWS_REGION="${aws_region}"
CLUSTER_NAME="${cluster_name}"

# Log everything
exec > >(tee /var/log/github-runner-setup.log)
exec 2>&1

echo "🚀 Starting GitHub Runner setup..."
echo "Runner: $RUNNER_NAME"
echo "Labels: $RUNNER_LABELS"
echo "Region: $AWS_REGION"
#### debug echo
echo "GITHUB_ORG = $GITHUB_ORG"
echo "GITHUB_REPO = $GITHUB_REPO"
echo "RUNNER_NAME = $RUNNER_NAME"
echo "RUNNER_LABELS = $RUNNER_LABELS"
echo "GITHUB_TOKEN = $GITHUB_TOKEN"

# Update system
apt-get update
apt-get upgrade -y

# Install essential packages
apt-get install -y \
    curl \
    wget \
    unzip \
    git \
    jq \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common

# Install Node.js (required for GitHub Actions runtime)
echo "📦 Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
apt-get install -y nodejs

# Verify Node.js installation
echo "Node.js version: $(node --version)"
echo "npm version: $(npm --version)"

# Install Docker
echo "🐳 Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Install AWS CLI v2
echo "☁️ Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install kubectl
echo "⚙️ Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Install Terraform
echo "🏗️ Installing Terraform..."
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
apt-get update
apt-get install -y terraform

# Install Helm
echo "⛵ Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Configure AWS CLI and kubectl for the main project cluster
echo "🔧 Configuring AWS CLI and kubectl..."
# AWS CLI will use IAM role from instance profile
aws configure set region ${aws_region}

# Configure kubectl for main project EKS cluster (this will be set from remote state)
if [ ! -z "${cluster_name}" ]; then
  aws eks update-kubeconfig --region ${aws_region} --name ${cluster_name}
fi

# Create GitHub runner user
useradd -m -s /bin/bash github-runner
usermod -aG docker github-runner

# Create runner directory
RUNNER_DIR="/opt/actions-runner"
mkdir -p "$RUNNER_DIR"
chown github-runner:github-runner $RUNNER_DIR

# Switch to github-runner user for runner setup
sudo -u github-runner bash << 'EOF'
set -e



echo "🚀 Starting GitHub Runner setup..."
echo "Runner: $RUNNER_NAME"
echo "Labels: $RUNNER_LABELS"
echo "Region: $AWS_REGION"
#### debug echo
echo "GITHUB_ORG = $GITHUB_ORG"
echo "GITHUB_REPO = $GITHUB_REPO"
echo "RUNNER_NAME = $RUNNER_NAME"
echo "RUNNER_LABELS = $RUNNER_LABELS"
echo "GITHUB_TOKEN = $GITHUB_TOKEN"

RUNNER_DIR="/opt/actions-runner"
echo "RUNNER_DIR = $RUNNER_DIR"
cd "$RUNNER_DIR"

# Download GitHub Actions runner
echo "📥 Downloading GitHub Actions runner..."
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/v//')
echo "RUNNER_VERSION = $RUNNER_VERSION"

curl -o actions-runner-linux-x64-$RUNNER_VERSION.tar.gz -L https://github.com/actions/runner/releases/download/v$RUNNER_VERSION/actions-runner-linux-x64-$RUNNER_VERSION.tar.gz

# Extract runner
tar xzf actions-runner-linux-x64-$RUNNER_VERSION.tar.gz
rm actions-runner-linux-x64-$RUNNER_VERSION.tar.gz

# Get registration token
echo "🔑 Getting registration token..."
REG_TOKEN=$(curl -X POST -H "Authorization: token ${github_token}" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/${github_org}/${github_repo}/actions/runners/registration-token" | jq -r .token)

# Configure runner (single runner per instance)
echo "⚙️ Configuring runner..."
./config.sh \
    --url "https://github.com/${github_org}/${github_repo}" \
    --token "$REG_TOKEN" \
    --name "${runner_name}" \
    --labels "${runner_labels}" \
    --unattended \
    --replace

EOF


cd $RUNNER_DIR
./svc.sh install github-runner
./svc.sh start github-runner

# Configure automatic runner cleanup on shutdown
cat > /etc/systemd/system/github-runner-cleanup.service << 'EOF'
[Unit]
Description=GitHub Runner Cleanup
DefaultDependencies=false
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=/bin/true
ExecStop=/opt/actions-runner/cleanup.sh
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

# Create cleanup script
cat > /opt/actions-runner/cleanup.sh << EOF
#!/bin/bash
set -e

#RUNNER_DIR="/opt/actions-runner"
cd $RUNNER_DIR

# Get removal token
REMOVE_TOKEN=$(curl -X POST -H "Authorization: token ${github_token}" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/${github_org}/${github_repo}/actions/runners/remove-token" | jq -r .token)

# Remove runner
sudo -u github-runner ./config.sh remove --token "$REMOVE_TOKEN"
EOF

chmod +x /opt/actions-runner/cleanup.sh
chown github-runner:github-runner /opt/actions-runner/cleanup.sh

# Enable cleanup service
systemctl enable github-runner-cleanup.service
systemctl start github-runner-cleanup.service

echo "✅ GitHub Runner setup complete!"
RUNNER_LIST="${runner_name}"
echo "Runners '$RUNNER_LIST' are now registered and running"

# Test basic connectivity (kubectl will be configured later when main project is deployed)
echo "🧪 Testing basic setup..."
echo "AWS CLI version: $(aws --version)"
echo "Terraform version: $(terraform --version)"
echo "Docker version: $(docker --version)"
echo "✅ All tools installed successfully"
