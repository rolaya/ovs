#!/bin/sh

# The name of the physical wired interface (host specific)
wired_iface=enp5s0

# The IP address assigned (by the DHCP server) to the physical wired interface (host specific)
wired_iface_ip=192.168.1.206

# The name of the OVS bridge to create
ovs_bridge=br0

# The number of VMs (and interfaces we are going to configure)
number_of_interfaces=3

# Degfault port name
port_name="tap_port"

# VirtualBox looks at this as the network name
network_name=$port_name

# For clarity, use number of VMs variable (it is the same as the number of ports/interfaces)
number_of_vms=$number_of_interfaces

# VM base name. The VMs names are something like "vm-debian9-net-node1"
vm_base_name="vm-debian9-net-node"

# This determines if we are going to use DHCP or static IP addresses
# Change to True to use DHCP.
use_dhcp="False"

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
  
  # Environment provisioning
  echo "Provisioning commands"
  echo "\"ovs_provision_for_build\"           - Provision system for building ovs"
  
  # Display some helpers to the user
  echo "Main commands"
  echo "=========================================================================================================================="
  echo "\"ovs_show_menu\"                     - Displays this menu"
  echo "\"ovs_start_test\"                    - Starts OVS daemons, deploys network configuration and configures QoS"
  echo "\"ovs_stop_test\"                     - Purges network configuration, QoS, restores wired interface and stops OVS daemons"
  echo "\"vms_start\"                         - Start all VMs in the testbed"
  echo "\"vms_stop\"                          - Stop all VMs in the testbed"

  echo

  echo "\"ovs_bridge_add\"                    - Add bridge to system"
  echo "\"ovs_bridge_add_ports\"              - Add ports to bridge"
  echo "\"ovs_bridge_del\"                    - Delete bridge to system"
  echo "\"ovs_bridge_del_ports\"              - Delete ports from bridge"

  # Hypervisor commands
  echo "Hypervisor commands"
  echo "=========================================================================================================================="
  echo "\"vm_set_network_interface\"          - Set VM's NIC \"network\" (this is an existing port in an OVS bridge)"
  echo "\"vm_network_configure\"              - Configure network"

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
  local command=""

  echo "Adding port: [$port] to bridge: [$bridge]"

  # Create tap (layer 2) device/interface
  command="ip tuntap add mode tap $port"
  echo "Executing: [$command]"
  $command

  # Activate device/interface 
  command="ip link set $port up"
  echo "Executing: [$command]"
  $command

  # Add tap device/interface to "br0" bridge
  command="ovs-vsctl add-port $bridge $port"
  echo "Executing: [$command]"
  $command
  
  echo "Added tap port/interface: [$port] to ovs bridge: [$bridge]"
}

