#!/bin/sh

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

  ip tuntap add mode tap $port

  ip link set $port up

  ovs-vsctl add-port $bridge $port
  
  echo "Added tap port/interface: [$port] to ovs bridge: [$bridge]"
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_deploy_test()
{
  # These commands are executed as "root" user (for now)
  
  export PATH=$PATH:/usr/local/share/openvswitch/scripts

  ovs-ctl start

  ovs-vsctl add-br br0
  
  ip link set br0 up

  ovs-vsctl add-port br0 enp5s0
  
  ip addr del 192.168.1.206/24 dev enp5s0

  dhclient br0

  # tap port for VM1
  ovs_bridge_add_port tap_port1 br0

  # tap port for VM2
  ovs_bridge_add_port tap_port2 br0

  # tap port for VM3
  ovs_bridge_add_port tap_port3 br0
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


