K8SVERSION=1.15.4-00
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