#!/usr/bin/env bash
set -euo pipefail

# ───────────────────────── helpers ──────────────────────────
log() { printf "\e[1;34m➜ %s\e[0m\n" "$*"; }
need_cmd() { command -v "$1" &>/dev/null; }

arch=$(dpkg --print-architecture)
distro=$(lsb_release -cs)

# ───────────────────────── apt + deps ───────────────────────
log "Màj APT & paquets de base"
sudo apt-get update -y
sudo apt-get install -y curl gnupg ca-certificates lsb-release apt-transport-https

# ───────────────────────── docker engine ────────────────────
if ! need_cmd docker; then
  log "Install Docker CE (moby) allégé"
  if [[ ! -f /etc/apt/sources.list.d/docker.list ]]; then
    curl -fsSL https://download.docker.com/linux/debian/gpg | \
      sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg
    echo "deb [arch=${arch} signed-by=/usr/share/keyrings/docker.gpg] \
https://download.docker.com/linux/debian ${distro} stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list
  fi
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io
else
  log "Docker déjà présent — skip"
fi

# user in docker group
if ! groups "$USER" | grep -q docker; then
  log "Ajout de $USER au groupe docker"
  sudo usermod -aG docker "$USER"
fi

# ───────────────────────── kind + kubectl ───────────────────
desired_kind=v0.23.0
if ! need_cmd kind || [[ $(kind --version 2>/dev/null | awk '{print $3}') != "$desired_kind" ]]; then
  log "Install kind $desired_kind"
  curl -Ls -o kind "https://kind.sigs.k8s.io/dl/${desired_kind}/kind-linux-amd64"
  sudo install -m 755 kind /usr/local/bin/kind
else
  log "kind déjà $desired_kind — skip"
fi

if ! need_cmd kubectl; then
  log "Install kubectl stable"
  curl -Ls -o kubectl \
    "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -m 755 kubectl /usr/local/bin/kubectl
fi

grep -q "alias k=kubectl" ~/.bashrc || echo 'alias k=kubectl' >> ~/.bashrc

# ───────────────────────── kind config ──────────────────────
config=~/kind-pocket.yaml
if [[ ! -f $config ]]; then
  log "Création fichier de config kind « pocket »"
  cat > "$config" <<'YAML'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: pocket
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            system-reserved: "cpu=200m,memory=512Mi"
            kube-reserved:   "cpu=200m,memory=512Mi"
    extraPortMappings:
      - containerPort: 80
        hostPort: 8080
        protocol: TCP
YAML
fi

# ───────────────────────── cluster pocket ───────────────────
if ! kind get clusters | grep -q pocket; then
  log "Création du cluster kind 'pocket'"
  kind create cluster --config "$config" --image kindest/node:v1.30.0
else
  log "Cluster 'pocket' déjà existant — skip création"
fi

# limite CPU / mémoire
CID=$(docker ps --filter "name=pocket-control-plane" -q)
if [[ -n $CID ]]; then
  log "Mise à jour limites container (2 CPU / 3 GiB)"
  docker update --cpus 2 --memory 3g --memory-swap 4g "$CID"
fi

# ───────────────────────── vérification ─────────────────────
log "État du nœud"
kubectl get nodes -o wide
log "🚀  Script terminé. (Relance-le sans crainte : il est idempotent.)"
