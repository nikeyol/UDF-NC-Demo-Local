#!/usr/bin/env bash

# change time zone
cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
timedatectl set-timezone Asia/Shanghai
rm /etc/yum.repos.d/CentOS-Base.repo
cp /vagrant/yum/*.* /etc/yum.repos.d/
mv /etc/yum.repos.d/CentOS7-Base-163.repo /etc/yum.repos.d/CentOS-Base.repo

yum install -y curl wget jq envsubst awk bash getent grep gunzip less openssl sed tar base64 basename cat dirname head id mkdir numfmt sort tee

echo 'set host name resolution'
cat >> /etc/hosts <<EOF
172.17.10.202 node2
172.17.10.201 node1
EOF

cat /etc/hosts

echo 'set nameserver'
echo "nameserver 8.8.8.8">/etc/resolv.conf
cat /etc/resolv.conf

echo 'disable swap'
swapoff -a
sed -i '/swap/s/^/#/' /etc/fstab


sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
sudo yum install -y vim
sudo yum install -y postgresql95 postgresql95-devel postgresql95-server postgresql95-contrib

POSTGRES_RUNNING=$(service postgresql-9.5 status | egrep  "postgresql.*running" | wc -l)
if [ "$POSTGRES_RUNNING" -ne 1 ]; then
  echo 'Starting Postgres'
  sudo /usr/pgsql-9.5/bin/postgresql95-setup initdb
  # sudo /sbin/service postgresql-9.5 initdb
  sudo /sbin/service postgresql-9.5 start
  sudo /sbin/chkconfig postgresql-9.5 on
else
  echo "Postgres is running"
fi

ln -s /usr/pgsql-9.5/bin/psql /usr/bin/psql
sudo ln -s /usr/pgsql-9.5/bin/postgres /usr/bin/postgres

echo "Creating postgres user:"
ALTER_POSTGRES_USER_SQL="ALTER USER postgres WITH ENCRYPTED PASSWORD 'postgres'"
sudo -u postgres psql --command="$ALTER_POSTGRES_USER_SQL"

echo "Updating postgresql connection info"
sudo cp /var/lib/pgsql/9.5/data/pg_hba.conf .
sudo chmod 666 pg_hba.conf
sed 's/ident/md5/' < pg_hba.conf > pg_hba2.conf
echo 'host    all             all             0.0.0.0/0               md5' >> pg_hba2.conf
sudo cp pg_hba2.conf /var/lib/pgsql/9.5/data/pg_hba.conf
sudo chmod 600 /var/lib/pgsql/9.5/data/pg_hba.conf

sudo cp /var/lib/pgsql/9.5/data/postgresql.conf .
sudo chmod 666 postgresql.conf
sed "s/^#listen_addresses.*$/listen_addresses = '0.0.0.0'/" < postgresql.conf > postgresql2.conf
sudo cp postgresql2.conf /var/lib/pgsql/9.5/data/postgresql.conf
sudo chmod 600 /var/lib/pgsql/9.5/data/postgresql.conf

echo "Patching complete, restarting"
sudo /sbin/service postgresql-9.5 restart

# install docker
DOCKER_VERSION=18.09
sudo yum install -y yum-utils \
  device-mapper-persistent-data \
  lvm2

sudo yum-config-manager \
      --add-repo \
      https://download.docker.com/linux/centos/docker-ce.repo

sudo yum install docker-ce-${DOCKER_VERSION} docker-ce-cli-${DOCKER_VERSION} containerd.io
sudo systemctl enable docker
sudo systemctl start docker


# pull nc docker required docker image
KUBE_VERSION=v1.15.5
KUBE_PAUSE_VERSION=3.1
ETCD_VERSION=3.3.10
CORE_DNS_VERSION=1.3.1

GCR_URL=k8s.gcr.io
ALIYUN_URL=registry.cn-hangzhou.aliyuncs.com/google_containers

images=(kube-proxy:${KUBE_VERSION}
kube-scheduler:${KUBE_VERSION}
kube-controller-manager:${KUBE_VERSION}
kube-apiserver:${KUBE_VERSION}
pause:${KUBE_PAUSE_VERSION}
etcd:${ETCD_VERSION}
coredns:${CORE_DNS_VERSION})

for imageName in ${images[@]} ; do
  docker pull $ALIYUN_URL/$imageName
  docker tag  $ALIYUN_URL/$imageName $GCR_URL/$imageName
  docker rmi $ALIYUN_URL/$imageName
done

docker pull quay-mirror.qiniu.com/coreos/flannel:v0.11.0-amd64
docker tag quay-mirror.qiniu.com/coreos/flannel:v0.11.0-amd64 quay.io/coreos/flannel:v0.11.0-amd64
docker rmi quay-mirror.qiniu.com/coreos/flannel:v0.11.0-amd64




# install NC env
#sudo cp -rf /vagrant/controller-installer /home
#udo cd /home/controller-installer && sudo chmod +x *.#!/bin/sh
# sudo sh  ./install.sh
