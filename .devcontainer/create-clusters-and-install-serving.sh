export KO_DOCKER_REPO=ko.local

# Build Knative
echo "Building Knative..."
export YAML_OUTPUT_DIR=$HOME/artifacts/build
mkdir -p ${YAML_OUTPUT_DIR}
./hack/generate-yamls.sh "/workspaces/serving" "$(mktemp)" $YAML_OUTPUT_DIR/env

# Build Test Images
echo "Building test images..."
./test/upload-test-images.sh

# Configure KinD Cluster
echo "Creating KinD cluster..."
mkdir -p /tmp/etcd
mount -t tmpfs tmpfs /tmp/etcd
kind create cluster --config .devcontainer/kind.yaml --wait 5m

# Setup Registry
echo "Setting up registry..."
docker run -d --restart=always -p 5000:5000 -v ~/artifacts/registry:/var/lib/registry --name registry.local registry:2
echo "127.0.0.1 registry.local" | tee -a /etc/hosts

# Deploy cert-manager
kubectl apply -f ./third_party/cert-manager-latest/cert-manager.yaml
kubectl wait --for=condition=Established --all crd
kubectl wait --for=condition=Available -n cert-manager --all deployments

# Install Serving & Ingress
# rm ./test/config/chaosduck/chaosduck.yaml
echo "Install Serving & Ingress"
source ./test/e2e-common.sh
export INSTALL_CUSTOM_YAMLS=$HOME/artifacts/build/env
knative_setup