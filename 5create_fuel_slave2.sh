#!/bin/bash

export LANG=C
source config

# delete old slave
nova delete ${FUEL_SLAVE_NAME}-2
while nova show ${FUEL_SLAVE_NAME}-2 &>/dev/null; do
 echo "Wait for delete"
 sleep 1
done

# create new volume
delete_volume ${FUEL_SLAVE_NAME}-2
create_volume ${FUEL_SLAVE_NAME}-2 80
VOL_TEST_ID=$(nova volume-show ${FUEL_SLAVE_NAME}-2|grep " id "|awk '{print $4}')
# set bootable to new volume
cinder set-bootable ${VOL_TEST_ID} True

neutron port-delete ${FUEL_SLAVE_NAME}-2-admin
P1_ID=$(neutron port-create --tenant-id ${TID} \
 --fixed-ip subnet_id=${NET_ADMIN_NAME}-subnet,ip_address=10.20.0.4 \
 --name ${FUEL_SLAVE_NAME}-2-admin \
 --mac-address aa:0a:14:00:04:01 \
 ${NET_ADMIN_NAME}-net|grep " id "|awk '{print $4}')

neutron port-delete ${FUEL_SLAVE_NAME}-2-public
P2_ID=$(neutron port-create --tenant-id ${TID} \
 --fixed-ip subnet_id=${NET_PUBLIC_NAME}-subnet,ip_address=172.16.0.4 \
 --name ${FUEL_SLAVE_NAME}-2-public \
 --mac-address aa:ac:10:00:04:01 \
 ${NET_PUBLIC_NAME}-net|grep " id "|awk '{print $4}')

neutron port-delete ${FUEL_SLAVE_NAME}-2-storage
P3_ID=$(neutron port-create --tenant-id ${TID} \
 --fixed-ip subnet_id=${NET_STORAGE_NAME}-subnet \
 --name ${FUEL_SLAVE_NAME}-2-storage \
 --mac-address aa:0a:14:00:04:03 \
 ${NET_STORAGE_NAME}-net|grep " id "|awk '{print $4}')

neutron port-delete ${FUEL_SLAVE_NAME}-2-mgmt
P4_ID=$(neutron port-create --tenant-id ${TID} \
 --fixed-ip subnet_id=${NET_MGMT_NAME}-subnet \
 --name ${FUEL_SLAVE_NAME}-2-mgmt \
 --mac-address aa:0a:14:00:04:04 \
 ${NET_MGMT_NAME}-net|grep " id "|awk '{print $4}')

CDROM_ID=$(nova image-show ipxe|grep " id "|awk '{print $4}')
nova volume-delete ${FUEL_SLAVE_NAME}-2-ipxe
while nova volume-show ${FUEL_SLAVE_NAME}-2-ipxe &>/dev/null; do
 echo "Wait for delete"
 sleep 1
done
nova volume-create --image-id ${CDROM_ID} --display-name ${FUEL_SLAVE_NAME}-2-ipxe 1
while [[ ! $(nova volume-show ${FUEL_SLAVE_NAME}-2-ipxe| grep " status " | awk '{print $4}') == 'available' ]] &>/dev/null; do
 echo "Wait for create"
 sleep 1
done
VOL_ISO_ID=$(nova volume-show ${FUEL_SLAVE_NAME}-2-ipxe|grep " id "|awk '{print $4}')
while [[ ! $(nova volume-show ${FUEL_SLAVE_NAME}-2-ipxe| grep " status " | awk '{print $4}') == 'available' ]] &>/dev/null; do
 echo "Wait for create"
 sleep 1
done


nova boot --flavor fuel-slave \
 --nic port-id=${P1_ID} \
 --nic port-id=${P2_ID} \
 --nic port-id=${P3_ID} \
 --nic port-id=${P4_ID} \
 --block-device id=${VOL_ISO_ID},source=volume,dest=volume,bus=ide,device=/dev/vdb,size=5,type=cdrom,bootindex=0 \
 --block-device id=${VOL_TEST_ID},source=volume,dest=volume,device=/dev/vda,size=80,bootindex=1 \
 ${FUEL_SLAVE_NAME}-2
# --security-groups full \
while [[ ! $(nova show ${FUEL_SLAVE_NAME}-2| grep " status " | awk '{print $4}') == 'ACTIVE' ]] &>/dev/null; do
 echo "Wait for create"
 sleep 1
done

#neutron port-update ${FUEL_SLAVE_NAME}-2-admin \
# --allowed-address-pairs type=dict list=true mac_address=aa:0a:14:00:04:01,ip_address=10.20.0.0/24
# --security-group full
#neutron port-update ${FUEL_SLAVE_NAME}-2-public \
# --allowed-address-pairs type=dict list=true mac_address=aa:ac:10:00:04:01,ip_address=0.0.0.0/0
# --security-group full
