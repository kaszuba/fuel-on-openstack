Fuel as Openstack instance
==========================

This is draft version of scripts used to install Fuel in Openstack and use
it to deploy cloud as openstack instances.

**WORK IN PROGRESS, it is not final, fully worked solution!!**

This script was used to deploy Fuel 6.1 (Openstack Juno) on Openstack deployed
by Fuel 6.0. Underlying Openstack configuration uses HW nodes:

- one controler node
- 5 compute nodes
- Neutron with GRE segmentation

Underlying installation was changed manually to make Fuel work, we need to
allow send DHCP responses from Openstack instance. In standard installation
firewall rules created by Neutron agent will not allow to do this.

We need to remove DROP rule from instance which is used for Fuel master, it
will allow to run dhcp on it. It is possible by executing on compute node:

.. code::

  iptables -D neutron-openvswi-oc439e856-3 -p udp --sport 67 --dport 68 -j DROP

You can also change it permanently for all instance in file
/usr/lib/python2.7/dist-packages/neutron/agent/linux/iptables_firewall.py
line 332

Known problems
==============

VLAN segmentation
~~~~~~~~~~~~~~~~~

Cloud deployed inside other Openstack cannot use VLAN segmentation, at least
when we use openvswitch in underlying cloud. This should work when we use flat
network with linux bridges and deploy all cloud nodes on one hardware server.
It should also work with some functionality like Q-in-Q enabled on openvswitch
or other solution used in Neutron.

**VLAN Problem description**

In standard installations networks could be attached directly to interface or
created as a VLAN on network interface. We want to minimalise problems with
tagging/fragmentation and each of network was created as a separate
neutron network with dedicated interface inside instance.

This requires to create infrastructure with:

- router connected to external network
- 4 neutron networks
- public and admin network connected to router

Network connections between openstack instances:

.. code::

              +---------+
              | Neutron |   +~~~~~~~~+
       +------| router  |---|Internet|
       |      +---------+   +~~~~~~~~+
       |           |
  +---------+ +---------+ +---------+ +---------+
  | Neutron | | Neutron | | Neutron | | Neutron |
  | network | | network | | network | | network |
  |  admin  | | public  | | mgmt    | | storage |
  +---------+ +---------+ +---------+ +---------+
     |     |           |       |          |
     |     +--------+  |       |          |
     |              |  |       |          |
  +-----------+    +------------------------+
  |Fuel Master|    |    Fuel slave X        |
  +-----------+    +------------------------+


Fuel installation with 2 nodes ready for deployment:

.. code::

  +------------------------------------------------------+
  | Hardware node                                        |
  |                 +------------------------+           |
  |                 |    Fuel slave 1        |           |
  |                 |   (KVM Instance)       |           |
  |                 +------------------------+           |
  |                   |  |       |          |            |
  |          +--------+  |       |          |            |
  |          |           |       |          |            |
  | +---------+ +---------+ +---------+ +---------+      |
  | | Neutron | | Neutron | | Neutron | | Neutron |      |
  | | network | | network | | network | | network |      |
  | |  admin  | | public  | | mgmt    | | storage |      |
  | |  (OVS)  | |  (OVS)  | |  (OVS)  | |  (OVS)  |      |
  | +---------+ +---------+ +---------+ +---------+      |
  |    |     |           |       |          |            |
  |    |     +--------+  |       |          |            |
  |    |              |  |       |          |            |
  | +-----------+    +------------------------+          |
  | |Fuel Master|    |    Fuel slave 2        |          |
  | |   (KVM)   |    |   (KVM Instance)       |          |
  | +-----------+    +------------------------+          |
  |                                                      |
  +------------------------------------------------------+

Openstack deployed inside other Openstack with VLAN separation:

.. code::

  +------------------------------------------------------+
  | Hardware node                                        |
  |   +---------------------------------------+          |
  |   |    Fuel slave 1  +------------------+ |          |
  |   |   (KVM Instance) |Openstack Instance| |          |
  |   |                  |       TEST1      | |          |
  |   |                  |       (KVM)      | |          |
  |   |                  +------------------+ |          |
  |   |                            |          |          |
  |   |                      +----------+     |          |
  |   |                      |    OVS   |     |          |
  |   |                      |   (VLAN) |     |          |
  |   |                      +----------+     |          |
  |   |                            |tag:1000  |          |
  |   +---------------------------ETH---------+          |
  |                                |                     |
  |                          +----------+                |
  |                          |    OVS   |                |
  |                          |   (GRE)  |                |
  |                          +----------+                |
  |                                |                     |
  |   +---------------------------ETH---------+          |
  |   |   Fuel slave 2             |tag:1000  |          |
  |   |  (KVM Instance)      +----------+     |          |
  |   |                      |    OVS   |     |          |
  |   |                      |   (VLAN) |     |          |
  |   |                      +----------+     |          |
  |   |                            |          |          |
  |   |                  +------------------+ |          |
  |   |                  |Openstack Instance| |          |
  |   |                  |       TEST2      | |          |
  |   |                  |       (KVM)      | |          |
  |   |                  +------------------+ |          |
  |   +---------------------------------------+          |
  |                                                      |
  +------------------------------------------------------+

Problem appears when we want to send packets between instances TEST1 and TEST2
on two different slaves:

- packet sended from TEST1 to TEST2
- OVS inside Fuel slave 1 needs to send this packet to other compute node,
  then will add VLAN tag and send it by network interface
- OVS on hardware node will get tagged frame on interface which is not
  configured for tagging with default configuration this packet will be dropped
