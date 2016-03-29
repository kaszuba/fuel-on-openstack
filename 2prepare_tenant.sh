#!/bin/bash
#
# Prepare openstack installation to work with deployment
#

source config

# create router
neutron router-create --tenant-id $TID fuel-router
R_ID=$(neutron router-show fuel-router |grep " id "|awk '{print $4}')
N_EXT_ID=$(neutron net-list |grep " net04_ext "|awk '{print $2}')
neutron router-gateway-set ${R_ID} ${N_EXT_ID}

# create networks
create_os_net ${TID} ${NET_ADMIN_NAME} ${NET_ADMIN_CLASS} yes
create_os_net ${TID} ${NET_PUBLIC_NAME} ${NET_PUBLIC_CLASS} yes
create_os_net ${TID} ${NET_MGMT_NAME} ${NET_MGMT_CLASS} no
create_os_net ${TID} ${NET_STORAGE_NAME} ${NET_STORAGE_CLASS} no

# upload fuel iso
glance image-create \
 --disk-format iso \
 --container-format bare \
 --name "fuel-6.1-432" \
 --file /home/iso/fuel-6.1-432-2015-05-18_03-43-53.iso \
 --progress

# upload ipxe iso
# wget http://boot.ipxe.org/ipxe.iso
glance image-create \
 --disk-format iso \
 --container-format bare \
 --name "ipxe" \
 --file /home/iso/ipxe.iso \
 --progress

# reserve floating ip
#nova floating-ip-create

# for test allow full net
#nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
#nova secgroup-add-rule default tcp 1 65535 0.0.0.0/0
#nova secgroup-add-rule default udp 1 65535 0.0.0.0/0
