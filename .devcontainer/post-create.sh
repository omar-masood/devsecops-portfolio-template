#!/bin/bash
set -e

echo "Setting up DevSecOps Portfolio environment..."

echo "Installing additional tools (vim, unzip, git-lfs)..."
sudo apt-get update -qq
sudo apt-get install -y vim unzip git-lfs
git lfs install

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

echo "Verifying Docker..."
docker_ready=0
for _ in $(seq 1 30); do
  if docker info >/dev/null 2>&1; then
    docker_ready=1
    break
  fi
  sleep 1
done

if [ "$docker_ready" -eq 1 ]; then
  docker --version || true
  docker compose version || true
else
  echo "Warning: Docker daemon did not become ready in time; skipping pre-pull."
fi

echo "Verifying Python..."
python3 --version
pip3 --version

echo "Installing kind..."
curl -fsSLo ./kind "https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-${ARCH}"
sudo install -m 755 ./kind /usr/local/bin/kind
rm ./kind
kind version

echo "Installing kustomize..."
curl -fsSL "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo install -m 755 ./kustomize /usr/local/bin/kustomize
rm ./kustomize

echo "Installing HashiCorp Vault CLI..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update -qq
sudo apt-get install -y vault

echo "Installing ruff and bandit..."
pip3 install --user --upgrade ruff bandit
sudo ln -sf "$HOME/.local/bin/ruff" /usr/local/bin/ruff
sudo ln -sf "$HOME/.local/bin/bandit" /usr/local/bin/bandit

echo "Installing hadolint..."
HADOLINT_ARCH="x86_64"
if [ "$ARCH" = "arm64" ]; then
  HADOLINT_ARCH="arm64"
fi
curl -fsSLo ./hadolint "https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-${HADOLINT_ARCH}"
sudo install -m 755 ./hadolint /usr/local/bin/hadolint
rm ./hadolint

echo "Installing trivy..."
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin

echo "Installing kubeconform..."
curl -fsSLo /tmp/kubeconform.tar.gz "https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-${ARCH}.tar.gz"
tar -xzf /tmp/kubeconform.tar.gz -C /tmp kubeconform
sudo install -m 755 /tmp/kubeconform /usr/local/bin/kubeconform
rm -f /tmp/kubeconform /tmp/kubeconform.tar.gz

echo "Installing Python app dependencies..."
if [ -f pyproject.toml ]; then
  pip3 install --user -e ".[dev]" 2>/dev/null || pip3 install --user -e . 2>/dev/null || true
fi

echo ""
echo "Environment setup complete!"
echo ""
echo "Installed tools:"
echo "  docker:      $(docker --version 2>/dev/null || echo 'waiting for daemon')"
echo "  kubectl:     $(kubectl version --client 2>/dev/null | head -1)"
echo "  helm:        $(helm version --short 2>/dev/null)"
echo "  kind:        $(kind version 2>/dev/null)"
echo "  kustomize:   $(kustomize version 2>/dev/null)"
echo "  vault:       $(vault version 2>/dev/null)"
echo "  ruff:        $(ruff --version 2>/dev/null)"
echo "  bandit:      $(bandit --version 2>/dev/null | head -1)"
echo "  hadolint:    $(hadolint --version 2>/dev/null | head -1)"
echo "  trivy:       $(trivy --version 2>/dev/null | head -1)"
echo "  kubeconform: $(kubeconform -v 2>/dev/null)"
echo ""
echo "Next steps:"
echo "  1. Create a kind cluster:  kind create cluster --name lab"
echo "  2. Install ArgoCD:         helm repo add argo https://argoproj.github.io/argo-helm && helm install argocd argo/argo-cd --namespace argocd --create-namespace"
echo "  3. Run the CI tools:       ruff check app/ && bandit -r app/"
echo ""
