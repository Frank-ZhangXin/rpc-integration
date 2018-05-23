Notice
This guide shows deployment RPC Openstack with RPC Ceph.

# Backup

Proper backup Openstack config files and Ceph config files, and this would save a lot of time in re-deployment.

On infra01 node:

    cd /etc/openstack_deploy
    tar cvf os-deploy-MM-DD-YY.tar .

On ceph/storage01 node

    cd /opt/rpc-ceph
    tar cvf ceph-MM-DD-YY.tar .

On deploy node

    cd
    scp infra01:/etc/openstack_deploy/os-deploy-MM-DD-YY.tar .
    scp storage01:/opt/rpc-ceph/ceph-MM-DD-YY.tar .

# Rekick the Eureka lab

On deploy node:

    ansible-playbook -i /etc/ansible/cobbler_hosts /root/rekick_eureka.yml

Check if all hosts are ready:

    ansible all -i /etc/ansible/cobbler_hosts -m ping

# Prepare the lab

On deploy node, truncate `known_hosts` file:
        
    echo '' > ~/.ssh/known_hosts

On deploy node, copy backup files to infra01 and storage01 node:

    scp os-deploy-MM-DD-YY.tar infra01:~/
    scp ceph-MM-DD-YY.tar storage01:~/

On deploy node, copy ssh keys and hosts files to infra01 and storage01 node:

    scp ~/.ssh/id_rsa infra01:~/.ssh/
    scp ~/.ssh/id_rsa.pub infra01:~/.ssh/
    scp ~/.ssh/id_rsa storage01:~/.ssh/
    scp ~/.ssh/id_rsa.pub storage01:~/.ssh/
    scp /etc/hosts infra01:/etc/
    scp /etc/hosts storage01:/etc/

On infra01 node, extract backup file:

    cd
    mkdir -p ./openstack_deploy
    tar xvf os-deploy-MM-DD-YY.tar -C ~/openstack_deploy

On storage01 node, extract backup file

    cd
    mkdir -p ./rpc-ceph
    tar xvf ceph-MM-DD-YY.tar -C ~/rpc-ceph

# RPC Openstack deployment

On infra01 node, clone down RPC-O

    git clone -b master https://github.com/rcbops/rpc-openstack.git /opt/rpc-openstack 

On infra01 node, check `pyyaml` if it doesn't exist, install it.

    pip install pyyaml

Start bootstrap, this will generate `/etc/openstack_deploy directory` and default configs. 

    /opt/rpc-openstack/scripts/deploy.sh

Replace configs in `/etc/openstack_deploy/` with backup files

    cp ~/openstack_deploy/user_osa_variables_overrides.yml /etc/openstack_deploy/
    cp ~/openstack_deploy/openstack_user_config.yml /etc/openstack_deploy/
    cp ~/openstack_deploy/env.d/cinder.yml /etc/openstack_deploy/env.d/
    cp ~/openstack_deploy/env.d/ceph.yml /etc/openstack_deploy/env.d/
    cp /opt/rpc-openstack/etc/openstack_deploy/user_rpco_secrets.yml.example /etc/openstack_deploy/user_rpco_secrets.yml

Generate user secrets (passwords)

    python /opt/openstack-ansible/scripts/pw-token-gen.py --file /etc/openstack_deploy/user_rpco_secrets.yml
    python /opt/openstack-ansible/scripts/pw-token-gen.py --file /etc/openstack_deploy/user_secrets.yml

Ceph deployment would start here, Openstack deployment will continue after Ceph done.

# RPC Ceph deployment

Clone down rpc-ceph

   git clone https://github.com/rcbops/rpc-ceph.git /opt/rpc-ceph 

On storage01 node, copy backup config file to ceph directory

    cp ~/rpc-ceph/vars.yml /opt/rpc-ceph/vars.yml
    cp ~/rpc-ceph/inventory.yml /opt/rpc-ceph/inventory.yml

Find and copy down `keystone_auth_admin_password` on infra01 node `/etc/openstack_deploy/user_secrets.yml`

    keystone_auth_admin_password: <SECRET> 

Then replace `radosgw_keystone_admin_password` in storage01 node /opt/rpc-ceph/vars.yml with it

Boostrap ansible

    /opt/rpc-ceph/scripts/bootstrap-ansible.sh

Deploy ceph

    cd /opt/rpc-ceph
    ceph-ansible-playbook -i inventory.yml playbooks/deploy-ceph.yml -e @vars.yml

If you met disk prepartion error, zapping disk is needed.

Prepare disk/device for ceph.

    umount -l /dev/sdc
    umount -l /dev/sdd
    umount -l /dev/sde
    umount -l /dev/sdf
    umount -l /dev/sdc1
    umount -l /dev/sdd1
    umount -l /dev/sde1
    umount -l /dev/sdf1
    ceph-disk zap /dev/sdc
    ceph-disk zap /dev/sdd
    ceph-disk zap /dev/sde
    ceph-disk zap /dev/sdf

Then re-run deployment of ceph.

# RPC Openstack deploy cont.

Continue setting up openstack on infra01 node

    cd /opt/openstack-ansible/playbooks/
    openstack-ansible setup-hosts.yml
    openstack-ansible setup-infrastructure.yml
    openstack-ansible os-keystone-install.yml

Create and run ceph-rgw-install.yml, which will setup rados gate service endpoints.  (Script: https://gist.github.com/Frank-ZhangXin/c7c8f5c2be96c30105821eb05db2d24f)

    openstack-ansible ceph-rgw-intall.yml

Set `rgw_keystone_admin_tenant` and `rgw_keystone_admin_user` with correct value in `/etc/ceph/ceph.conf` on storage01 node

    rgw_keystone_admin_tenant = admin
    rgw_keystone_admin_user = admin

On storage01 node, create a glance radosgw user in ceph
(https://github.com/rcbops/rpc-eng-ops/blob/master/docs/source/deployment_plan/rpc_openstack_manual_install.rst#set-up-the-glance-radosgw-user-in-ceph)
You will need `ironic_swift_temp_url_secret_key` and `glance_service_password` which is in `user_secrets.yml` on infra01 node `/etc/openstack_deploy`

Continue Openstack installation on infra01 node

    cd /opt/openstack-ansible/playbooks
    openstack-ansible setup-openstack.yml
    cd /opt/rpc-openstack/playbooks
    openstack-ansible site-openstack.yml

## Known issues with misconfiguration
#### Swift status is 401 error
Check 'swft stat' on uitlity container. 

    swift stat

If '401' error appeared. We need solving variable matching problem on storage01 node. On storage01 node, make sure `rgw_keystone_url` in `/etc/ceph/ceph.conf` and `internal_lb_vip_address` in `/opt/rpc-ceph/vars.yml` are same.

#### Keeplived no response
If meet 'keeplived' doesn't respond, keeplived process might die with miss-configed IP address. The cause could be keeplived was given an used IP address that conflicts other services. On infra01 node, maker sure `internal_lb_vip_address` and `external_lb_vip_address` are not given conflicted IPs in infra01 `/etc/openstack_deploy/openstack_user_config.yml`. Check `haproxy_keepalived_internal_vip_cidr` and `haproxy_keepalived_external_vip_cidr` in `/etc/openstack_deploy/user_osa_variables_overrides.yml` if matching to `internal_lb_vip_address` and `external_lb_vip_address` in `/etc/openstack_deploy/openstack_user_config.yml`.
