#!/usr/bin/env bash

set -e

function cleanup {
  # it's ok if we have some errors on cleanup
  set +e
  unset DIB_DEV_USER_USERNAME DIB_DEV_USER_PASSWORD DIB_DEV_USER_PWDLESS_SUDO
  unset ELEMENTS_PATH DIB_CLOUD_INIT_DATASOURCES DIB_RELEASE DISTRO_NAME
  unset DIB_HPSSACLI_URL IRONIC_AGENT_VERSION
  unset -f make-base-image
  unset -f cleanup
  deactivate
}
# clean up our variables on exit, even exit on error
trap cleanup EXIT

function make-base-image
{
disk-image-create -o baremetal-$DISTRO_NAME-$DIB_RELEASE $DISTRO_NAME baremetal bootloader local-config dhcp-all-interfaces bootloader proliant-tools devuser eureka-element

rm -R *.d/
scp -o StrictHostKeyChecking=no baremetal-$DISTRO_NAME-$DIB_RELEASE* "${UTILITY01_HOSTNAME}":~/images
rm baremetal-$DISTRO_NAME-$DIB_RELEASE*  # no reason to keep these around

VMLINUZ_UUID=$(ssh -o StrictHostKeyChecking=no "${UTILITY01_HOSTNAME}" "source ~/openrc; glance image-create --name baremetal-debug6-$DISTRO_NAME-$DIB_RELEASE.vmlinuz \
                                    --visibility public \
                                    --disk-format aki \
                                    --property hypervisor_type=baremetal \
                                    --protected=True \
                                    --container-format aki < ~/images/baremetal-$DISTRO_NAME-$DIB_RELEASE.vmlinuz" | awk '/\| id/ {print $4}')
INITRD_UUID=$(ssh -o StrictHostKeyChecking=no "${UTILITY01_HOSTNAME}" "source ~/openrc; glance image-create --name baremetal-debug6-$DISTRO_NAME-$DIB_RELEASE.initrd \
                                   --visibility public \
                                   --disk-format ari \
                                   --property hypervisor_type=baremetal \
                                   --protected=True \
                                   --container-format ari < ~/images/baremetal-$DISTRO_NAME-$DIB_RELEASE.initrd" | awk '/\| id/ {print $4}')
ssh -o StrictHostKeyChecking=no "${UTILITY01_HOSTNAME}" "source ~/openrc; glance image-create --name baremetal-debug6-$DISTRO_NAME-$DIB_RELEASE \
  --visibility public \
  --disk-format qcow2 \
  --container-format bare \
  --property hypervisor_type=baremetal \
  --property kernel_id=${VMLINUZ_UUID} \
  --protected=True \
  --property ramdisk_id=${INITRD_UUID} < ~/images/baremetal-$DISTRO_NAME-$DIB_RELEASE.qcow2"
}

# install needed binaries
apt-get install -y kpartx parted qemu-utils

mkdir -p ~/dib
pushd ~/dib
  virtualenv env
  source env/bin/activate

  # newton pip.conf sucks
  if [[ -f ~/.pip/pip.conf ]]; then
    mv ~/.pip/pip.conf{,.bak}
  fi
  # install dib
  pip install pbr  # newton pbr is too old
  if [[ ! -d ~/dib/diskimage-builder ]]; then
    git clone https://github.com/openstack/diskimage-builder/
  fi
  # let's use a new kernel
  if ! grep -q linux-image-generic-lts-xenial ~/dib/diskimage-builder/diskimage_builder/elements/ubuntu/package-installs.yaml; then
    echo 'linux-image-generic-lts-xenial:' > ~/dib/diskimage-builder/diskimage_builder/elements/ubuntu/package-installs.yaml
  fi
  pushd diskimage-builder
    pip install .
  popd
  if [[ -f ~/.pip/pip.conf.bak ]]; then
    mv ~/.pip/pip.conf.bak ~/.pip/pip.conf
  fi

  UTILITY01_HOSTNAME=$(grep infra01_util /etc/hosts | awk '{print $NF}')

  # create image directory in util01 container
  ssh -o StrictHostKeyChecking=no "${UTILITY01_HOSTNAME}" "mkdir -p ~/images"

  # set up envars for the deploy image debug user
  export DIB_DEV_USER_USERNAME=debug-user
  export DIB_DEV_USER_PASSWORD=secrete
  export DIB_DEV_USER_PWDLESS_SUDO=yes

  # set up envars for the deploy image ironic agent
  # export DIB_HPSSACLI_URL="http://downloads.hpe.com/pub/softlib2/software1/pubsw-linux/p1857046646/v109216/hpssacli-2.30-6.0.x86_64.rpm"
  export IRONIC_AGENT_VERSION="stable/ocata"
  # create the deploy image
  disk-image-create --install-type source -o ironic-deploy ironic-agent ubuntu devuser proliant-tools

  rm ironic-deploy.vmlinuz  # not needed or uploaded
  rm -R *.d/  # don't need dib dirs
  scp -o StrictHostKeyChecking=no ironic-deploy* "${UTILITY01_HOSTNAME}":~/images
  rm ironic-deploy*  # no reason to keep these around

  ssh -o StrictHostKeyChecking=no "${UTILITY01_HOSTNAME}" "source ~/openrc; glance image-create --name ironic-deploy.kernel \
    --visibility public \
    --disk-format aki \
    --property hypervisor_type=baremetal \
    --protected=True \
    --container-format aki < ~/images/ironic-deploy.kernel"
  ssh -o StrictHostKeyChecking=no "${UTILITY01_HOSTNAME}" "source ~/openrc; glance image-create --name ironic-deploy.initramfs \
    --visibility public \
    --disk-format ari \
    --property hypervisor_type=baremetal \
    --protected=True \
    --container-format ari < ~/images/ironic-deploy.initramfs"



  #Ubuntu Xenial
  export DIB_CLOUD_INIT_DATASOURCES="Ec2, ConfigDrive, OpenStack"
  export DIB_RELEASE=xenial
  export DISTRO_NAME=ubuntu
#  make-base-image

  #Ubuntu Trusty
  export DIB_RELEASE=trusty
  export DISTRO_NAME=ubuntu
 #  make-base-image

 # Added for custom element
  export ELEMENTS_PATH="/root/custom-elements/"

  #CentOS 7
  export DIB_RELEASE=7
  export DISTRO_NAME=centos7
  make-base-image
popd

# utility container doesn't have much space...
ssh -o StrictHostKeyChecking=no "${UTILITY01_HOSTNAME}" "rm ~/images -R"
