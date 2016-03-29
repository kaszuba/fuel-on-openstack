#!/bin/bash

export LANG=C
source config

VOL_ID=$(nova volume-show ${FUEL_MASTER_NAME}|grep " id "|awk '{print $4}')
N_ID=$(neutron net-list |grep " ${NET_ADMIN_NAME}-net "|awk '{print $2}')

nova delete ${FUEL_MASTER_NAME}
while nova show ${FUEL_MASTER_NAME} &>/dev/null; do
 echo "Wait for delete"
 sleep 1
done

neutron port-delete ${FUEL_MASTER_NAME}-admin
P_ID=$(neutron port-create --tenant-id ${TID} \
 --fixed-ip subnet_id=${NET_ADMIN_NAME}-subnet,ip_address=10.20.0.2 \
 --name ${FUEL_MASTER_NAME}-admin \
 --mac-address aa:0a:14:00:02:01 \
 ${NET_ADMIN_NAME}-net|grep " id "|awk '{print $4}')

# create new volume
delete_volume ${FUEL_MASTER_NAME}-stage1
delete_volume_snapshot ${FUEL_MASTER_NAME}-stage1
nova volume-snapshot-create --display-name ${FUEL_MASTER_NAME}-stage1 ${VOL_ID}
while [[ ! $(nova volume-snapshot-show ${FUEL_MASTER_NAME}-stage1| grep " status " | awk '{print $4}') == 'available' ]] &>/dev/null; do
 echo "Wait for create"
 sleep 1
done
VOL_SNAP_ID=$(nova volume-snapshot-show ${FUEL_MASTER_NAME}-stage1|grep " id "|awk '{print $4}')
# create volume
nova volume-create --display-name ${FUEL_MASTER_NAME}-stage1 --snapshot-id ${VOL_SNAP_ID} 80
while [[ ! $(nova volume-show ${FUEL_MASTER_NAME}-stage1| grep " status " | awk '{print $4}') == 'available' ]] &>/dev/null; do
 echo "Wait for create"
 sleep 1
done
VOL_TEST_ID=$(nova volume-show ${FUEL_MASTER_NAME}-stage1|grep " id "|awk '{print $4}')
# set bootable to new volume
cinder set-bootable ${VOL_TEST_ID} True

nova boot --flavor fuel-master \
 --nic port-id=${P_ID} \
 --block-device id=${VOL_TEST_ID},source=volume,dest=volume,device=/dev/vda,size=80,bootindex=0 \
 ${FUEL_MASTER_NAME}
while [[ ! $(nova show ${FUEL_MASTER_NAME}| grep " status " | awk '{print $4}') == 'ACTIVE' ]] &>/dev/null; do
 echo "Wait for create"
 sleep 1
done

nova floating-ip-associate ${FUEL_MASTER_NAME} ${FIP}
#neutron port-update ${FUEL_MASTER_NAME}-admin \
# --allowed-address-pairs type=dict list=true mac_address=aa:0a:14:00:02:01,ip_address=0.0.0.0/0