#==================================================================================================================
#
#==================================================================================================================
ovs_bridge_del_port()
{
  local port="$1"
  local bridge="$2"
  local command=""

  echo "Deleting port: [$port] from bridge: [$bridge]"

  # Delete tap device/interface to "br0" bridge
  command="ovs-vsctl del-port $bridge $port"
  echo "Executing: [$command]"
  $command

  # Deactivate device/interface 
  command="ip link set $port down"
  echo "Executing: [$command]"
  $command

  # Delete tap port
  command="ip tuntap del mode tap $port"
  echo "Executing: [$command]"
  $command

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
ovs_bridge_add_ports()
{
  local bridge=$1
  local port=${2:-$port_name}
  
  echo "Adding ports to bridge $bridge..."

  # Create a tap interface(s) for VMs 1-6 (and add interface to "br0" bridge).
  for ((i = 1; i <= $number_of_interfaces; i++)) do
    ovs_bridge_add_port $port$i $bridge
  done
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_bridge_add()
{
  local bridge=$1
  local command=""

  # These commands are executed as "root" user (for now)
  
  echo "Adding bridge $bridge to system..."

  # Update path with ovs scripts path.
  export PATH=$PATH:/usr/local/share/openvswitch/scripts

  # create new bridge named "br0"
  command="ovs-vsctl add-br $bridge"
  echo "executing: [$command]..."
  $command
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

  # Using DHCP?
  if [[ "$use_dhcp" = "True" ]]; then
    # Acquire ip address and assign it to the "br0" bridge/interface
    dhclient $ovs_bridge
  fi

  # Create tap interface(s) for VMs 1-6 (and add interface to "br0" bridge).
  ovs_bridge_add_ports $ovs_bridge
}

#==================================================================================================================
#
#==================================================================================================================
ovs_purge_network_deployment()
{
  local port=${2:-$port_name}

  # Update path with ovs scripts path.
  export PATH=$PATH:/usr/local/share/openvswitch/scripts

  # "Manually" delete port/interfaces and bridge created via "ovs_deploy_network"
  # Note: it is possible to purge all bridge, etc configuration when starting
  # daemons via command line options (need to try this...).
  for ((i = 1; i <= $number_of_interfaces; i++)) do
    ovs-vsctl del-port $port$1
  done
  
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

  if [[ "$use_dhcp" = "True" ]]; then
    dhclient $ovs_bridge
  fi
}

#==================================================================================================================
#
#==================================================================================================================
ovs_test_tc()
{
  local port=${2:-$port_name}

  # These commands are executed as "root" user (for now)

  export PATH=$PATH:/usr/local/share/openvswitch/scripts

  ovs-ctl start

  ovs-vsctl add-br $ovs_bridge

  # tap port for VM1
  ovs_bridge_add_port $port1 $ovs_bridge
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
ovs_bridge_del_ports()
{
  local bridge=$1
  local port=${2:-$port_name}

  # These commands are executed as "root" user (for now)
  
  echo "Purging $number_of_interfaces ports from $bridge bridge..."

  for ((i = $number_of_interfaces; i > 0; i--)) do

    # Delete tap port tap_portx from ovs bridge
    ovs_bridge_del_port $port$i $bridge

  done
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

  # Remote ports from bridge
  ovs_bridge_del_ports $ovs_bridge

  # Delete physical wired port from ovs bridge
  ovs-vsctl del-port $ovs_bridge $wired_iface
  
  # Deactivate "br0" device 
  ip link set $ovs_bridge down
  
  # Delete bridge named "br0" from ovs
  ovs-vsctl del-br $ovs_bridge

  # Bring up physical wired interface
  ip link set $wired_iface up

  if [[ "$use_dhcp" = "True" ]]; then
    # Acquire ip address and assign it to the physical wired interface
    dhclient $wired_iface
  fi
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

#==================================================================================================================
#
#==================================================================================================================
ovs_provision_for_build()
{
  local command=""
  local linux_version=$(uname -r)

  command="sudo apt-get install git build-essential libtool autoconf pkg-config"
  echo "Executing: [$command]"
  $command

  command="sudo apt-get install libssl-dev gdb libcap-ng-dev linux-headers-$linux_version"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# rolaya: this function needs parameter handling improvements.
#==================================================================================================================
vm_set_network_interface()
{
  local command=""
  local vm_name=${1:-"vm_name_is_required"}
  local nic_number=${2:-"1"}
  local network=${3:-"net_name_is_required"}

  # Format the command to set the network interface to bridged and the bridged 
  # adapter to an appropriate "network" name (i.e. a port defined with OVS).
  # The command generated will be something like: 
  # "VBoxManage modifyvm vm-debian9-net-node1 --nic1 bridged --bridgeadapter1 tap_port1"
  command="VBoxManage modifyvm $vm_name --nic$nic_number bridged --bridgeadapter$nic_number $network"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
vm_network_configure()
{
  # For now, we assume the first nic interface
  local nic="1"

  echo "Setting NIC \"network\" configuration for all VMs in the network..."

  for ((i = 1; i <= $number_of_vms; i++)) do

    # Set VM network configuration
    vm_set_network_interface $vm_base_name$i "1" $network_name$i

  done
}

#==================================================================================================================
#
#==================================================================================================================
vm_start()
{
  local command=""
  local vm_name=${1:-"vm_name_is_required"}

  # Start VM
  command="VBoxManage startvm $vm_name"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
#
#==================================================================================================================
vm_stop()
{
  local command=""
  local vm_name=${1:-"vm_name_is_required"}

  # Start VM
  command="VBoxManage controlvm $vm_name acpipowerbutton"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
vms_start()
{
  # For now, we assume the first nic interface
  local nic="1"

  echo "Launching all VMs in the network..."

  for ((i = 1; i <= $number_of_vms; i++)) do

    # Start VM
    vm_start $vm_base_name$i

  done
}

#==================================================================================================================
# 
#==================================================================================================================
vms_stop()
{
  # For now, we assume the first nic interface
  local nic="1"

  echo "Powering off all VMs in the network..."

  for ((i = 1; i <= $number_of_vms; i++)) do

    # Power off VM
    vm_stop $vm_base_name$i

  done
}

# Display ovs helper "menu"
ovs_show_menu
