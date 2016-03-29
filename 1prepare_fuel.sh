#!/bin/bash

# prepare clean openstack installation to work with deployment

source ~/openrc-admin.sh

# create test user
keystone tenant-create --name test --description "test"
keystone user-create --name test --pass test --tenant test

# create flavors
nova flavor-create fuel-master 100 2048 80 2
nova flavor-create fuel-slave 101 2548 5 2 --ephemeral 100

