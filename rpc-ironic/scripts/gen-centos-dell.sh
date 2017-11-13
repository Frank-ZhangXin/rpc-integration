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
disk-image-create -o baremetal-$DISTRO_NAME-$DIB_RELEASE $DISTRO_NAME baremetal bootloader local-config proliant-tools devuser eureka-element dhcp-all-interfaces

rm -R *.d/
scp -o StrictHostKeyChecking=no baremetal-$DISTRO_NAME-$DIB_RELEASE* "${UTILITY01_HOSTNAME}":~/images
rm baremetal-$DISTRO_NAME-$DIB_RELEASE*  # no reason to keep these around

VMLINUZ_UUID=$(ssh -o StrictHostKeyChecking=no "${UTILITY01_HOSTNAME}" "source ~/openrc; glance image-create --name baremetal-dell-$DISTRO_NAME-$DIB_RELEASE.vmlinuz \
                                    --visibility public \
                                    --disk-format aki \
                                    --property hypervisor_type=baremetal \
                                    --protected=True \
                                    --container-format aki < ~/images/baremetal-$DISTRO_NAME-$DIB_RELEASE.vmlinuz" | awk '/\| id/ {print $4}')
INITRD_UUID=$(ssh -o StrictHostKeyChecking=no "${UTILITY01_HOSTNAME}" "source ~/openrc; glance image-create --name baremetal-dell-$DISTRO_NAME-$DIB_RELEASE.initrd \
                                   --visibility public \
                                   --disk-format ari \
                                   --property hypervisor_type=baremetal \
                                   --protected=True \
                                   --container-format ari < ~/images/baremetal-$DISTRO_NAME-$DIB_RELEASE.initrd" | awk '/\| id/ {print $4}')
ssh -o StrictHostKeyChecking=no "${UTILITY01_HOSTNAME}" "source ~/openrc; glance image-create --name baremetal-dell-$DISTRO_NAME-$DIB_RELEASE \
  --visibility public \
  --disk-format qcow2 \
  --container-format bare \
  --property hypervisor_type=baremetal \
  --property kernel_id=${VMLINUZ_UUID} \
  --protected=True \
  --property ramdisk_id=${INITRD_UUID} < ~/images/baremetal-$DISTRO_NAME-$DIB_RELEASE.qcow2"
}


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


  # Added for custom element
  export ELEMENTS_PATH="/opt/rpc-integration/rpc-ironic/custom-elements/"

  #CentOS 7
  export DIB_RELEASE=7
  export DISTRO_NAME=centos7
  make-base-image
popd

# utility container doesn't have much space...
ssh -o StrictHostKeyChecking=no "${UTILITY01_HOSTNAME}" "rm ~/images -R"

