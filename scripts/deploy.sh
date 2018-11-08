#!/bin/bash

set -x
source scripts/functions.sh

export PREDIX_REPO_ROOT=`pwd`

cp Dockerfile ~/
cd ~

tar -xvf build_artifact.tar
ls -la

echo "----------------------------"
echo "Deploying Package"
echo "----------------------------"

# Ensure docker is installed
if ! which docker > /dev/null 2>&1; then
  install_docker
fi

sudo service docker start

# Remove any previously built images
if ! require_vars DOCKER_IMAGE; then
  echo "Set required variables"
  exit 1
fi

if sudo docker images -a | awk '{print $1}' | grep $DOCKER_IMAGE > /dev/null 2>&1; then
  for image_id in `docker images -a | grep ^${DOCKER_IMAGE} | awk '{print $3}'`; do 
    sudo docker rmi $image_id
  done
fi

# Build docker image
sudo docker build -t ${DOCKER_IMAGE}:latest .

# Push docker image
if ! require_vars DOCKER_USERNAME DOCKER_PASSWORD; then
  echo "Set required variables"
  exit 2
fi

echo $DOCKER_PASSWORD | sudo docker login --username=${DOCKER_USERNAME} --password-stdin
sudo docker push $DOCKER_IMAGE

# Deploy to kubernetes cluster

install_kubectl

if ! require_vars NUTRO_K8S_PASSWORD; then
  echo "Set required variables (NUTRO_K8S_PASSWORD)"
  exit 2
fi

# Hardcoded IP of k8s master node - can also acheive this by creating private hosted zone in route 53, doing this now for brevity
echo "54.165.1.73 api.k8s-nutro.slno.net" >> /etc/hosts

# Set up config for nutro sandbox
kubectl config --kubeconfig=predix-demo set-cluster nutro --server=https://api.k8s-nutro.slno.net --insecure-skip-tls-verify
kubectl config --kubeconfig=predix-demo set-credentials admin --username=admin --password=$NUTRO_K8S_PASSWORD
kubectl config --kubeconfig=predix-demo set-context predix-ci-demo --cluster=nutro --namespace=default --user=admin
kubectl config --kubeconfig=predix-demo use-context predix-ci-demo

kubectl patch deployment canary --kubeconfig=predix-demo --namespace demo -p \
  "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"date\":\"`date +'%s'`\"}}}}}"

echo "----------------------------"
echo "Success"
echo "Kubernetes Service is at : http://a37bfd6c8549311e8adec0eae065c225-44571616.us-east-1.elb.amazonaws.com/"
echo "----------------------------"
