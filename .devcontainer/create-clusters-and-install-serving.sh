#!/bin/bash
set -ex

echo "Setting up registry..."
export KO_DOCKER_REPO="registry.local:5000/knative"
docker run -d --restart=always -p 5000:5000 -h 127.0.0.1 -v ~/artifacts/registry:/var/lib/registry --name registry.local registry:2
echo "127.0.0.1 registry.local" | tee -a /etc/hosts

echo "Building Knative..."
export YAML_OUTPUT_DIR=$HOME/artifacts/build
# export KO_FLAGS=--platform=linux/amd64
mkdir -p ~/artifacts/build
mkdir -p ~/artifacts/registry
./hack/generate-yamls.sh "/workspaces/serving" "$(mktemp)" $YAML_OUTPUT_DIR/env

echo "Building test images..."
./test/upload-test-images.sh

echo "Installing dependencies..."
echo "Install kapp..."
curl -Lo ./kapp https://github.com/vmware-tanzu/carvel-kapp/releases/download/v0.46.0/kapp-linux-amd64
chmod +x ./kapp
mv kapp /usr/local/bin

echo "Installing ytt..."
curl -Lo ./ytt https://github.com/vmware-tanzu/carvel-ytt/releases/download/v0.40.1/ytt-linux-amd64
chmod +x ./ytt
mv ytt /usr/local/bin

echo "Creating KinD cluster..."
export INGRESS_CLASS=kourier.ingress.networking.knative.dev
export ENABLE_TLS=0
export KIND=1
mkdir -p /tmp/etcd
mount -t tmpfs tmpfs /tmp/etcd
kind create cluster --config .devcontainer/kind.yaml --wait 5m

echo "Installing metallb"
curl https://raw.githubusercontent.com/metallb/metallb/v0.13.5/config/manifests/metallb-native.yaml -k | \
    sed '0,/args:/s//args:\n        - --webhook-mode=disabled/' | \
    sed '/apiVersion: admissionregistration/,$d' | \
    kubectl apply -f -

# Add Layer 2 config
network=$(docker network inspect kind -f "{{(index .IPAM.Config 0).Subnet}}" | cut -d '.' -f1,2)
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
    name: first-pool
    namespace: metallb-system
spec:
    addresses:
    - $network.255.1-$network.255.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
    name: example
    namespace: metallb-system
EOF

echo "Setup local registry..."
# Connect the registry to the KinD network.
docker network connect "kind" registry.local

echo "Install Serving & Ingress..."
source ./test/e2e-common.sh
export INSTALL_CUSTOM_YAMLS=$HOME/artifacts/build/env
# rm ./test/config/chaosduck/chaosduck.yaml
knative_setup
