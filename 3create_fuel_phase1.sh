#!/bin/bash

source config

# create volume for fuel
delete_volume ${FUEL_MASTER_NAME}
create_volume ${FUEL_MASTER_NAME} 80
VOL_ID=$(get_volume_id ${FUEL_MASTER_NAME})

neutron port-delete ${FUEL_MASTER_NAME}-admin
P_ID=$(neutron port-create --tenant-id ${TID} \
 --fixed-ip subnet_id=${NET_ADMIN_NAME}-subnet,ip_address=10.20.0.2 \
 --name ${FUEL_MASTER_NAME}-admin \
 --mac-address aa:0a:14:00:02:01 \
 ${NET_ADMIN_NAME}-net|grep " id "|awk '{print $4}')

# do not set bootable for main volume, there is a bug
# add bootable for snapshot
# https://bugs.launchpad.net/cinder/+bug/1413880

#CDROM_ID=$(nova volume-show fuel-cd|grep " id "|awk '{print $4}')
CDROM_ID=$(nova image-show fuel-6.1-432|grep " id "|awk '{print $4}')

# create volume from ISO
nova volume-show fuel-cd || nova volume-create --image-id ${CDROM_ID} --display-name fuel-cd 3
while [[ ! $(nova volume-show fuel-cd| grep " status " | awk '{print $4}') == 'available' ]] &>/dev/null; do
 echo "Wait for create"
 sleep 1
done
VOL_ISO_ID=$(nova volume-show fuel-cd|grep " id "|awk '{print $4}')

N_ID=$(neutron net-list |grep " ${NET_ADMIN_NAME}-net "|awk '{print $2}')

# --nic "net-id=${N_ID},v4-fixed-ip=10.20.0.2" \
nova boot --flavor fuel-master \
 --nic port-id=${P_ID} \
 --block-device id=${VOL_ISO_ID},source=volume,dest=volume,bus=ide,device=/dev/vdb,size=5,type=cdrom,bootindex=0 \
 --block-device id=${VOL_ID},source=volume,dest=volume,device=/dev/vda,size=80,bootindex=1 \
 ${FUEL_MASTER_NAME}
while [[ ! $(nova show ${FUEL_MASTER_NAME}| grep " status " | awk '{print $4}') == 'ACTIVE' ]] &>/dev/null; do
 echo "Wait for create"
 sleep 1
done

nova floating-ip-associate fuel-master $FIP
