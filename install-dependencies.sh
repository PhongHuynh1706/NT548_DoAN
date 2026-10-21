#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# NT548_DoAN - Install dependencies for Ansible + AWS EKS
# Target: Ubuntu EC2 control node
# ============================================================

PROJECT_DIR="${HOME}/NT548_DoAN/ansible"

# Reuse the active virtualenv if available; otherwise use the
# project's venv, creating it if necessary.
if [[ -n "${VIRTUAL_ENV:-}" ]]; then
    VENV_DIR="${VIRTUAL_ENV}"
else
    VENV_DIR="${PROJECT_DIR}/ansible-venv"
fi

echo "=================================================="
echo " Installing NT548 automation dependencies"
echo " Project : ${PROJECT_DIR}"
echo " Python  : ${VENV_DIR}"
echo "=================================================="

if [[ ! -d "${PROJECT_DIR}" ]]; then
    echo "ERROR: Project directory not found: ${PROJECT_DIR}"
    exit 1
fi

# 1. Install OS packages
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates \
    curl \
    unzip \
    tar \
    gzip \
    git \
    python3 \
    python3-venv \
    python3-pip \
    python3-dev \
    build-essential

# 2. Install AWS CLI v2 if missing
if ! command -v aws >/dev/null 2>&1; then
    echo "[1/6] Installing AWS CLI v2..."

    ARCH="$(uname -m)"
    case "${ARCH}" in
        x86_64)
            AWS_ARCH="x86_64"
            ;;
        aarch64|arm64)
            AWS_ARCH="aarch64"
            ;;
        *)
            echo "ERROR: Unsupported architecture: ${ARCH}"
            exit 1
            ;;
    esac

    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "${TMP_DIR}"' EXIT

    curl -fsSL \
        "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" \
        -o "${TMP_DIR}/awscliv2.zip"

    unzip -q "${TMP_DIR}/awscliv2.zip" -d "${TMP_DIR}"

    if [[ -x /usr/local/aws-cli/v2/current/bin/aws ]]; then
        sudo "${TMP_DIR}/aws/install" \
            --update \
            --install-dir /usr/local/aws-cli \
            --bin-dir /usr/local/bin
    else
        sudo "${TMP_DIR}/aws/install" \
            --install-dir /usr/local/aws-cli \
            --bin-dir /usr/local/bin
    fi

    rm -rf "${TMP_DIR}"
    trap - EXIT
else
    echo "[1/6] AWS CLI already installed."
fi

# 3. Install kubectl if missing
if ! command -v kubectl >/dev/null 2>&1; then
    echo "[2/6] Installing kubectl..."

    KUBECTL_VERSION="$(curl -fsSL \
        https://dl.k8s.io/release/stable.txt)"

    ARCH="$(uname -m)"
    case "${ARCH}" in
        x86_64)  K8S_ARCH="amd64" ;;
        aarch64|arm64) K8S_ARCH="arm64" ;;
        *)
            echo "ERROR: Unsupported architecture: ${ARCH}"
            exit 1
            ;;
    esac

    TMP_BIN="$(mktemp)"
    curl -fsSL \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${K8S_ARCH}/kubectl" \
        -o "${TMP_BIN}"

    sudo install -o root -g root -m 0755 \
        "${TMP_BIN}" /usr/local/bin/kubectl

    rm -f "${TMP_BIN}"
else
    echo "[2/6] kubectl already installed."
fi

# 4. Install Helm 3 if missing
if ! command -v helm >/dev/null 2>&1; then
    echo "[3/6] Installing Helm..."

    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "${TMP_DIR}"' EXIT

    curl -fsSL \
        https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
        -o "${TMP_DIR}/get-helm-3"

    chmod 700 "${TMP_DIR}/get-helm-3"
    "${TMP_DIR}/get-helm-3"

    rm -rf "${TMP_DIR}"
    trap - EXIT
else
    echo "[3/6] Helm already installed."
fi

# 5. Create/use Python virtualenv and install dependencies
echo "[4/6] Preparing Python virtualenv..."

if [[ ! -x "${VENV_DIR}/bin/python" ]]; then
    python3 -m venv "${VENV_DIR}"
fi

"${VENV_DIR}/bin/python" -m pip install --upgrade pip setuptools wheel

"${VENV_DIR}/bin/python" -m pip install --upgrade \
    ansible \
    boto3 \
    botocore \
    kubernetes \
    PyYAML \
    jsonpatch \
    jmespath

# 6. Install Ansible collections
echo "[5/6] Installing Ansible collections..."

"${VENV_DIR}/bin/ansible-galaxy" collection install \
    kubernetes.core amazon.aws

# Verify dependencies
echo "[6/6] Verifying installation..."

aws --version
kubectl version --client
helm version --short
"${VENV_DIR}/bin/python" --version
"${VENV_DIR}/bin/ansible-playbook" --version
"${VENV_DIR}/bin/python" -m pip check
"${VENV_DIR}/bin/ansible-galaxy" collection list

EOF

