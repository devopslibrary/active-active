# Tested with:

- terraform v0.13.5
- AWS terraform provider v3.12.0

# Prerequisites

- 6 EIPs (3 in us-east-1 & 3 in us-east-2)

# TODO
ADD FIREWALL RULES

# Istio Install

aws eks --region us-east-1 update-kubeconfig --name virginia-cluster
git clone git@github.com:istio/istio.git
kubectl create namespace istio-system
kubectl create secret generic cacerts -n istio-system \
 --from-file=../istio/samples/certs/ca-cert.pem \
 --from-file=../istio/samples/certs/ca-key.pem \
 --from-file=../istio/samples/certs/root-cert.pem \
 --from-file=../istio/samples/certs/cert-chain.pem

# For Virginia
cat <<EOF> istio-main-cluster.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  values:
    global:
      multiCluster:
        clusterName: virginia
      network: network1
      # Use the existing istio-ingressgateway.
      meshExpansion:
        enabled: true
EOF

# A bit diff, we use hostname not IP on AWS
export ISTIOD_REMOTE_EP=$(kubectl get svc -n istio-system --context=${MAIN_CLUSTER_CTX} istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "ISTIOD_REMOTE_EP is ${ISTIOD_REMOTE_EP}"

# Ohio time!
aws eks --region us-east-2 update-kubeconfig --name ohio-cluster
kubectl create namespace istio-system
kubectl create secret generic cacerts -n istio-system \
 --from-file=../istio/samples/certs/ca-cert.pem \
 --from-file=../istio/samples/certs/ca-key.pem \
 --from-file=../istio/samples/certs/root-cert.pem \
 --from-file=../istio/samples/certs/cert-chain.pem

cat <<EOF> istio-remote0-cluster.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  values:
    global:
      # The remote cluster's name and network name must match the values specified in the
      # mesh network configuration of the primary cluster.
      multiCluster:
        clusterName: ohio
      network: network1

      # Replace ISTIOD_REMOTE_EP with the the value of ISTIOD_REMOTE_EP set earlier.
      remotePilotAddress: ${ISTIOD_REMOTE_EP}
EOF


kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  namespace: istio-system
  name: httpbin-gateway
spec:
  selector:
    istio: ingressgateway # use Istio default gateway implementation
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin
  namespace: istio-system
spec:
  hosts:
  - "*"
  gateways:
  - httpbin-gateway
  http:
  - match:
    - port: 80
    route:
    - destination:
        port:
          number: 5000
        host: helloworld.sample.svc.cluster.local
EOF
