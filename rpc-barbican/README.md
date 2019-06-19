# Deploy Barbican (Key manager) service on RPC Openstack
 
Before deploying Barbican, make you've already had fully deployed RPC Openstack. Details about this please see `https://github.com/rcbops/rpc-integration/tree/master/rpc-openstack`

## Prepare host config for Barbican

```sh
cp /opt/openstack-ansible/etc/openstack_deploy/conf.d/barbican.yml.example /etc/openstack_deploy/conf.d/barbican.yml
```
Then replace the IPs with the actually infra hosts.

```sh
cd /opt/openstack-ansible/playbooks/
openstack-ansible setup-hosts.yml --limit hosts:barbican_all
```

## Deploy Barbican service

```sh
# create overrides if not exists
touch /etc/openstack_deploy/user_osa_variables_overrides.yml
echo "barbican_galera_address: "{{ internal_lb_vip_address }}"
barbican_keystone_auth: yes
barbican_venv_tag: testing
keystone_admin_user_name: admin
keystone_admin_tenant_name: admin" >> /etc/openstack_deploy/user_osa_variables_overrides.yml
cd /opt/openstack-ansible/playbooks/
openstack-ansible repo-build.yml
openstack-ansible os-barbican-install.yml
openstack-ansible haproxy-install.yml
```

And Barbican should be good to go. You can log into utility container and source openrc file, then use "openstack secret" CLI to verify it.

## Reference
Openstack Barbican Key Manger service: `https://docs.openstack.org/barbican/latest/`
OSA Barbican role: `https://docs.openstack.org/openstack-ansible-os_barbican/latest/`
