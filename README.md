# Getting up and running with Calico on your on-premises K8s Cluster

This content was built for free training workshops. If you're looking for general docs for Calico, we recommend you start [here](https://docs.projectcalico.org/getting-started/kubernetes/quickstart)

## Agenda

- Kubernetes networking considerations
  - Choose a pod cidr
  - Choose a service cidr
  - Choose which kube-proxy mode to run
- Calico networking considerations
  - Choose which dataplane to use
  - Choose the initial IP Pool cidr
  - Choose the initial IP Pool block size
  - Choose the initial IP Pool nat outgoing mode
  - How to determine if encapsulation is required
- Install Kubernetes with Calico using kubeadm
- Explore Kubernetes with Calico networking
- Simple Calico network policy example

## Notes

### Kubernetes networking configuration

- Cluster pod cidr:               10.48.0.0/16
- Cluster service cidr:           10.49.0.0/16
- Cluster kube-proxy mode:        iptables

### Calico networking configuration

- Calico dataplane:                  Standard Linux networking
- Calico initial IP Pool cidr:       10.48.0.0/24
- Calico initial IP Pool block size: /26 (default)
- Calico initial IP Pool nat mode:   enabled (default)
- Calico additional IP Pool cidr:    10.48.1.0/24

### Install Kubernetes with Calico using kubeadm

#### All nodes (Ubuntu 18.04 LTS)

##### Initial setup

1. Install kubeadm, cluster dependencies, and friends

```
K8SVERSION=1.18.3-00
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
sudo apt update -y
sudo apt install \
	docker.io \
	watch \
	ipvsadm \
	ipset \
	tcpdump -y
sudo apt install kubeadm=${K8SVERSION} kubelet=${K8SVERSION} kubectl=${K8SVERSION} -y
sudo systemctl enable docker
sudo docker --version
kubeadm version
sudo swapoff -a
sudo kubeadm config images pull
sudo hostnamectl set-hostname `hostname -f`
```

#### Only Master node

##### Initial setup

1. Initialize the kubernetes cluster with iptables mode kube-proxy

`kubeadm-config-iptables-mode.yaml`

```
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
networking:
  serviceSubnet: 10.49.0.0/16
  podSubnet: 10.48.0.0/16
  dnsDomain: cluster.local
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: iptables
```

```
sudo kubeadm reset -f
sudo kubeadm init --config kubeadm-config-iptables-mode.yaml
```

2. Copy the kubectl config into place

```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

3. You should see an output similar to below. It will be different and unique to your environment.

```
kubeadm join 10.0.0.10:6443 --token 0d3aqz.u2bmp0zwlfdh5pmt \
  --discovery-token-ca-cert-hash sha256:726cf64d358aded6a6584271c5342178f10834e254bfe8ff08357dcc3c6af877
```

4. Install and configure `calicoctl`

```
curl -O -L  https://github.com/projectcalico/calicoctl/releases/download/v3.16.4/calicoctl
chmod +x calicoctl
sudo mv calicoctl /usr/local/bin
```

`calicoctl.cfg`

```
apiVersion: projectcalico.org/v3
kind: CalicoAPIConfig
metadata:
spec:
  datastoreType: "kubernetes"
  kubeconfig: "/home/ubuntu/.kube/config"
```

```
sudo mkdir -p /etc/calico
sudo cp calicoctl.cfg /etc/calico
```

#### Each Worker node

##### Initial setup

1. Login to workers

2. Reset kubeadm

```
sudo kubeadm reset
```

3. Copy the command from step 3 above and run it on each of your worker nodes. It will look similar to below except you'll have a different token and hash. Make sure you run the command on each worker as root or with sudo.

```
sudo kubeadm join 10.0.0.10:6443 --token 42sy8h.gg7su3eb12dvbu76 --discovery-token-ca-cert-hash sha256:b34cc7c3ee43d7476639624d9b2da9fed9365b7f79525b5c15030f37114a4ccb
```

```
[preflight] Running pre-flight checks
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
[kubelet-start] Downloading configuration for the kubelet from the "kubelet-config-1.15" ConfigMap in the kube-system namespace
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Activating the kubelet service
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

4. Login to the other workers and repeat steps 2 and 3.

##### Only Master node

##### Configure and Install Calico

1. Install the Tigera Calico operator

```
kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
```

2. Download the custom-resources.yaml

```
curl -O -L https://docs.projectcalico.org/manifests/custom-resources.yaml
```

