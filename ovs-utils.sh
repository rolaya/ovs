#!/bin/sh

# Define text views
TEXT_VIEW_NORMAL_BLUE="\e[01;34m"
TEXT_VIEW_NORMAL_RED="\e[31m"
TEXT_VIEW_NORMAL_GREEN="\e[32m"
TEXT_VIEW_NORMAL_PURPLE="\e[177m"
TEXT_VIEW_NORMAL='\e[00m'

# The name of the physical wired interface (host specific)
wired_iface=enp5s0

# The IP address assigned (by the DHCP server) to the physical wired interface (host specific)
wired_iface_ip=192.168.1.206

# The name of the OVS bridge to create (it can be anything)
ovs_bridge=br0

# The number of VMs (and interfaces we are going to configure)
number_of_interfaces=1

# Default port name. Once generated, you will have something like:
# tap_port1, tap_port2, ... (depends on "number_of_interfaces").
port_name="tap_port"

# VirtualBox looks at this as the network name
network_name=$port_name

# For clarity, use number of VMs variable (it is the same as the number of ports/interfaces)
number_of_vms=$number_of_interfaces

# VM base name. The VMs names are something like "vm-debian9-net-node1".
# At presend, these VMs are "manually" generated. The "vm_base_name" must be manually changed
# here according to your local configuration (i.e. based on how the VMs in the testbed were
# named. It is assumed VMs are sequentially named).
vm_base_name="vm-debian9-net-node"

# This determines if we are going to use DHCP or static IP address for the host.
# Node: the guests can use either (but are configured for static ip).
use_dhcp="True"

# Traffic shaping specific definitions

# Max rate: 1GB/sec (network specific)
ether_max_rate=1000000000

# Array of openvswitch tables (incomplete)
declare -a ovs_tables_array=("Open_vSwitch" "Interface" "Bridge" "Port" "QoS" "Queue" "Flow_Table" "sFlow" "NetFlow" "Datapath")

