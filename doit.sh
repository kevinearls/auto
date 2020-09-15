#!/usr/bin/env bash
set -x
set -e

echo Starting minikube
minikube stop || true
minikube delete || true
minikube start --memory 12288 --vm-driver hyperkit
minikube addons enable ingress
minikube addons enable metrics-server
minikube ssh -- 'sudo sysctl -w vm.max_map_count=262144'

Echo creating es instance
kubectl create --namespace default -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/test/elasticsearch.yml
kubectl wait --for=condition=Ready pod/elasticsearch-0 --namespace default --timeout=300s

Echo install Jaeger Operator
kubectl create namespace observability
kubectl create -n observability -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/crds/jaegertracing.io_jaegers_crd.yaml || true
kubectl create -n observability -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/service_account.yaml
kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/cluster_role.yaml
kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/cluster_role_binding.yaml

# Modified version to watch all namespaces
kubectl create -n observability -f ./operator.yaml

kubectl get deployment jaeger-operator --namespace observability
kubectl wait --for=condition=available deployment/jaeger-operator --namespace observability --timeout=300s

# TODO install simple-prod and wait for it
echo install simple-prod
kubectl create namespace simple
kubectl create --namespace simple -f ./simple-prod.yaml
sleep 15
kubectl wait --for=condition=available deployment/simple-prod-collector --namespace simple --timeout=300s

# install tracegen  -- copy yaml
kubectl create --namespace simple -f ./tracegen.yaml
kubectl get pods --namespace simple --watch

# TODO start a bunch of oc get commands?