3. Edit the custom-resources.yaml to match your network choices

For more information on configuration options available in this manifest, see [the installation reference](https://docs.projectcalico.org/reference/installation/api).

```
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  # Configures Calico networking.
  calicoNetwork:
    # Note: The ipPools section cannot be modified post-install.
    ipPools:
    - blockSize: 26
      cidr: 10.48.0.0/24
      encapsulation: None
      natOutgoing: Enabled
      nodeSelector: all()
```

4. Install Calico by creating the necessary custom resource.

```
kubectl create -f custom-resources.yaml
```

5. Confirm that all of the pods are running with the following command.

```
watch kubectl get pods -n calico-system
```

6. Remove the taints on the master so that you can schedule pods on it.

```
kubectl taint nodes --all node-role.kubernetes.io/master-
```

7. Confirm that you now have a node in your cluster with the following command.

```
kubectl get nodes -o wide
kubectl get pods -o wide --all-namespaces 
```

##### Explore Kubernetes with Calico networking

Let's look around and explore

1. Check out the Calico node status.

```
sudo calicoctl node status
```

```
Calico process is running.

IPv4 BGP status
+--------------+-------------------+-------+----------+-------------+
| PEER ADDRESS |     PEER TYPE     | STATE |  SINCE   |    INFO     |
+--------------+-------------------+-------+----------+-------------+
| 10.0.0.236   | node-to-node mesh | up    | 00:11:57 | Established |
| 10.0.0.30    | node-to-node mesh | up    | 00:12:10 | Established |
+--------------+-------------------+-------+----------+-------------+

IPv6 BGP status
No IPv6 peers found.
```

2. Verify your IP pool settings

```
calicoctl get ippools default-ipv4-ippool -o yaml
```

```
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  creationTimestamp: "2020-04-15T23:50:00Z"
  name: default-ipv4-ippool
  resourceVersion: "1063"
  uid: 89bbe3a0-4191-4234-93eb-be5aec34d7ab
spec:
  blockSize: 26
  cidr: 10.48.0.0/24
  ipipMode: Never
  natOutgoing: true
  nodeSelector: all()
  vxlanMode: Never
```

13. Check out our IP pool utilization

```
calicoctl ipam show
```

```
+----------+--------------+-----------+------------+-----------+
| GROUPING |     CIDR     | IPS TOTAL | IPS IN USE | IPS FREE  |
+----------+--------------+-----------+------------+-----------+
| IP Pool  | 10.48.0.0/24 |       256 | 3 (1%)     | 253 (99%) |
+----------+--------------+-----------+------------+-----------+
```

```
calicoctl ipam show --show-blocks
```

```
+----------+----------------+-----------+------------+-----------+
| GROUPING |      CIDR      | IPS TOTAL | IPS IN USE | IPS FREE  |
+----------+----------------+-----------+------------+-----------+
| IP Pool  | 10.48.0.0/24   |       256 | 3 (1%)     | 253 (99%) |
| Block    | 10.48.0.0/26   |        64 | 1 (2%)     | 63 (98%)  |
| Block    | 10.48.0.192/26 |        64 | 2 (3%)     | 62 (97%)  |
+----------+----------------+-----------+------------+-----------+
```

##### Simple Calico network policy example

1.  Inspect the network policies

```
calicoctl get networkpolicies --all-namespaces
```

```
NAMESPACE   NAME

```

2.  Inspect the global network policies

```
calicoctl get globalnetworkpolicies
```

```
NAME

```

3. Deploy the zone-based segmentation policies

```
calicoctl apply -f FirewallZonesPolicies.yaml
```

4. Verify the zone-based segmentation policies

```
calicoctl get networkpolicies --all-namespaces
```

```
NAMESPACE   NAME
default     dmz
default     restricted
default     trusted

```

## References

* Kubeadm Install: https://docs.projectcalico.org/getting-started/kubernetes/quickstart
* Kube-Proxy Mode: https://www.projectcalico.org/comparing-kube-proxy-modes-iptables-or-ipvs/
* Calico IPAM: https://docs.projectcalico.org/networking/ipam
* Intro Calico eBPF dataplane: https://www.projectcalico.org/introducing-the-calico-ebpf-dataplane/
* CNCF Calico eBPF webinar: https://www.cncf.io/webinars/calico-networking-with-ebpf/
* Trying Calico eBPF dataplane: https://docs.projectcalico.org/getting-started/kubernetes/trying-ebpf
