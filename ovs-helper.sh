#!/bin/sh

echo "Use \"ovs_deploy_network\" to deploy network configuration"

#==================================================================================================================
# 
#==================================================================================================================
ovs_override_kernel_modules()
{
  config_file="/etc/depmod.d/openvswitch.conf"

  for module in datapath/linux/*.ko; do
    modname="$(basename ${module})"
    echo "override ${modname%.ko} * extra" >> "$config_file"
    echo "override ${modname%.ko} * weak-updates" >> "$config_file"
  done
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_config_db()
{
  mkdir -p /usr/local/etc/openvswitch
  ovsdb-tool create /usr/local/etc/openvswitch/conf.db vswitchd/vswitch.ovsschema
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_start_db_server()
{
  mkdir -p /usr/local/var/run/openvswitch

  ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
    --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
    --private-key=db:Open_vSwitch,SSL,private_key \
    --certificate=db:Open_vSwitch,SSL,certificate \
    --bootstrap-ca-cert=db:Open_vSwitch,SSL,ca_cert \
    --pidfile --detach --log-file
}

#==================================================================================================================
#
#==================================================================================================================
ovs_bridge_add_port()
{
  local port="$1"
  local bridge="$2"

  # Create tap (layer 2) device/interface
  ip tuntap add mode tap $port

  # Activate device/interface 
  ip link set $port up

  # Add tap device/interface to "br0" bridge
  ovs-vsctl add-port $bridge $port
  
  echo "Added tap port/interface: [$port] to ovs bridge: [$bridge]"
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_start()
{
  # These commands are executed as "root" user (for now)
  
  export PATH=$PATH:/usr/local/share/openvswitch/scripts
  
  ovs-ctl start
}

#==================================================================================================================
#
#==================================================================================================================
ovs_stop()
{
  # These commands are executed as "root" user (for now)

  export PATH=$PATH:/usr/local/share/openvswitch/scripts

  ovs-ctl stop
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_deploy_network()
{
  # These commands are executed as "root" user (for now)
  
  # Update path with ovs scripts path.
  export PATH=$PATH:/usr/local/share/openvswitch/scripts

  # Starts "ovs-vswitchd:" and "ovsdb-server" daemons
  ovs-ctl start

  # create new bridge named "br0"
  ovs-vsctl add-br br0
  
  # Activate "br0" device 
  ip link set br0 up

  # Add network device "enp5s0" to "br0" bridge. Device "enp5s0" is the
  # name of the actual physical wired network interface. In some devices
  # it may be eth0.
  ovs-vsctl add-port br0 enp5s0
  
  # Delete assigned ip address from "enp5s0" device/interface. This address 
  # was provided (served) by the DHCP server (in the local network).
  # For simplicity, I configured my verizon router to always assign this
  # ip address (192.168.1.206) to "this" host (i.e. the host where I am 
  # deploying ovs).
  ip addr del 192.168.1.206/24 dev enp5s0

  # Acquire ip address and assign it to the "br0" bridge/interface
  dhclient br0

  # Create a tap interface for VM1 (and add interface to "br0" bridge).
  ovs_bridge_add_port tap_port1 br0

  # Create a tap interface for VM2 (and add interface to "br0" bridge).
  ovs_bridge_add_port tap_port2 br0

  # Create a tap interface for VM3 (and add interface to "br0" bridge).
  ovs_bridge_add_port tap_port3 br0
}

#==================================================================================================================
#
#==================================================================================================================
ovs_purge_network_deployment()
{
  # Update path with ovs scripts path.
  export PATH=$PATH:/usr/local/share/openvswitch/scripts

  # "Manually" delete port/interfaces and bridge created via "ovs_deploy_network"
  # Note: it is possible to purge all bridge, etc configuration when starting
  # daemons via command line options (need to try this...).
  ovs-vsctl del-port tap_port1
  ovs-vsctl del-port tap_port2
  ovs-vsctl del-port tap_port3
  ovs-vsctl del-br br0
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_run_test()
{
  # These commands are executed as "root" user (for now)
  
  export PATH=$PATH:/usr/local/share/openvswitch/scripts

  ip addr del 192.168.1.206/24 dev enp5s0
  
  ovs-ctl start

  dhclient br0
}

#==================================================================================================================
#
#==================================================================================================================
ovs_test_tc()
{
  # These commands are executed as "root" user (for now)

  export PATH=$PATH:/usr/local/share/openvswitch/scripts

  ovs-ctl start

  ovs-vsctl add-br br0

  # tap port for VM1
  ovs_bridge_add_port tap_port1 br0
}

#==================================================================================================================
#
#==================================================================================================================
ovs_traffic_shape()
{
  # Configure traffic shaping for interfaces (to be) used by VM1 and VM2.
  # The max bandwidth allowed for VM1 will be 10Mbits/sec,
  # the max bandwidth allowed for VM2 will be 20Mbits/sec.
  # VM3 is used as the baseline, so no traffic shaping is applied to
  # this VM.
  ovs-vsctl -- \
  set interface tap_port1 ofport_request=5 -- \
  set interface tap_port2 ofport_request=6 -- \
  set port enp5s0 qos=@newqos -- \
  --id=@newqos create qos type=linux-htb \
      other-config:max-rate=1000000000 \
      queues:123=@tap_port1_queue \
      queues:234=@tap_port2_queue -- \
  --id=@tap_port1_queue create queue other-config:max-rate=10000000 -- \
  --id=@tap_port2_queue create queue other-config:max-rate=20000000
}