#==================================================================================================================
#
#==================================================================================================================
ovs_show_menu()
{
  local port_name_sample=""
  local vm_name_sample=""

  # Initialize misc. for display to user
  port_name_sample=$port_name
  port_name_sample+="1"

  vm_name_sample=$vm_base_name
  vm_name_sample+="1"

  # Display current hardcoded configuration 
  echo
  echo "Current configuration (currently hardcoded)"
  echo "Manually update these values in this file according to your network configuration"
  echo "Wired interface:            [$wired_iface]"
  echo "Wired interface IP address: [$wired_iface_ip]"
  echo "Default bridge name:        [$ovs_bridge]"
  echo "Number of VMs in testbed:   [$number_of_vms]"
  echo "Expected VM base name:      [$vm_name_sample]. VM names will be sequential starting with [$vm_name_sample]"
  echo "VM base port name:          [$port_name]. Port names will be sequential starting with [$port_name_sample]"

  echo
  echo

  # Environment provisioning
  echo "Provisioning commands"
  echo "\"ovs_provision_for_build\"           - Provision system for building ovs"
  
  # Display some helpers to the user
  echo "Main commands"
  echo "=========================================================================================================================="
  echo "\"ovs_show_menu\"                     - Displays this menu"
  echo "\"ovs_start\"                         - Starts OVS daemons"
  echo "\"ovs_stop\"                          - Stops OVS daemons"
  echo "\"ovs_restart\"                       - Restarts OVS daemons"

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
  echo "\"vms_set_network_interface\"         - Set all VM's NIC \"network\" interface"

  echo
  echo "Network deployment and QoS configuration commands"
  echo "=========================================================================================================================="
  echo "\"ovs_deploy_network\"                   - Deploys network configuration"
  echo "\"ovs_set_qos\"                          - Configures QoS"
  echo "\"ovs_vm_set_qos\"                       - Configures QoS for specific vm3 (vm attached to tap_port3)"
  echo "\"ovs_port_qos_latency_create\"          - Create QoS record - latency (netem) on specified port"
  echo "                                         ex: ovs_port_qos_latency_create tap_port3 2000000"
  echo "\"ovs_port_qos_packet_loss_create\"      - Create QoS record - packet loss as a percentage (netem) on specified port"
  echo "                                         ex: ovs_port_qos_packet_loss_create tap_port3 10"
  echo "\"ovs_port_qos_max_rate_create\"         - Create QoS record - max rate on specified port"
  echo "\"ovs_port_qos_max_rate_update\"         - Update QoS record - max rate on specified port"
  echo "\"ovs_port_qos_packet_loss_update\"      - Update QoS record - packet loss on specified port"
  echo "\"ovs_port_qos_latency_update\"          - Update QoS record - latency on specified port"
  
  echo "\"ovs_purge_network\"                    - Purge deployed network (and QoS)"
  
  echo
  echo "Project build/install related commands"
  echo "=========================================================================================================================="
  echo "\"ovs_install\"                          - Builds and installs OVS daemons and kernel modules"
  echo "\"ovs_configure_debug_build\"            - Configures OVS project for debug build"
  echo "\"ovs_configure_release_build\"          - Configures OVS project for release build"
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
  command="sudo ip tuntap add mode tap $port"
  echo "Executing: [$command]"
  $command

  # Activate device/interface 
  command="sudo ip link set $port up"
  echo "Executing: [$command]"
  $command

  # Add tap device/interface to "br0" bridge
  command="sudo ovs-vsctl add-port $bridge $port"
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
  command="sudo ovs-vsctl del-port $bridge $port"
  echo "Executing: [$command]"
  $command

  # Deactivate device/interface 
  command="sudo ip link set $port down"
  echo "Executing: [$command]"
  $command

  # Delete tap port
  command="sudo ip tuntap del mode tap $port"
  echo "Executing: [$command]"
  $command

  echo "Deleted tap port/interface: [$port] from ovs bridge: [$bridge]"
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
  command="sudo ovs-vsctl add-br $bridge"
  echo "executing: [$command]..."
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_start()
{
  local command=""

  echo "Starting Open vSwitch..."

  # Update path with ovs scripts path.
  export PATH=$PATH:/usr/local/share/openvswitch/scripts

  # Starts "ovs-vswitchd:" and "ovsdb-server" daemons
  # This command must be executed as "root" user (for now).
  command="ovs-ctl start --delete-bridges"
  echo "executing: [$command]..."
  $command
}

#==================================================================================================================
#
#==================================================================================================================
ovs_stop()
{
  # These commands are executed as "root" user (for now)

  export PATH=$PATH:/usr/local/share/openvswitch/scripts

  # This command must be executed as "root" user (for now).
  command="ovs-ctl stop"
  echo "executing: [$command]..."
  $command 
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_restart()
{
  # This command must be executed as "root" user (for now).
  command="ovs-ctl restart --delete-bridges"
  echo "executing: [$command]..."
  $command 
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_deploy_network()
{
  local command=""

  # These commands are executed as "root" user (for now)
  
  echo "Deploying testbed network..."

  # create new bridge named "br0"
  command="sudo ovs-vsctl add-br $ovs_bridge"
  echo "executing: [$command]..."
  $command
  
  # Activate "br0" device 
  command="sudo ip link set $ovs_bridge up"
  echo "executing: [$command]..."
  $command

  # Add network device "enp5s0" to "br0" bridge. Device "enp5s0" is the
  # name of the actual physical wired network interface. In some devices
  # it may be eth0.
  command="sudo ovs-vsctl add-port $ovs_bridge $wired_iface"
  echo "executing: [$command]..."
  $command
  
  # Delete assigned ip address from "enp5s0" device/interface. This address 
  # was provided (served) by the DHCP server (in the local network).
  # For simplicity, I configured my verizon router to always assign this
  # ip address (192.168.1.206) to "this" host (i.e. the host where I am 
  # deploying ovs).
  command="sudo ip addr del $wired_iface_ip/24 dev $wired_iface"
  echo "executing: [$command]..."
  $command

  # Using DHCP?
  if [[ "$use_dhcp" = "True" ]]; then
    # Acquire ip address and assign it to the "br0" bridge/interface
    command="sudo dhclient $ovs_bridge"
    echo "executing: [$command]..."
    $command
  fi

  # Create tap interface(s) for VMs 1-6 (and add interface to "br0" bridge).
  command="ovs_bridge_add_ports $ovs_bridge"
  echo "executing: [$command]..."
  $command
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
    sudo ovs-vsctl del-port $port$1
  done
  
  sudo ovs-vsctl del-br $ovs_bridge
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
  local command=""

  # Configure traffic shaping for interfaces (to be) used by VM1 and VM2.
  # The max bandwidth allowed for VM1 will be 10Mbits/sec,
  # the max bandwidth allowed for VM2 will be 20Mbits/sec.
  # VM3 is used as the baseline, so no traffic shaping is applied to
  # this VM.
  command="sudo ovs-vsctl -- \
  set interface tap_port1 ofport_request=5 -- \
  set interface tap_port2 ofport_request=6 -- \
  set port $wired_iface qos=@newqos -- \
  --id=@newqos create qos type=linux-htb \
      other-config:max-rate=1000000000 \
      queues:123=@tap_port1_queue \
      queues:234=@tap_port2_queue -- \
  --id=@tap_port1_queue create queue other-config:max-rate=10000000 -- \
  --id=@tap_port2_queue create queue other-config:max-rate=20000000"
  echo "excuting: [$command]"
  $command  
}

#==================================================================================================================
#
#==================================================================================================================
ovs_configure_traffic_flows()
{
  local command=""

  # Use OpenFlow to direct packets from tap_port1, tap_port2 to their respective 
  # (traffic shaping) queues (reserved for them in "ovs_traffic_shape").
  command="sudo ovs-ofctl add-flow $ovs_bridge in_port=5,actions=set_queue:123,normal"
  echo "excuting: [$command]"
  $command

  command="sudo ovs-ofctl add-flow $ovs_bridge in_port=6,actions=set_queue:234,normal"
  echo "excuting: [$command]"
  $command
}

#==================================================================================================================
#
#==================================================================================================================
ovs_vm_set_qos()
{
  local command=""

  # Configure traffic shaping for interfaces (to be) used by VM1 and VM2.
  # The max bandwidth allowed for VM1 will be 10Mbits/sec,
  # the max bandwidth allowed for VM2 will be 20Mbits/sec.
  # VM3 is used as the baseline, so no traffic shaping is applied to
  # this VM.
  command="sudo ovs-vsctl -- \
  set interface tap_port3 ofport_request=7 -- \
  set port $wired_iface qos=@newqos1 -- \
  --id=@newqos1 create qos type=linux-htb \
      other-config:max-rate=1000000000 \
      queues:122=@tap_port3_queue -- \
  --id=@tap_port3_queue create queue other-config:max-rate=30000000"
  echo "excuting: [$command]"
  $command
  
  command="sudo ovs-ofctl add-flow $ovs_bridge in_port=7,actions=set_queue:122,normal"
  echo "excuting: [$command]"
  $command  
}

#==================================================================================================================
#
#==================================================================================================================
qos_id_format() 
{
  local temp=""
  local interface=$2
  local qos_type=$3
  local qos_other_config=$4

  # Generate a somewhat unique and readable qos id, something like:
  # "qos_id_enp5s0_tap_port1_linux-htb_max-rate". Ultimately the QoS table
  # record is identified by the record's uuid (something like:
  # bdc3fe06-edcc-419b-80bd-d523a0628aa2).
  temp="qos_id"
  temp+="_$wired_iface"
  temp+="_$interface"
  temp+="_$qos_type"
  temp+="_$qos_other_config"
  eval "$1=$temp"
}

#==================================================================================================================
#
#==================================================================================================================
ovs_port_qos_latency_create()
{
  local command=""
  local queue_name=""
  local qos_type=""
  local interface=$1
  local latency=$2
  local qos_id=""
  local qos_other_config=""
  local of_port_request=""
  local queue_number=""
  local qos_uuid=""
  local queue_uuid=""
  local uuids=""

  # Configure (netem latency) traffic shaping on interface.
  
  if [[ $# -eq 2 ]] && [[ $2 -gt 1 ]]; then

    # For clarity and simplicity set some ovs-vsctl parameters
    queue_name="${interface}_queue"
    qos_type="linux-netem"
    qos_other_config="latency"
    
    # Make the qos_id as unique as possible (contains port, interface qos type and other qos config),
    # something like "qos_id_enp5s0_tap_port1_linux-htb_max-rate"
    qos_id_format qos_id $interface $qos_type $qos_other_config

    # We use the number part of the interface as the openflow port request and openflow queue number
    of_port_request=$(echo "$interface" | sed 's/[^0-9]*//g')
    queue_number=$(echo "$interface" | sed 's/[^0-9]*//g')

    command="sudo ovs-vsctl -- \
    set interface $interface ofport_request=$of_port_request -- \
    set port $wired_iface qos=@$qos_id -- \
    --id=@$qos_id create qos type=$qos_type \
        other-config:$qos_other_config=$latency \
        queues:$queue_number=@$queue_name -- \
    --id=@$queue_name create queue other-config:$qos_other_config=$latency"
    echo "excuting: [$command]"
    $command

    command="sudo ovs-ofctl add-flow $ovs_bridge in_port=$of_port_request,actions=set_queue:$queue_number,normal"
    echo "excuting: [$command]"
    $command

    echo "Created QoS configuration:"
    echo "bridge:            [$ovs_bridge]"
    echo "port:              [$wired_iface]"
    echo "interface:         [$interface]"
    echo "type:              [$qos_type]"
    echo "config:            [$qos_other_config]"
    echo "latency:           [$latency]"
    echo "qos id:            [$qos_id]"
    echo "of port request:   [$of_port_request]"
    echo "of queue number:   [$queue_number]"
    echo "UUIDs:             [$uuids] (second one is Queue record)"

  else
    echo "Usage: ovs_port_qos_packet_loss_create port loss (e.g. ovs_port_qos_set_qos tap_port1 20)..."
  fi
}

#==================================================================================================================
#
#==================================================================================================================
ovs_port_qos_packet_loss_create()
{
  local command=""
  local queue_name=""
  local qos_type=""
  local interface=$1
  local packet_loss=$2
  local qos_id=""
  local qos_other_config=""
  local of_port_request=""
  local queue_number=""
  local qos_uuid=""
  local queue_uuid=""
  local uuids=""

  # Configure (netem packet loss) traffic shaping on interface.

  # Insure port and max rate supplied (and max rate is a number)
  if [[ $# -eq 2 ]] && [[ $2 -gt 1 ]]; then

    # For clarity and simplicity set some ovs-vsctl parameters
    queue_name="${interface}_queue"
    qos_type="linux-netem"
    qos_other_config="loss"
    
    # Make the qos_id as unique as possible (contains port, interface qos type and other qos config),
    # something like "qos_id_enp5s0_tap_port1_linux-htb_max-rate"
    qos_id_format qos_id $interface $qos_type $qos_other_config

    # We use the number part of the interface as the openflow port request and openflow queue number
    of_port_request=$(echo "$interface" | sed 's/[^0-9]*//g')
    queue_number=$(echo "$interface" | sed 's/[^0-9]*//g')
  
    command="sudo ovs-vsctl -- \
    set interface $interface ofport_request=$of_port_request -- \
    set port $wired_iface qos=@$qos_id -- \
    --id=@$qos_id create qos type=$qos_type \
        other-config:loss=$packet_loss \
        queues:$queue_number=@$queue_name -- \
    --id=@$queue_name create queue other-config:$qos_other_config=$packet_loss"
    echo "excuting: [$command]"
    $command

    # Format and execute flow command (creates and initializes new record in Queue table)
    command="sudo ovs-ofctl add-flow $ovs_bridge in_port=$of_port_request,actions=set_queue:$queue_number,normal"
    echo "excuting: [$command]"
    $command

    echo "Created QoS configuration:"
    echo "bridge:            [$ovs_bridge]"
    echo "port:              [$wired_iface]"
    echo "interface:         [$interface]"
    echo "type:              [$qos_type]"
    echo "config:            [$qos_other_config]"
    echo "packet loss:       [$packet_loss]"
    echo "qos id:            [$qos_id]"
    echo "of port request:   [$of_port_request]"
    echo "of queue number:   [$queue_number]"
    echo "UUIDs:             [$uuids] (second one is Queue record)"

  else
    echo "Usage: ovs_port_qos_packet_loss_create port loss (e.g. ovs_port_qos_set_qos tap_port1 20)..."
  fi
}

#==================================================================================================================
# Set linux-htb max-rate QoS. This creates a new record ("QoS" table) everytime it is executed.
# This function "returns" two uuids, one for the QoS and one for the Queue record. The QoS record uuid is required
# for later operations (e.g. for updating the max-rate for the port).
#==================================================================================================================
ovs_port_qos_max_rate_create()
{
  local command=""
  local queue_name=""
  local qos_type=""
  local interface=$1
  local port_max_rate=$2
  local qos_id=""
  local qos_other_config=""
  local of_port_request=""
  local queue_number=""
  local qos_uuid=""
  local queue_uuid=""
  local uuids=""

  # Configure max rate QoS.

  # Insure port and max rate supplied (and max rate is a number)
  if [[ $# -eq 2 ]] && [[ $2 -gt 1 ]]; then

    # For clarity and simplicity set some ovs-vsctl parameters
    queue_name="${interface}_queue"
    qos_type="linux-htb"
    qos_other_config="max-rate"
    
    # Make the qos_id as unique as possible (contains port, interface qos type and other qos config),
    # something like "qos_id_enp5s0_tap_port1_linux-htb_max-rate"
    qos_id_format qos_id $interface $qos_type $qos_other_config

    # We use the number part of the interface as the openflow port request and openflow queue number
    of_port_request=$(echo "$interface" | sed 's/[^0-9]*//g')
    queue_number=$(echo "$interface" | sed 's/[^0-9]*//g')

    # Format and execute traffic shaping command (creates and initializes new record in QoS table)
    command="sudo ovs-vsctl -- \
    set interface $interface ofport_request=$of_port_request -- \
    set port $wired_iface qos=@$qos_id -- \
    --id=@$qos_id create qos type=$qos_type \
        other-config:$qos_other_config=$ether_max_rate \
        queues:$queue_number=@$queue_name -- \
    --id=@$queue_name create queue other-config:$qos_other_config=$port_max_rate"
    echo "excuting: [$command]"
    uuids="$($command)"

    # Format and execute flow command (creates and initializes new record in Queue table)
    command="sudo ovs-ofctl add-flow $ovs_bridge in_port=$of_port_request,actions=set_queue:$queue_number,normal"
    echo "excuting: [$command]"
    $command

    echo "Created QoS configuration:"
    echo "bridge:            [$ovs_bridge]"
    echo "port:              [$wired_iface]"
    echo "interface:         [$interface]"
    echo "type:              [$qos_type]"
    echo "config:            [$qos_other_config]"
    echo "ether max rate:    [$ether_max_rate]"
    echo "port max rate:     [$port_max_rate]"
    echo "qos id:            [$qos_id]"
    echo "of port request:   [$of_port_request]"
    echo "of queue number:   [$queue_number]"
    echo "UUIDs:             [$uuids] (second one is Queue record)"

  else
    echo "Usage: ovs_port_qos_set_qos port max-rate (e.g. ovs_port_qos_set_qos tap_port1 10000)..."
  fi
}

#==================================================================================================================
# Updates QoS.
#==================================================================================================================
ovs_port_queue_update()
{
  local command=""
  local uuid=$1
  local other_config=$2
  local other_config_val=$3

  # Update QoS max rate.

  # Insure uuid and max rate supplied (and max rate is a number)
  if [[ $# -eq 3 ]] && [[ $3 -gt 1 ]]; then

    # Format and execute traffic shaping command (creates and initializes new record in QoS table)
    command="sudo ovs-vsctl set Queue $uuid other_config:$other_config=$other_config_val"
    echo "excuting: [$command]"
    $command

    echo "Update QoS configuration:"
    echo "UUID:  [$uuid]"
    echo "QoS:   [$other_config:$other_config_val]"

  else
    echo "Usage: ovs_port_queue_update uuid max-rate max-rate-value (e.g. \"ovs_port_queue_update bdc3fe06-edcc-419b-80bd-d523a0628aa2 max-rate 30000000\")"
  fi
}

#==================================================================================================================
# Updates QoS - netem latency.
#==================================================================================================================
ovs_port_qos_latency_update()
{
  local uuid=$1
  local latency=$2
  local other_config="latency"

  # Update QoS max rate.

  # Insure uuid and max rate supplied (and max rate is a number)
  if [[ $# -eq 2 ]] && [[ $2 -gt 1 ]]; then

    ovs_port_queue_update $uuid $other_config $latency

  else
    echo "Usage: ovs_port_qos_latency_update uuid latency (e.g. \"ovs_port_qos_latency_update bdc3fe06-edcc-419b-80bd-d523a0628aa2 1000000\")..."
  fi
}

#==================================================================================================================
# Updates QoS - netem packet loss.
#==================================================================================================================
ovs_port_qos_packet_loss_update()
{
  local uuid=$1
  local packet_loss=$2
  local other_config="loss"

  # Update QoS max rate.

  # Insure uuid and max rate supplied (and max rate is a number)
  if [[ $# -eq 2 ]] && [[ $2 -gt 1 ]]; then

    ovs_port_queue_update $uuid $other_config $packet_loss

  else
    echo "Usage: ovs_port_qos_packet_loss_update uuid loss (e.g. \"ovs_port_qos_packet_loss_update bdc3fe06-edcc-419b-80bd-d523a0628aa2 30\")..."
  fi
}

#==================================================================================================================
# Updates linux-htb max-rate QoS.
#==================================================================================================================
ovs_port_qos_max_rate_update()
{
  local uuid=$1
  local port_max_rate=$2
  local other_config="max-rate"

  # Update QoS max rate.

  # Insure uuid and max rate supplied (and max rate is a number)
  if [[ $# -eq 2 ]] && [[ $2 -gt 1 ]]; then

    ovs_port_queue_update $uuid $other_config $port_max_rate

  else
    echo "Usage: ovs_port_qos_max_rate_update uuid max-rate (e.g. \"ovs_port_qos_max_rate_update bdc3fe06-edcc-419b-80bd-d523a0628aa2 30000000\")..."
  fi
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
  local command=""

  # These commands are executed as "root" user (for now)
  
  echo "Purging testbed network..."

  # Update path with ovs scripts path.
  export PATH=$PATH:/usr/local/share/openvswitch/scripts

  # Remote ports from bridge
  command="ovs_bridge_del_ports $ovs_bridge"
  echo "Executing: [$command]"
  $command

  # Delete physical wired port from ovs bridge
  command="sudo ovs-vsctl del-port $ovs_bridge $wired_iface"
  echo "Executing: [$command]"
  $command

  # Deactivate "br0" device 
  command="sudo ip link set $ovs_bridge down"
  echo "Executing: [$command]"
  $command

  # Delete bridge named "br0" from ovs
  command="sudo ovs-vsctl del-br $ovs_bridge"
  echo "Executing: [$command]"
  $command

  # Bring up physical wired interface
  command="sudo ip link set $wired_iface up"
  echo "Executing: [$command]"
  $command

  if [[ "$use_dhcp" = "True" ]]; then
    # Acquire ip address and assign it to the physical wired interface
    command="sudo dhclient $wired_iface"
    echo "Executing: [$command]"
    $command    
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
vms_set_network_interface()
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
vm_deploy()
{
  local vm_number=$1
  local vm_name=""
  local port=""
  
  # Configure the vm name and the port name the vm will use.
  local vm_name="$vm_base_name$vm_number"
  local port="$network_name$vm_number"

  echo "Attaching VM: [$vm_name] to bridge: [$ovs_bridge], port: [$port]..."

  # Add port to bridge
  ovs_bridge_add_port $port $ovs_bridge

  # "Attach" VM's network interface to bridge ports
  vm_set_network_interface $vm_name "1" $port
  
  echo "Starting VM: [$vm_name]..."

  # Start all VMs in the testbed
  vm_start $vm_name
}

#==================================================================================================================
# 
#==================================================================================================================
deploy_network()
{
  # Deploy network
  ovs_deploy_network
  
  # "Attach" VM's network interface to bridge ports
  vms_set_network_interface
  
  # Start all VMs in the testbed
  vms_start

  # Init QoS configuration
  #qos_initialize
}

#==================================================================================================================
#
#==================================================================================================================
qos_initialize()
{
  local port=""

  echo "Configuring QoS..."
  echo "Initializing QoS max-rate..."

  for ((i = 1; i <= $number_of_vms; i++)) do

    # This is something like tap_port1
    port="$port_name"
    port+="$i"

    # Create QoS record (defaulting to max ethernet rate on each port)
    ovs_port_qos_max_rate_create $port $ether_max_rate
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
  command="VBoxManage startvm $vm_name --type headless"
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

#==================================================================================================================
# 
#==================================================================================================================
ovs_dump_ports()
{
  local command=""

  command="sudo ovs-ofctl dump-ports br0"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_dump_flows()
{
  local command=""

  command="sudo ovs-ofctl dump-flows br0"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_dump_tables()
{
  local command=""

  command="sudo ovs-ofctl dump-tables br0"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_list_table()
{
  local table=$1
  local command=""

  echo -e "${TEXT_VIEW_NORMAL_GREEN}Displaying table: ${TEXT_VIEW_NORMAL}${TEXT_VIEW_NORMAL_BLUE}[$table]${TEXT_VIEW_NORMAL}"

  command="sudo ovs-vsctl list $table"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_list_tables()
{
  local arraylength=0

  arraylength=${#ovs_tables_array[@]}

  # Loop through all tables (hardcoded) defined in ovs tables array.
  for (( i=1; i<${arraylength}+1; i++ ));
    do
      # Display all records in current table (e.g. qos table)
      ovs_list_table ${ovs_tables_array[$i-1]}
  done
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_tables_list()
{
  local arraylength=0

  echo "Note: this is a partial list of Open vSwitch tables. For a complete list do \"sudo ovs-vsctl --help\""

  arraylength=${#ovs_tables_array[@]}

  # Loop through all tables (hardcoded) defined in ovs tables array.
  for (( i=1; i<${arraylength}+1; i++ ));
    do
      echo ${ovs_tables_array[$i-1]}
  done
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_create_qos_queue()
{
  local command=""
  local other_config=$1
  local other_config_val=$2
  
  command="sudo ovs-vsctl create queue other-config:$other_config=$other_config_val"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_qos_create()
{
  local command=""
  local type=$1
  
  command="sudo ovs-vsctl create qos type=$type"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_qos_add_queue()
{
  local command=""
  local uuid=$1
  local queue_id=$2
  local queue_uuid=$3
  
  command="sudo ovs-vsctl add qos $uuid queues $queue_id=$queue_uuid"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_interface_set_ofport_request()
{
  local command=""
  local iface_name=$1
  local ofport_request=$2

  # The interface name is something like "tap_port2", the ofport...
  command="sudo ovs-vsctl set interface $iface_name ofport_request=$ofport_request"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_interface_configure_flow()
{
  local command=""
  local in_port=$1
  local queue=$1

  command="sudo ovs-ofctl add-flow $ovs_bridge in_port=$in_port,actions=set_queue:$queue,normal"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_table_get_value()
{
  local command=""
  local table=$1
  local record=$2
  local column=$3
  local value=""

  echo "Looking for [$column] in table: [$table] with record: [$record]"

  command="sudo ovs-vsctl get $table $record $column"
  echo "Executing: [$command]"
  value="$($command)"

  echo "lksjdaksdjas $value"
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_table_find_record()
{
  local command=""
  local table=$1
  local condition=$2
  local record=""
  local record_uuid=""

  echo "Looking for record: [$condition] in table: [$table]"

  # If present, all this will return all columns in the record.
  command="sudo ovs-vsctl find $table $condition"
  echo "Executing: [$command]"
  record="$($command)"
  echo "$record"

  # For the "port" table for example, the output from the find command is something like:
  # "_uuid               : 53da5984-7424-4397-97fc-b83ce8e1c582"
  # "bond_active_slave   : []"
  # "bond_downdelay      : 0"
  # "bond_fake_iface     : false"
  # ...
  # ...
  # ...
  # We are interested in the record's uuid (third field)
  record_uuid="$(echo "$record" | grep "_uuid" | awk '{print $3}')"
  
  echo "$record_uuid"
}



# Display ovs helper "menu"
ovs_show_menu

