#!/bin/bash

# Copyright 2015 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Note: these functions override functions in the GCE configure-vm script
# We include the GCE script first, and this one second.

ensure-basic-networking() {
 # NFSv4 Ports
 iptables -I INPUT 1 -p tcp --dport 2049 -j ACCEPT

 # NFSv3 Ports
 iptables -I INPUT 1 -p tcp --dport 20048 -j ACCEPT
 iptables -I INPUT 1 -p tcp --dport 111 -j ACCEPT

 # glusterfs
iptables -I INPUT 1 -p tcp --dport 38465 -j ACCEPT
iptables -I INPUT 1 -p tcp --dport 38466 -j ACCEPT
iptables -I INPUT 1 -p tcp --dport 38467 -j ACCEPT
iptables -I INPUT 1 -p tcp --dport 38468 -j ACCEPT
iptables -I INPUT 1 -p tcp --dport 24007:24008 -j ACCEPT
iptables -I INPUT 1 -p tcp --dport 49152:49156 -j ACCEPT

# CEPH
iptables -I INPUT 1 -p tcp --dport 6800:7300 -j ACCEPT
iptables -I INPUT 1 -p tcp --dport 6789 -j ACCEPT

#ISCSI

iptables -I INPUT 1 -p tcp --dport 3260 -j ACCEPT



}

ensure-packages() {
 # apt-get-install curl
  # For reading kube_env.yaml
 # apt-get-install python-yaml

  # TODO: Where to get safe_format_and_mount?
  mkdir -p /usr/share/google
  cd /usr/share/google
  download-or-bust "dc96f40fdc9a0815f099a51738587ef5a976f1da" https://raw.githubusercontent.com/GoogleCloudPlatform/compute-image-packages/82b75f314528b90485d5239ab5d5495cc22d775f/google-startup-scripts/usr/share/google/safe_format_and_mount
  chmod +x safe_format_and_mount

  # install Gluster client packages
 #  apt-get install -y -qq glusterfs-client

  # Install rbd client packages
 # apt-get install -y -qq ceph-common
  modprobe rbd

  #Install ISCSI pieces
 # apt-get install -y -qq  open-iscsi
 :

}

set-kube-env() {
  local kube_env_yaml="/etc/kubernetes/kube_env.yaml"

  # kube-env has all the environment variables we care about, in a flat yaml format
  eval "$(python -c '
import pipes,sys,yaml

for k,v in yaml.load(sys.stdin).iteritems():
  print("""readonly {var}={value}""".format(var = k, value = pipes.quote(str(v))))
  print("""export {var}""".format(var = k))
  ' < """${kube_env_yaml}""")"
}

remove-docker-artifacts() {
  :
}

# Finds the master PD device
find-master-pd() {
  if ( grep "/mnt/master-pd" /proc/mounts ); then
    echo "Master PD already mounted; won't remount"
    MASTER_PD_DEVICE=""
    return
  fi
  echo "Waiting for master pd to be attached"
  attempt=0
  while true; do
    echo Attempt "$(($attempt+1))" to check for /dev/xvdb
    if [[ -e /dev/xvdb ]]; then
      echo "Found /dev/xvdb"
      MASTER_PD_DEVICE="/dev/xvdb"
      break
    fi
    attempt=$(($attempt+1))
    sleep 1
  done

  # Mount the master PD as early as possible
  echo "/dev/xvdb /mnt/master-pd ext4 noatime 0 0" >> /etc/fstab
}
apt-get-install() {
 :
}

apt-get-update() {
 :
}


fix-apt-sources() {
  # gluster source
#   wget -O - http://download.gluster.org/pub/gluster/glusterfs/LATEST/rsa.pub | #apt-key add -
#  DEBID=$(grep 'VERSION_ID=' /etc/os-release | cut -d '=' -f 2 | tr -d '"')
#  DEBVER=$(grep 'VERSION=' /etc/os-release | grep -Eo '[a-z]+')
#  echo deb https://download.gluster.org/pub/gluster/glusterfs/LATEST/Debian/${DEBID}/apt ${DEBVER} main > /etc/apt/sources.list.d/gluster.list
#  apt-get update -y -qq
 :
}

salt-master-role() {
  cat <<EOF >/etc/salt/minion.d/grains.conf
grains:
  roles:
    - kubernetes-master
  cloud: aws
EOF

  # If the kubelet on the master is enabled, give it the same CIDR range
  # as a generic node.
  if [[ ! -z "${KUBELET_APISERVER:-}" ]] && [[ ! -z "${KUBELET_CERT:-}" ]] && [[ ! -z "${KUBELET_KEY:-}" ]]; then
    cat <<EOF >>/etc/salt/minion.d/grains.conf
  kubelet_api_servers: '${KUBELET_APISERVER}'
  cbr-cidr: 10.123.45.0/29
EOF
  else
    # If the kubelet is running disconnected from a master, give it a fixed
    # CIDR range.
    cat <<EOF >>/etc/salt/minion.d/grains.conf
  cbr-cidr: ${MASTER_IP_RANGE}
EOF
  fi

  env-to-grains "runtime_config"
  env-to-grains "kube_user"
}

salt-node-role() {
  cat <<EOF >/etc/salt/minion.d/grains.conf
grains:
  roles:
    - kubernetes-pool
  cbr-cidr: 10.123.45.0/29
  cloud: aws
  api_servers: '${API_SERVERS}'
EOF

  # We set the hostname_override to the full EC2 private dns name
  # we'd like to use EC2 instance-id, but currently the kubelet health-check assumes the name
  # is resolvable, although that check should be going away entirely (#7092)
  if [[ -z "${HOSTNAME_OVERRIDE:-}" ]]; then
    HOSTNAME_OVERRIDE=`curl --silent curl http://169.254.169.254/2007-01-19/meta-data/local-hostname`
  fi

  env-to-grains "hostname_override"
}

function run-user-script() {
  # TODO(justinsb): Support user scripts on AWS
  # AWS doesn't have as rich a metadata service as GCE does
  # Maybe specify an env var that is the path to a script?
  :
}

