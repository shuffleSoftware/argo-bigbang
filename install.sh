#!/bin/bash

# Optional: Set Git credentials for private repositories
source .env
REPO_USER=$GITHUB_USER
REPO_PASSWORD=$GITHUB_PAT
REPO_URL=$GITHUB_URL

echo $GITHUB_URL

if [[ $# -eq 0 ]]; then
    echo 'Please provide an environment parameter (e.g., dev, stage, prod)'
    exit 1
fi

ENV=$1
GITHUB_ACCOUNT=${2:-"shuffleSoftware"} # Set default value "argo-universe" if second argument is not provided

# Set environment variable
export ENV=$ENV

# Create Kubernetes namespaces for ArgoCD and Ingress
kubectl create ns argocd

# --------------------------------------------------------------------------------------------
# Install ArgoCD
# --------------------------------------------------------------------------------------------
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update argo
helm upgrade --install argocd argo/argo-cd -n argocd --version 7.7.22 --values values.yaml \
  --set configs.credentialTemplates.github.url="${CUSTOM_URL}" \
  --set configs.credentialTemplates.github.password="${CUSTOM_TOKEN}" \
  --set configs.credentialTemplates.github.username="${CUSTOM_USERNAME}"
# helm template argocd argo/argo-cd -n argocd --version 7.7.22 --values values.yaml > template.yaml
# Wait for the Deployment to be ready
echo "Waiting for Deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# prometheus CDR's
# kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.80.0/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagerconfigs.yaml
# kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.80.0/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml
# kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.80.0/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml
# kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.80.0/example/prometheus-operator-crd/monitoring.coreos.com_probes.yaml
# kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.80.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheusagents.yaml
# kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.80.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml
# kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.80.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml
# kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.80.0/example/prometheus-operator-crd/monitoring.coreos.com_scrapeconfigs.yaml
# kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.80.0/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
# kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.80.0/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml

# --------------------------------------------------------------------------------------------
# Install BigBang application using the Helm chart from the local repository
# --------------------------------------------------------------------------------------------
echo "upgrade --install bigbang-app bigbang/bigbang-app -n argocd --set env=\"$ENV\"  --set gitHubAccount=\"$GITHUB_ACCOUNT\""
helm upgrade --install bigbang-app \
  bigbang/bigbang-app \
  -n argocd \
  --set env="$ENV" \
  --set gitHubAccount="$GITHUB_ACCOUNT" \
  --set custom_github_url="${CUSTOM_URL}" \
  --set custom_github_password="${CUSTOM_TOKEN}" \
  --set custom_github_username="${CUSTOM_USERNAME}"

# Echo Argocd admin password
ArgoCDAdminPassword=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD admin password is $ArgoCDAdminPassword"

 if [ "$ENV" = "dev" ]; then
  argo_ing=$(kubectl get ing argocd-server -n argocd -o jsonpath='{.spec.rules[0].host}')
  echo "Visit: $argo_ing"
else
  echo "ENV variable is not set to 'dev'. No port forwarding needed."
fi


# helm template bigbang-app \
#   bigbang/bigbang-app \
#   -n argocd \
#   --set env="$ENV" \
#   --set gitHubAccount="$GITHUB_ACCOUNT" \
#   --set custom_github_url="${CUSTOM_URL}" \
#   --set custom_github_password="${CUSTOM_TOKEN}" \
#   --set custom_github_username="${CUSTOM_USERNAME}" > template.yaml