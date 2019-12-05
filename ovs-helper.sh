#!/bin/sh

# The name of the physical wired interface (host specific)
wired_iface=enp5s0

# The IP address assigned (by the DHCP server) to the physical wired interface (host specific)
wired_iface_ip=192.168.1.206

# The name of the OVS bridge to create
ovs_bridge=br0

#==================================================================================================================
#
#==================================================================================================================
ovs_show_menu()
{
  # Display current hardcoded configuration 
  echo
  echo "Current configuration (currently hardcoded)"
  echo "Wired interface:            [$wired_iface]"
  echo "Wired interface IP address: [$wired_iface_ip]"
  echo "Manually update these values in this file according to your network configuration"
  echo
  echo
  # Display some helpers to the user
  echo "Main commands"
  echo "=========================================================================================================================="
  echo "\"ovs_show_menu\"                     - Displays this menu"
  echo "\"ovs_start_test\"                    - Starts OVS daemons, deploys network configuration and configures QoS"
  echo "\"ovs_stop_test\"                     - Purges network configuration, QoS, restores wired interface and stops OVS daemons"
  echo
  echo "Network deployment and QoS configuration commands"
  echo "=========================================================================================================================="
  echo "\"ovs_deploy_network\"                - Deploys network configuration"
  echo "\"ovs_set_qos\"                       - Configures QoS"
  echo "\"ovs_vm_set_qos\"                    - Configures QoS for specific vm3 (vm attached to tap_port3)"
  echo "\"ovs_vm_set_qos_netem_latency\"      - Configure latency (netem) on specified port"
  echo "                                      ex: ovs_vm_set_qos_netem_latency tap_port3 2000000"
  echo "\"ovs_vm_set_qos_netem_packet_loss\"  - Configure packet loss as a percentage (netem) on specified port"
  echo "                                      ex: ovs_vm_set_qos_netem_packet_loss tap_port3 10"
  echo "\"ovs_purge_network\"                 - Purge deployed network (and QoS)"
  echo
  echo "Project build/install related commands"
  echo "=========================================================================================================================="
  echo "\"ovs_install\"                       - Builds and installs OVS daemons and kernel modules"
  echo "\"ovs_configure_debug_build\"         - Configures OVS project for debug build"
  echo "\"ovs_configure_release_build\"       - Configures OVS project for release build"
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_override_kernel_modules()
{
  config_file="/etc/depmod.d/openvswitch.conf"

  echo "Updating configuration file: [$config_file]..."

  for module in datapath/linux/*.ko; do
    modname="$(basename ${module})"
  
    echo "Appending module: [$modname]..."

    echo "override ${modname%.ko} * extra" >> "$config_file"
    echo "override ${modname%.ko} * weak-updates" >> "$config_file"
  done

  echo "Generating list of kernel module dependencies..."

  sudo depmod -a -v -w
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_update_openvswitch_module()
{
  local module="openvswitch.ko"
  local replacement_module="/lib/modules/5.0.0-rc8/extra/openvswitch.ko"

  echo "Unloading module: [$module]..."
  sudo rmmod $module
  
  echo "Loading module: [$replacement_module]..."
  sudo insmod $replacement_module

  sudo modinfo $replacement_module
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
ovs_bridge_del_port()
{
  local port="$1"
  local bridge="$2"

  # Delete tap device/interface to "br0" bridge
  ovs-vsctl del-port $bridge $port
  
  # Delete tap port
  ip tuntap del mode tap $port

  # Deactivate device/interface 
  ip link set $port down
  
  echo "Deleted tap port/interface: [$port] from ovs bridge: [$bridge]"
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
  
  echo "Deploying testbed network..."

  # Update path with ovs scripts path.
  export PATH=$PATH:/usr/local/share/openvswitch/scripts

  # Starts "ovs-vswitchd:" and "ovsdb-server" daemons
  ovs-ctl start --delete-bridges

  # create new bridge named "br0"
  ovs-vsctl add-br $ovs_bridge
  
  # Activate "br0" device 
  ip link set $ovs_bridge up

  # Add network device "enp5s0" to "br0" bridge. Device "enp5s0" is the
  # name of the actual physical wired network interface. In some devices
  # it may be eth0.
  ovs-vsctl add-port $ovs_bridge $wired_iface
  
  # Delete assigned ip address from "enp5s0" device/interface. This address 
  # was provided (served) by the DHCP server (in the local network).
  # For simplicity, I configured my verizon router to always assign this
  # ip address (192.168.1.206) to "this" host (i.e. the host where I am 
  # deploying ovs).
  ip addr del $wired_iface_ip/24 dev $wired_iface

  # Acquire ip address and assign it to the "br0" bridge/interface
  dhclient $ovs_bridge

  # Create a tap interface for VM1 (and add interface to "br0" bridge).
  ovs_bridge_add_port tap_port1 $ovs_bridge

  # Create a tap interface for VM2 (and add interface to "br0" bridge).
  ovs_bridge_add_port tap_port2 $ovs_bridge

  # Create a tap interface for VM3 (and add interface to "br0" bridge).
  ovs_bridge_add_port tap_port3 $ovs_bridge
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
  ovs-vsctl del-br $ovs_bridge
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_run_test()
{
  # These commands are executed as "root" user (for now)
  
  export PATH=$PATH:/usr/local/share/openvswitch/scripts

  ip addr del $wired_iface_ip/24 dev $wired_iface
  
  ovs-ctl start

  dhclient $ovs_bridge
}

#==================================================================================================================
#
#==================================================================================================================
ovs_test_tc()
{
  # These commands are executed as "root" user (for now)

  export PATH=$PATH:/usr/local/share/openvswitch/scripts

  ovs-ctl start

  ovs-vsctl add-br $ovs_bridge

  # tap port for VM1
  ovs_bridge_add_port tap_port1 $ovs_bridge
}

#==================================================================================================================
#
#==================================================================================================================
ovs_set_qos()
{
  # Configure traffic shaping
  ovs_traffic_shape

  # Configure traffic flows
  ovs_configure_traffic_flows
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
  set port $wired_iface qos=@newqos -- \
  --id=@newqos create qos type=linux-htb \
      other-config:max-rate=1000000000 \
      queues:123=@tap_port1_queue \
      queues:234=@tap_port2_queue -- \
  --id=@tap_port1_queue create queue other-config:max-rate=10000000 -- \
  --id=@tap_port2_queue create queue other-config:max-rate=20000000
}

#==================================================================================================================
#
#==================================================================================================================
ovs_configure_traffic_flows()
{
  # Use OpenFlow to direct packets from tap_port1, tap_port2 to their respective 
  # (traffic shaping) queues (reserved for them in "ovs_traffic_shape").
  ovs-ofctl add-flow $ovs_bridge in_port=5,actions=set_queue:123,normal
  ovs-ofctl add-flow $ovs_bridge in_port=6,actions=set_queue:234,normal
}

#==================================================================================================================
#
#==================================================================================================================
ovs_vm_set_qos()
{
  # Configure traffic shaping for interfaces (to be) used by VM1 and VM2.
  # The max bandwidth allowed for VM1 will be 10Mbits/sec,
  # the max bandwidth allowed for VM2 will be 20Mbits/sec.
  # VM3 is used as the baseline, so no traffic shaping is applied to
  # this VM.
  ovs-vsctl -- \
  set interface tap_port3 ofport_request=7 -- \
  set port $wired_iface qos=@newqos -- \
  --id=@newqos create qos type=linux-htb \
      other-config:max-rate=1000000000 \
      queues:122=@tap_port3_queue -- \
  --id=@tap_port3_queue create queue other-config:max-rate=10000
  
  ovs-ofctl add-flow $ovs_bridge in_port=7,actions=set_queue:122,normal
}

#==================================================================================================================
#
#==================================================================================================================
ovs_vm_set_qos_netem_latency()
{
  local tap_port=$1
  local latency=$2

  # Configure (netem latency) traffic shaping on interface.
  
  echo "Setting latency: [$latency] in port: [$tap_port]"
  
  ovs-vsctl -- \
  set interface $tap_port ofport_request=7 -- \
  set port $wired_iface qos=@qos_netem_latency -- \
  --id=@qos_netem_latency create qos type=linux-netem \
      other-config:latency=$latency \
      queues:122=@$tap_port_queue -- \
  --id=@$tap_port_queue create queue other-config:latency=$latency

  ovs-ofctl add-flow $ovs_bridge in_port=7,actions=set_queue:122,normal
}

#==================================================================================================================
#
#==================================================================================================================
ovs_vm_set_qos_netem_packet_loss()
{
  local tap_port=$1
  local packet_loss=$2

  # Configure (netem packet loss) traffic shaping on interface.
  
  echo "Setting packet loss: [$packet_loss%] in port: [$tap_port]"
  
  ovs-vsctl -- \
  set interface $tap_port ofport_request=7 -- \
  set port $wired_iface qos=@qos_netem_pkt_loss -- \
  --id=@qos_netem_pkt_loss create qos type=linux-netem \
      other-config:loss=$packet_loss \
      queues:122=@$tap_port_queue -- \
  --id=@$tap_port_queue create queue other-config:loss=$packet_loss

  ovs-ofctl add-flow $ovs_bridge in_port=7,actions=set_queue:122,normal
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_purge_network()
{
  # These commands are executed as "root" user (for now)
  
  echo "Purging testbed network..."

  # Update path with ovs scripts path.
  export PATH=$PATH:/usr/local/share/openvswitch/scripts

  # Delete tap port tap_port3 from ovs bridge
  ovs_bridge_del_port tap_port3 $ovs_bridge

  # Delete tap port tap_port2 from ovs bridge
  ovs_bridge_del_port tap_port2 $ovs_bridge
  
  # Delete tap port tap_port1 from ovs bridge
  ovs_bridge_del_port tap_port1 $ovs_bridge
  
  # Delete physical wired port from ovs bridge
  ovs-vsctl del-port $ovs_bridge $wired_iface
  
  # Deactivate "br0" device 
  ip link set $ovs_bridge down
  
  # Delete bridge named "br0" from ovs
  ovs-vsctl del-br $ovs_bridge

  # Bring up physical wired interface
  ip link set $wired_iface up

  # Acquire ip address and assign it to the physical wired interface
  dhclient $wired_iface
}

#==================================================================================================================
#
#==================================================================================================================
ovs_start_test()
{
  ovs_deploy_network
  ovs_set_qos
}

#==================================================================================================================
#
#==================================================================================================================
ovs_stop_test()
{
  ovs_purge_network
  ovs_stop
}

#==================================================================================================================
#
#==================================================================================================================
ovs_configure_debug_build()
{
  make clean
  ./configure CFLAGS="-g -O0 -fsanitize=address -fno-omit-frame-pointer -fno-common" --with-linux=/lib/modules/$(uname -r)/build
}

#==================================================================================================================
#
#==================================================================================================================
ovs_configure_release_build()
{
  make clean
  ./configure --with-linux=/lib/modules/$(uname -r)/build
}

#==================================================================================================================
#
#==================================================================================================================
ovs_install()
{
  make
  sudo make install
  sudo make modules_install
}

# Display ovs helper "menu"
ovs_show_menu
