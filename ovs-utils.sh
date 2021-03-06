#!/bin/sh

#set -x			# activate debugging from here

# Define text views
TEXT_VIEW_NORMAL_BLUE="\e[01;34m"
TEXT_VIEW_NORMAL_RED="\e[31m"
TEXT_VIEW_NORMAL_GREEN="\e[32m"
TEXT_VIEW_NORMAL_MAGENTA="\e[35m"
TEXT_VIEW_NORMAL_YELLOW="\e[93m"

TEXT_VIEW_NORMAL_PURPLE="\e[177m"
TEXT_VIEW_NORMAL_ORANGE="\e[209m"
TEXT_VIEW_NORMAL='\e[00m'

# The name of the physical wired interface (host specific)
wired_iface=enp0s3

# The IP address assigned (by the DHCP server) to the host's wired interface (host specific)
wired_iface_ip=192.168.1.157

# The local network gatway IP address (relevant when using static IP addressing)
gateway_ip=192.168.1.1

# The name of the OVS bridge to create (it can be anything)
ovs_bridge=br0

# The number of VMs (and interfaces we are going to configure)
number_of_interfaces=6

# Default port name. Once generated, you will have something like:
# tap_port1, tap_port2, ... (depends on "number_of_interfaces").
port_name_base="tap_port"

# VirtualBox looks at this as the network name
network_name=$port_name_base

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

# Define some default qos values (update as per required configuration)
# Max rate: 1GB/sec (network specific), no latency, no packet loss
qos_default_max_rate=1000000000
qos_default_latency=1000000
qos_default_packet_loss=0

# Array of openvswitch tables (incomplete)
declare -a ovs_tables_array=("Open_vSwitch" "Interface" "Bridge" "Port" "QoS" "Queue" "Flow_Table" "sFlow" "NetFlow" "Datapath")

global_qos_queues_list=""

# We are going to use an array to "partition" the qos queue types numbering.
# This needs to be modified when support for new qos types is added to this
# script. This is a global definition used by misc. functions.
declare -A map_qos_type_queue_number_partition
map_qos_type_queue_number_partition["linux-htb.max-rate"]=100
map_qos_type_queue_number_partition["linux-netem.latency"]=200
map_qos_type_queue_number_partition["linux-netem.loss"]=300

# Gloabal...
g_qos_queue_number=0
g_qos_queue_record_uuid=""

# This flag should normally be set to true (because we want to start the VMs in out network). But
# just in case (for some reason) we do not want to start the VMs immediately after configuring the 
# network, we can manage that here.
g_start_vms_upon_network_provisioning=true

# Capture time when file was sourced 
g_sourced_datetime="$(date +%c)"

#==================================================================================================================
#
#==================================================================================================================
ovs_show_menu_option()
{
  local command_name=$1
  local command_description=$2
  echo -e "${TEXT_VIEW_NORMAL_BLUE}$command_name${TEXT_VIEW_NORMAL} $command_description"
}

#==================================================================================================================
#
#==================================================================================================================
ovs_show_menu()
{
  local datetime=""
  local port_name_sample=""
  local vm_name_sample=""
  local first_vm="1"

  # Initialize misc. for display to user
  port_name_sample=$port_name_base
  port_name_sample+="1"

  vm_name_sample=$vm_base_name
  vm_name_sample+="1"

  # Environment 
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}Environment"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"

  # Get date/time (useful for keeping track of changes)
  datetime="$(date +%c)"

  echo "Host name:                       [$HOSTNAME]"
  echo "Sourced time:                    [$g_sourced_datetime]"
  echo "Current time:                    [$datetime]"
  echo "Using DHCP for host's IP:        [$use_dhcp]"
  echo "Network interface:               [$wired_iface]"
  echo "Network interface IP address:    [$wired_iface_ip]"
  echo "Default gateway IP address:      [$gateway_ip]"
  echo "Default bridge name:             [$ovs_bridge]"
  echo "Number of VMs in testbed:        [$number_of_vms]"
  echo "VM base name:                    [$vm_base_name]"
  echo "VM range:                        [$vm_base_name$first_vm..$vm_base_name$number_of_vms]"
  echo "VM port range:                   [$port_name_base$first_vm..$port_name_base$number_of_vms]"
  echo

  # Deployment
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}Deployment"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"
  ovs_show_menu_option "ovs_start                        " " - Start OVS daemons (must be executed as root)"
  ovs_show_menu_option "deploy_network                   " " - Deploy network configuration and launch VMs"
  echo

   # Traffic shaping
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}Traffic shaping"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"
  ovs_show_menu_option "ovs_port_qos_max_rate_create     " " - set port bandwidth (mbps)"
  ovs_show_menu_option "                                 " "   usage:   ovs_port_qos_max_rate_create port_number bandwidth"
  ovs_show_menu_option "                                 " "   example: ovs_port_qos_max_rate_create 1 1000000"

  ovs_show_menu_option "ovs_port_qos_packet_loss_create  " " - set port packet loss (%)"
  ovs_show_menu_option "                                 " "   usage:   ovs_port_qos_packet_loss_create port_number packet_loss"
  ovs_show_menu_option "                                 " "   example: ovs_port_qos_max_rate_create 1 30"

  ovs_show_menu_option "ovs_port_qos_latency_create      " " - set port latency (microseconds)"
  ovs_show_menu_option "                                 " "   usage:   ovs_port_qos_latency_create port_number latency"
  ovs_show_menu_option "                                 " "   example: ovs_port_qos_max_rate_create 1 500000"

  ovs_show_menu_option "ovs_port_qos_max_rate_update     " " - update port bandwidth (mbps)"
  ovs_show_menu_option "                                 " "   usage:   ovs_port_qos_max_rate_update port_number bandwidth"
  ovs_show_menu_option "                                 " "   example: ovs_port_qos_max_rate_update 1 500000"

  ovs_show_menu_option "ovs_port_qos_packet_loss_update  " " - update port packet loss (%)"
  ovs_show_menu_option "                                 " "   usage:   ovs_port_qos_packet_loss_update port_number packet_loss"
  ovs_show_menu_option "                                 " "   example: ovs_port_qos_packet_loss_update 1 30"

  ovs_show_menu_option "ovs_port_qos_latency_update      " " - update port latency (microseconds)"
  ovs_show_menu_option "                                 " "   usage:   ovs_port_qos_latency_update port_number latency"
  ovs_show_menu_option "                                 " "   example: ovs_port_qos_latency_update 1 500000"

  #echo "\"ovs_bridge_add\"                    - Add bridge to system"
  #echo "\"ovs_bridge_add_ports\"              - Add ports to bridge"
  #echo "\"ovs_bridge_del\"                    - Delete bridge to system"
  #echo "\"ovs_bridge_del_ports\"              - Delete ports from bridge"

  # Hypervisor commands
  #echo "Hypervisor commands"
  #echo "=========================================================================================================================="
  #echo "\"vm_set_network_interface\"          - Set VM's NIC \"network\" (this is an existing port in an OVS bridge)"
  #echo "\"vms_set_network_interface\"         - Set all VM's NIC \"network\" interface"

  #echo
  #echo "Network deployment and QoS configuration commands"
  #echo "=========================================================================================================================="
  #echo "\"ovs_deploy_network\"                   - Deploys network configuration"
  #echo "\"ovs_set_qos\"                          - Configures QoS"
  #echo "\"ovs_vm_set_qos\"                       - Configures QoS for specific vm3 (vm attached to tap_port3)"
  #echo "\"ovs_port_qos_max_rate_update\"         - Update QoS record - max rate on specified port"
  #echo "\"ovs_port_qos_packet_loss_update\"      - Update QoS record - packet loss on specified port"
  #echo "\"ovs_port_qos_latency_update\"          - Update QoS record - latency on specified port"
  
  #echo "\"ovs_purge_network\"                    - Purge deployed network (and QoS)"
  
  #echo
  #echo "Project build/install related commands"
  #echo "=========================================================================================================================="
  #echo "\"ovs_install\"                          - Builds and installs OVS daemons and kernel modules"
  #echo "\"ovs_configure_debug_build\"            - Configures OVS project for debug build"
  #echo "\"ovs_configure_release_build\"          - Configures OVS project for release build"

   # Display some helpers to the user
  #echo "Main commands"
  #echo "=========================================================================================================================="
  #echo "\"ovs_show_menu\"                     - Displays this menu"
  #echo "\"ovs_start\"                         - Starts OVS daemons"
  #echo "\"ovs_stop\"                          - Stops OVS daemons"
  #echo "\"ovs_restart\"                       - Restarts OVS daemons"

  #echo "\"ovs_start_test\"                    - Starts OVS daemons, deploys network configuration and configures QoS"
  #echo "\"ovs_stop_test\"                     - Purges network configuration, QoS, restores wired interface and stops OVS daemons"
  #echo "\"vms_start\"                         - Start all VMs in the testbed"
  #echo "\"vms_stop\"                          - Stop all VMs in the testbed" 

  # Environment provisioning
  #echo "Provisioning commands"
  #echo "\"ovs_provision_for_build\"           - Provision system for building ovs" 
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
  local port=${2:-$port_name_base}
  
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
  else
    # Add (move) the wired interface ip address to the bridge interface
    command="sudo ip addr add $wired_iface_ip/24 dev $ovs_bridge"
    echo "executing: [$command]..."
    $command

    # Add static route to allow access to hosts outside the local subnet
    command="sudo route add default gw $gateway_ip $ovs_bridge"
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
  local port=${2:-$port_name_base}

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
  local port_number=$1
  local port_name=""
  local qos_type=""
  local qos_other_config=""
  local qos_other_config_value=$2

  port_name="$port_name_base$port_number"
  qos_type="linux-netem"
  qos_other_config="latency"
  
  # Configure (netem latency) traffic shaping on interface.
  ovs_port_qos_netem_create $port_name $qos_type $qos_other_config $qos_other_config_value $qos_default_latency
}

#==================================================================================================================
#
#==================================================================================================================
ovs_port_qos_packet_loss_create()
{
  local port_number=$1
  local port_name=""
  local qos_type=""
  local qos_other_config=""
  local qos_other_config_value=$2

  port_name="$port_name_base$port_number"
  qos_type="linux-netem"
  qos_other_config="loss"
  
  # Configure (netem loss) traffic shaping on interface.
  ovs_port_qos_netem_create $port_name $qos_type $qos_other_config $qos_other_config_value $qos_default_packet_loss
}

#==================================================================================================================
# Set linux-htb max-rate QoS. This creates a new record ("QoS" table) everytime it is executed.
# This function "returns" two uuids, one for the QoS and one for the Queue record. The QoS record uuid is required
# for later operations (e.g. for updating the max-rate for the port).
#
# parameters:
# port:     the virtual port number.
# max-rate: the max-rate to set the port to.
#==================================================================================================================
ovs_port_qos_max_rate_create()
{
  local port_number=$1
  local port_name=""
  local qos_type=""
  local qos_other_config=""
  local qos_other_config_value=$2

  # Format the port name based on the port base name and port number (something like tab_port1)
  port_name="$port_name_base$port_number"
  qos_type="linux-htb"
  qos_other_config="max-rate"
  
  ovs_port_qos_htb_create $port_name $qos_type $qos_other_config $qos_other_config_value $qos_default_max_rate
}

#==================================================================================================================
# Set linux-htb max-rate QoS. This creates a new record ("QoS" table) everytime it is executed.
# This function "returns" two uuids, one for the QoS and one for the Queue record. The QoS record uuid is required
# for later operations (e.g. for updating the max-rate for the port).
#
# parameters:
# port:     the virtual port create qos for, e.g tap_port1.
# max-rate: the max-rate to set the port to.
#==================================================================================================================
ovs_port_qos_htb_create()
{
  local command=""
  local queue_name=""
  local interface=$1
  local qos_type=$2
  local qos_other_config=$3
  local qos_other_config_value=$4
  local qos_default_value=$5
  local qos_id=""
  local qos_uuid=""
  local queue_uuid=""
  local of_port_request=""
  local queue_number=0
  local uuids=""
  local qos_defined=false
  local linux_htb_qos_record_uuid=""
  local linux_htb_queue_record_uuid=""
  local old_ifs=""
  local table=""
  local qos=""
  local port_number=0
  local port_name=""

  # Format the "complete" qos type, something like "linux-htm.max-rate"
  qos="$qos_type.$qos_other_config"

  echo "Creating qos:"
  echo "port:               [$interface]"
  echo "qos:                [$qos]"
  echo "qos type:           [$qos_type]"
  echo "default value:      [$qos_default_value]"
  echo "other config:       [$qos_other_config]"
  echo "other config value: [$qos_other_config_value]"

  # Perform some parameter
  if [[ $# -eq 5 ]] && [[ $4 -gt 0 ]]; then

    # When qos is linux-htm max-rate, the qos configuration includes the physical interface.
    # (Need to understand this better (see ovs documentation in web)).
    port_name=$wired_iface

    # Find record in "port" table whose "name" is enp5s0 (the name of our wired ethernet interface).
    table="port"
    condition="name=$port_name"
    ovs_table_find_record $table "$condition" uuid

    # QoS configured?
    if [[ "$uuid" != "" ]]; then

      # Get qos uuid associated with port
      ovs_table_get_value $table $uuid "qos" qos_uuid

      # Remove [] from value
      qos_uuid=$(echo "$qos_uuid" | sed 's/\[//g')
      qos_uuid=$(echo "$qos_uuid" | sed 's/\]//g')
    
      if [[ "$qos_uuid" != "" ]]; then
        qos_defined=true
      fi
    fi

    # For clarity and simplicity set some ovs-vsctl parameters
    queue_name="${interface}_queue"

    # Make the qos_id as unique as possible (contains port, interface qos type and other qos config),
    # something like "qos_id_enp5s0_tap_port1_linux-htb_max-rate"
    qos_id_format qos_id $interface $qos_type $qos_other_config

    # We use the number part of the interface as the openflow port request and openflow queue number
    of_port_request=$(echo "$interface" | sed 's/[^0-9]*//g')
    port_number=$(echo "$interface" | sed 's/[^0-9]*//g')

    # Get queue number based on qos type and port number
    ovs_get_qos_queue_number $qos $port_number

    # Update local value
    queue_number=$g_qos_queue_number
    
    # qos already defined?
    if [[ "$qos_defined" = false ]]; then

      # Format and execute traffic shaping command (creates and initializes a single 
      # qos and queue table record). This command returns a uuid for each of the records
      # created. The second uuid is the uuid of the queue record. This is the record
      # we update when we want to modify the max-traffic for the port via
      # ovs_port_qos_max_rate_update.
      command="sudo ovs-vsctl -- \
      set interface $interface ofport_request=$of_port_request -- \
      set port $port_name qos=@$qos_id -- \
      --id=@$qos_id create qos type=$qos_type \
          other-config:$qos_other_config=$qos_default_value \
          queues:$queue_number=@$queue_name -- \
      --id=@$queue_name create queue other-config:$qos_other_config=$qos_other_config_value"
      echo "excuting: [$command]"
      uuids="$($command)"

      # Backup IFS (this is a "system/environment" wide setting)
      old_ifs=$IFS

      # Convert LF to space (for use as the IFS)
      delimeted_uuids=$(echo "$uuids" | tr '\n' ' ')

      # Use space as delimiter
      IFS=' '

      # uuids are separated by IFS
      read -ra  uuid_array <<< "$delimeted_uuids"
      
      # Restore IFS
      IFS=$old_ifs

      # (for debugging) save the uuid of the qos, queue records
      linux_htb_qos_record_uuid="${uuid_array[0]}"
      linux_htb_queue_record_uuid="${uuid_array[1]}"

      # Format and execute flow command (creates and initializes new record in Queue table)
      command="sudo ovs-ofctl add-flow $ovs_bridge in_port=$of_port_request,actions=set_queue:$queue_number,normal"
      echo "excuting: [$command]"
      $command

    else

      # The "main" linux-htb record exists, we need to add a qos queue for the supplied port, etc.
      
      # Create max-rate queue
      ovs_create_qos_queue $qos_other_config $qos_other_config_value queue_uuid
      
      # Add the queue to the qos list of queues
      ovs_qos_add_queue $qos_uuid $queue_number $queue_uuid

      # Configure openflow port request
      ovs_interface_set_ofport_request $interface $of_port_request

      # Configure flow
      ovs_interface_configure_flow $of_port_request $queue_number

    fi

    echo "Created QoS configuration:"
    echo "bridge:              [$ovs_bridge]"
    echo "port:                [$wired_iface]"
    echo "interface:           [$interface]"
    echo "type:                [$qos_type]"
    echo "other config:        [$qos_other_config]"
    echo "other config value:  [$qos_other_config_value]"
    echo "qos id:              [$qos_id]"
    echo "of port request:     [$of_port_request]"
    echo "of queue number:     [$queue_number]"
    echo "qos uuid:            [$linux_htb_qos_record_uuid]"
    echo "queue uuid:          [$linux_htb_queue_record_uuid]"

  else
    echo "Usage:    ovs_port_qos_htb_create qos_type qos_other_config qos_other_config_value qos_default_max_rate..."
    echo "Example: \"ovs_port_qos_htb_create tap_port1 linux-htm max-rate 10000000 1000000000\""
  fi
}

#==================================================================================================================
# Handles packet loss and latency
#==================================================================================================================
ovs_port_qos_netem_create()
{
  local command=""
  local queue_name=""
  local interface=$1
  local qos_type=$2
  local qos_other_config=$3
  local qos_other_config_value=$4
  local qos_default_value=$5
  local qos_id=""
  local queue_uuid=""
  local of_port_request=""
  local queue_number=0
  local uuids=""
  local qos_defined=false
  local linux_htb_qos_record_uuid=""
  local linux_htb_queue_record_uuid=""
  local old_ifs=""
  local table=""
  local qos=""
  local port_number=0
  local port_name=""

  # Format the "complete" qos type, something like "linux-htm.max-rate"
  qos="$qos_type.$qos_other_config"

  echo "Creating qos:"
  echo "port:               [$interface]"
  echo "qos:                [$qos]"
  echo "qos type:           [$qos_type]"
  echo "default value:      [$qos_default_value]"
  echo "other config:       [$qos_other_config]"
  echo "other config value: [$qos_other_config_value]"

  # Perform some parameter
  if [[ $# -eq 5 ]] && [[ $4 -gt 0 ]]; then

    # When qos is linux-netem, the qos configuration DOES not include the physical interface.
    # (Need to understand this better (see ovs documentation in web)).
    port_name=$interface

    # Find record in "port" table whose "name" is enp5s0 (the name of our wired ethernet interface).
    table="port"
    condition="name=$port_name"
    ovs_table_find_record $table "$condition" uuid

    # For clarity and simplicity set some ovs-vsctl parameters
    queue_name="${interface}_queue"

    # Make the qos_id as unique as possible (contains port, interface qos type and other qos config),
    # something like "qos_id_enp5s0_tap_port1_linux-htb_max-rate"
    qos_id_format qos_id $interface $qos_type $qos_other_config

    # We use the number part of the interface as the openflow port request and openflow queue number
    of_port_request=$(echo "$interface" | sed 's/[^0-9]*//g')
    port_number=$(echo "$interface" | sed 's/[^0-9]*//g')

    # Get queue number based on qos type and port number
    ovs_get_qos_queue_number $qos $port_number

    # Update local value
    queue_number=$g_qos_queue_number
    
    # Format and execute traffic shaping command (creates and initializes a single 
    # qos and queue table record). This command returns a uuid for each of the records
    # created. The second uuid is the uuid of the queue record. This is the record
    # we update when we want to modify the max-traffic for the port via
    # ovs_port_qos_max_rate_update.
    command="sudo ovs-vsctl -- \
    set interface $interface ofport_request=$of_port_request -- \
    set port $port_name qos=@$qos_id -- \
    --id=@$qos_id create qos type=$qos_type \
        other-config:$qos_other_config=$qos_other_config_value"
    echo "excuting: [$command]"
    uuids="$($command)"

    # Backup IFS (this is a "system/environment" wide setting)
    old_ifs=$IFS

    # Convert LF to space (for use as the IFS)
    delimeted_uuids=$(echo "$uuids" | tr '\n' ' ')

    # Use space as delimiter
    IFS=' '

    # uuids are separated by IFS
    read -ra  uuid_array <<< "$delimeted_uuids"
    
    # Restore IFS
    IFS=$old_ifs

    # (for debugging) save the uuid of the qos, queue records
    linux_htb_qos_record_uuid="${uuid_array[0]}"
    linux_htb_queue_record_uuid="${uuid_array[1]}"

    # Format and execute flow command (creates and initializes new record in Queue table)
    command="sudo ovs-ofctl add-flow $ovs_bridge in_port=$of_port_request,actions=set_queue:$queue_number,normal"
    echo "excuting: [$command]"
    $command

    echo "Created QoS configuration:"
    echo "bridge:              [$ovs_bridge]"
    echo "port:                [$wired_iface]"
    echo "interface:           [$interface]"
    echo "type:                [$qos_type]"
    echo "other config:        [$qos_other_config]"
    echo "other config value:  [$qos_other_config_value]"
    echo "qos id:              [$qos_id]"
    echo "of port request:     [$of_port_request]"
    echo "of queue number:     [$queue_number]"
    echo "qos uuid:            [$linux_htb_qos_record_uuid]"
    echo "queue uuid:          [$linux_htb_queue_record_uuid]"

  else
    echo "Usage:    ovs_port_qos_netem_create qos_type qos_other_config qos_other_config_value qos_default_max_rate..."
    echo "Example: \"ovs_port_qos_netem_create tap_port1 linux-htm max-rate 10000000 1000000000\""
  fi
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_port_qos_htb_delete()
{
  local command=""
  local ovs_port=$1
  local table="port"
  local condition=""
  local uuid=""
  local column="qos"
  local qos_uuid=""
  local qos_queues_uuid=""

  # Insure port is supplied (something like tap_port1)
  if [[ $# -eq 1 ]]; then

    condition="name=$ovs_port"

    # Find record in "port" table whose "name" is the port name supplied by caller.
    ovs_table_find_record $table "$condition" uuid

    if [[ "$uuid" != "" ]]; then

      # Get qos uuid associated with port
      ovs_table_get_value $table $uuid "qos" qos_uuid

      # Clear "qos" field in "port" table
      ovs_table_clear_values $table $uuid $column

      # Get list of qos queues uuids (for now, result in global variable)
      table="qos"
      ovs_table_get_list $table $qos_uuid "queues"

      # Delete record from qos table
      table="qos"
      ovs_table_delete_record $table $qos_uuid

      # Purge records from queues table
      ovs_queue_table_purge

    else
      echo -e "${TEXT_VIEW_NORMAL_RED}Error: record [$condition] not found in table: [$table]${TEXT_VIEW_NORMAL}"
    fi

  else
    echo "Usage: ovs_port_qos_htb_delete port (e.g. ovs_port_qos_htb_delete tap_port1)..."
  fi
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_port_qos_netem_purge()
{
  local command=""
  local port_number=
  local port_name=""

  for ((i = $number_of_interfaces; i > 0; i--)) do

    port_name="$port_name_base$i"

    # Delete tap port tap_portx from ovs bridge
    ovs_port_qos_netem_delete $port_name

  done
}

#==================================================================================================================
# Note: at present, we are handling all netem (packet loss, latency)
#==================================================================================================================
ovs_port_qos_netem_delete()
{
  local command=""
  local ovs_port=$1
  local table="port"
  local condition=""
  local uuid=""
  local column="qos"
  local qos_uuid=""
  local qos_queues_uuid=""

  # Insure port is supplied (something like tap_port1)
  if [[ $# -eq 1 ]]; then

    condition="name=$ovs_port"

    # Find record in "port" table whose "name" is the port name supplied by caller.
    ovs_table_find_record $table "$condition" uuid

    if [[ "$uuid" != "" ]]; then

      # Get qos uuid associated with port
      ovs_table_get_value $table $uuid "qos" qos_uuid

      # Clear "qos" field in "port" table
      ovs_table_clear_values $table $uuid $column

      # Get list of qos queues uuids (for now, result in global variable)
      table="qos"
      ovs_table_get_list $table $qos_uuid "queues"

      # Delete record from qos table
      table="qos"
      ovs_table_delete_record $table $qos_uuid

      # Purge records from queues table
      ovs_queue_table_purge

    else
      echo -e "${TEXT_VIEW_NORMAL_BLUE}Warning: record [$condition] not found in table: [$table]${TEXT_VIEW_NORMAL}"
    fi

  else
    echo "Usage: ovs_port_qos_htb_delete port (e.g. ovs_port_qos_htb_delete tap_port1)..."
  fi
}

#==================================================================================================================
# Updates port qos queue.
#==================================================================================================================
ovs_port_qos_queue_update()
{
  local command=""
  local uuid=$1
  local other_config=$2
  local other_config_val=$3

  # Update QoS max rate.

  echo "Update port queue:"
  echo "queue record uuid:  [$uuid]"
  echo "other config:       [$other_config]"
  echo "other config value: [$other_config_val]"

  # Validate parameters
  if [[ $# -eq 3 ]] && [[ $3 -gt 1 ]]; then

    # Format and execute traffic shaping command (creates and initializes new record in QoS table)
    command="sudo ovs-vsctl set queue $uuid other_config:$other_config=$other_config_val"
    echo "excuting: [$command]"
    $command

    echo "Update QoS configuration:"
    echo "UUID:  [$uuid]"
    echo "QoS:   [$other_config:$other_config_val]"

  else

    echo -e "${TEXT_VIEW_NORMAL_RED}Error: failed to pdate QoS configuration!${TEXT_VIEW_NORMAL}"
    echo "UUID:  [$uuid]"
    echo "QoS:   [$other_config:$other_config_val]"
    echo "Usage: ovs_port_qos_queue_update uuid max-rate max-rate-value (e.g. \"ovs_port_qos_queue_update bdc3fe06-edcc-419b-80bd-d523a0628aa2 max-rate 30000000\")"
  fi
}

#==================================================================================================================
# Updates port qos.
#==================================================================================================================
ovs_port_qos_update()
{
  local command=""
  local uuid=$1
  local other_config=$2
  local other_config_val=$3

  # Update QoS max rate.

  echo "Update port queue:"
  echo "queue record uuid:  [$uuid]"
  echo "other config:       [$other_config]"
  echo "other config value: [$other_config_val]"

  # Validate parameters
  if [[ $# -eq 3 ]]; then

    # Format and execute traffic shaping command (creates and initializes new record in QoS table)
    command="sudo ovs-vsctl set qos $uuid other_config:$other_config=$other_config_val"
    echo "excuting: [$command]"
    $command

    echo "Update QoS configuration:"
    echo "UUID:  [$uuid]"
    echo "QoS:   [$other_config:$other_config_val]"

  else

    echo -e "${TEXT_VIEW_NORMAL_RED}Error: failed to pdate QoS configuration!${TEXT_VIEW_NORMAL}"
    echo "UUID:  [$uuid]"
    echo "QoS:   [$other_config:$other_config_val]"
    echo "Usage: ovs_port_qos_queue_update uuid max-rate max-rate-value (e.g. \"ovs_port_qos_queue_update bdc3fe06-edcc-419b-80bd-d523a0628aa2 max-rate 30000000\")"
  fi
}

#==================================================================================================================
# Updates QoS - netem latency.
#==================================================================================================================
ovs_port_qos_latency_update()
{
  local record_uuid=""
  local port_number=$1
  local queue_number=0
  local latency=$2
  local qos_type="linux-netem"
  local other_config="latency"
  local port_name=""

  # Update QoS max rate.

  port_name="$port_name_base$port_number"

  echo "Update port qos:"
  echo "port number: [$table]"
  echo "port name:   [$port_name]"
  echo "latency:     [$latency microseconds]"

  # Insure uuid and latency are supplied
  if [[ $# -eq 2 ]]; then

    # Format port name
    port_name="$port_name_base$port_number"

    # Delete qos entry
    ovs_port_qos_netem_delete $port_name

    # Recreate the qos entry with the new value
    ovs_port_qos_latency_create $port_number $latency

    # Find record in "port" table
    #table="port"
    #condition="name=$port_name"
    #ovs_table_find_record $table "$condition" uuid

    # Get qos uuid associated with port
    #table="port"
    #value="qos"
    #ovs_table_get_value $table $uuid $value qos_uuid

    # Update port's qos
    #ovs_port_qos_update $qos_uuid $other_config $latency

  else
    echo "Usage: ovs_port_qos_packet_loss_update...."
  fi
}

#==================================================================================================================
# Updates QoS - netem packet loss.
#==================================================================================================================
ovs_port_qos_packet_loss_update()
{
  local record_uuid=""
  local port_number=$1
  local queue_number=0
  local packet_loss=$2
  local qos_type="linux-netem"
  local other_config="loss"
  local port_name=""

  # Update QoS max rate.

  port_name="$port_name_base$port_number"

  echo "Update port qos:"
  echo "port number: [$table]"
  echo "port name:   [$port_name]"
  echo "packet loss: [$packet_loss%]"

  # Insure uuid and latency are supplied
  if [[ $# -eq 2 ]]; then

    # Format port name
    port_name="$port_name_base$port_number"

    # Delete qos entry
    ovs_port_qos_netem_delete $port_name

    # Recreate the qos entry with the new value
    ovs_port_qos_packet_loss_create $port_number $packet_loss

    # Find record in "port" table
    #table="port"
    #condition="name=$port_name"
    #ovs_table_find_record $table "$condition" uuid

    # Get qos uuid associated with port
    #table="port"
    #value="qos"
    #ovs_table_get_value $table $uuid $value qos_uuid

    # Update port's qos
    #ovs_port_qos_update $qos_uuid $other_config $packet_loss

  else
    echo "Usage: ovs_port_qos_packet_loss_update...."
  fi
}

#==================================================================================================================
# Updates linux-htb max-rate QoS.
#==================================================================================================================
ovs_port_qos_max_rate_update()
{
  local record_uuid=""
  local port_number=$1
  local queue_number=0
  local port_max_rate=$2
  local qos_type="linux-htb"
  local other_config="max-rate"

  # Update QoS max rate.

  echo "Update port qos:"
  echo "port number: [$table]"
  echo "max rate:    [$port_max_rate]"

  # Insure uuid and max rate supplied (and max rate is a number)
  if [[ $# -eq 2 ]] && [[ $2 -gt 1 ]]; then

    ovs_get_qos_queue_number "$qos_type.$other_config" $port_number
    queue_number=$g_qos_queue_number
    
    # Get qos queue record uuid.
    ovs_port_find_qos_queue_record $port_number $queue_number
    record_uuid=$g_qos_queue_record_uuid

    # Update port's qos
    ovs_port_qos_queue_update $record_uuid $other_config $port_max_rate

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
  local port=${2:-$port_name_base}

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
  else
    # Remove static route
    command="sudo route del default"
    echo "executing: [$command]..."
    $command

    # Restore IP address to wired interface
    command="sudo ip addr add $wired_iface_ip/24 dev $wired_iface"
    echo "executing: [$command]..."
    $command

    # Add static route to allow access to hosts outside the local subnet
    command="sudo route add default gw $gateway_ip $wired_iface"
    echo "executing: [$command]..."
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
show_warning_msg()
{
  local msg="$1"

  echo -e "${TEXT_VIEW_NORMAL_MAGENTA}$msg${TEXT_VIEW_NORMAL}"
}

#==================================================================================================================
# 
#==================================================================================================================
deploy_network()
{
  local msg=""

  # Deploy network
  ovs_deploy_network
  
  # "Attach" VM's network interface to bridge ports
  vms_set_network_interface
  
  if [[ "$g_start_vms_upon_network_provisioning" = true ]]; then
    # Start all VMs in the testbed
    vms_start
  else
    msg="Warning [$number_of_interfaces] VM(s) not started as per configuration!!!"
    show_warning_msg "$msg"
  fi

  # Init QoS configuration
  #qos_initialize
}

#==================================================================================================================
#
#==================================================================================================================
qos_initialize()
{
  echo "Configuring QoS..."
  echo "Initializing QoS max-rate..."

  for ((i = 1; i <= $number_of_vms; i++)) do

    # Create QoS record (defaulting to max ethernet rate on each port)
    ovs_port_qos_max_rate_create "$i" $qos_default_max_rate
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
  local uuid=""
  local command=""
  local other_config=$1
  local other_config_val=$2
  
  echo "Creating queue..."
  echo "other config:       [$other_config]"
  echo "other config value: [$table]"

  command="sudo ovs-vsctl create queue other-config:$other_config=$other_config_val"
  echo "Executing: [$command]"
  uuid="$($command)"

  # Return the uuid of the queue created.
  eval "$3=$uuid"
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
  local queue=$2

  command="sudo ovs-ofctl add-flow $ovs_bridge in_port=$in_port,actions=set_queue:$queue,normal"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_table_get_list()
{
  local command=""
  local table=$1
  local record=$2
  local column=$3
  local value=""

  echo "Looking for [$column] in table: [$table] with record id: [$record]"

  command="sudo ovs-vsctl get $table $record $column"
  echo "Executing: [$command]"
  value="$($command)"

  if [[ "$value" != "" ]]; then
    echo "table:   [$table]"
    echo "record:  [$record]"
    echo "column:  [$column]"
    echo "value:   [$value]"
  fi

  global_qos_queues_list=$value
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

  echo "Looking for [$column] in table: [$table] with record id: [$record]"

  command="sudo ovs-vsctl get $table $record $column"
  echo "Executing: [$command]"
  value="$($command)"

  if [[ "$value" != "" ]]; then
    echo "table:   [$table]"
    echo "record:  [$record]"
    echo "column:  [$column]"
    echo "value:   [$value]"
  fi

  eval "$4=$value"
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_table_clear_values()
{
  local command=""
  local table=$1
  local record=$2
  local column=$3
  local value=""

  echo "Clearing [$column] in table: [$table] for record: [$record]"

  command="sudo ovs-vsctl clear $table $record $column"
  echo "Executing: [$command]"
  value="$($command)"
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

echo "1111111 \"$condition\""

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

  # Update the third parameter passed with the uuid of the record found (if any)
  eval "$3=$record_uuid"
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_table_delete_record()
{
  local command=""
  local table=$1
  local uuid=$2
  local result=""

  echo "Deleting record: [$uuid] from table: [$table]"

  # Delete record from table given table and uuid.
  command="sudo ovs-vsctl destroy $table $uuid"
  echo "Executing: [$command]"
  result="$($command)"
  echo "$result"
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_queue_table_purge()
{
  local uuid=""
  local index=0
  local uuids=""
  local old_ifs=""
  local uuid_array=""
  local arraylength=0
  local local_debug=True
  local table="queue"
  
  # Backup IFS (this is a shell "system/environment" wide setting)
  old_ifs=$IFS

  # Remove {} from qos_queues_uuid
  uuids=$(echo "$global_qos_queues_list" | sed 's/{//g')
  uuids=$(echo "$uuids" | sed 's/}//g')

  #echo "$uuids" | tee uuids.txt

  # Use space as delimiter
  IFS=' ,'

  # uuids are separated by IFS
  read -ra  uuid_array <<< "$uuids"

  arraylength=${#uuid_array[@]}

  echo "processing: [$arraylength] uuids..."

  for uuid in "${uuid_array[@]}"; do

    uuid=$(echo ${uuid:(-36)})

    echo "uuid[$index]: [$uuid]"

    # Delete record from queue table
    ovs_table_delete_record $table $uuid

    ((index++))
  done

  # Restore IFS
  IFS=$old_ifs
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_extract_uuids()
{
  local index=0
  local uuids=$1
  local old_ifs=""
  local uuid_array=""
  local arraylength=0
  local delimeted_uuids=""
  local local_debug=True
  
  # Backup IFS (this is a "system/environment" wide setting)
  old_ifs=$IFS

  # Convert LF to space (for use as the IFS)
  delimeted_uuids=$(echo "$uuids" | tr '\n' ' ')

  #echo "$uuids" | tee uuids.txt

  # Use space as delimiter
  IFS=' '

  # uuids are separated by IFS
  read -ra  uuid_array <<< "$delimeted_uuids"

  # For debugging purposes (set local_debug= True)
  if [[ $local_debug -eq True ]]; then

    arraylength=${#uuid_array[@]}

    echo "processing: [$arraylength] uuids..."

    for i in "${uuid_array[@]}"; do
      echo "uuid[$index]: [$i]"
      ((index++))
    done

  fi

  # Restore IFS
  IFS=$old_ifs

  # Update the third parameter passed with the uuid of the record found (if any)
  eval "$2=$uuid_array" 
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_purge_qos_records()
{
  local command=""
  local table=""

  local table="qos"
  command="sudo ovs-vsctl purge $table"
  echo "Executing: [$command]"
  $command

  local table="queue"
  command="sudo ovs-vsctl purge $table"
  echo "Executing: [$command]"
  $command  
}

#==================================================================================================================
#==================================================================================================================
ovs_port_find_qos_queue_record()
{
  local port_number=$1
  local queue_number=$2
  local command=""
  local table=""
  local condidion=""
  local uuid=""
  local qos_uuid=""
  local value=""
  local old_ifs=""
  local index=0
  local uuid_array=""
  local arraylength=0
  local uuids=""
  local record_queue_number=""
  local record_uuid=""

  echo "Find qos queue record uuid for port: [$port_number]..."

  # Initialize qos queue record uuid
  g_qos_queue_record_uuid=""

  # Find record in "port" table whose "name" is enp5s0 (the name of our wired ethernet interface).
  table="port"
  condition="name=$wired_iface"
  ovs_table_find_record $table "$condition" uuid

  # Get qos uuid associated with port
  table="port"
  value="qos"
  ovs_table_get_value $table $uuid $value qos_uuid

  # Get list of qos queues uuids (for now, result in global variable)
  table="qos"
  ovs_table_get_list $table $qos_uuid "queues"
  
  # Backup IFS (this is a shell "system/environment" wide setting)
  old_ifs=$IFS

  # Remove {} from qos_queues_uuid
  uuids=$(echo "$global_qos_queues_list" | sed 's/{//g')
  uuids=$(echo "$uuids" | sed 's/}//g')

  # Use space as delimiter
  IFS=' ,'

  # uuids are separated by IFS
  read -ra  uuid_array <<< "$uuids"

  arraylength=${#uuid_array[@]}

  echo "processing: [$arraylength] uuids..."

  # Find qos queue based on port number
  for uuid in "${uuid_array[@]}"; do

    # Extract the queue number from the queues, a single queue value is something like:
    # 101=50ebde1e-1700-4edb-b18e-366353da3827
    record_queue_number=${uuid%%=*}

    echo "queue number: ${uuid%%=*} $record_queue_number"
    echo "uuid[$index]: [$uuid]"

    # Is this the entry we are looking for?
    if [[ "$record_queue_number" -eq "$queue_number" ]]; then

      # Save the actual record uuid, something like:
      # 50ebde1e-1700-4edb-b18e-366353da3827
      record_uuid=$(echo ${uuid:(-36)})
      echo "$record_uuid"
      g_qos_queue_record_uuid=$record_uuid
    fi

    ((index++))
  
  done

  # Restore IFS
  IFS=$old_ifs

  echo "Qos queue record uuid for port [$port_number]: [$g_qos_queue_record_uuid]"
}  

#==================================================================================================================
#==================================================================================================================
ovs_get_qos_queue_number()
{
  local qos_type=$1
  local port_number=$2
  local queue_number=0
  local port_name=""

  # Initialize global, if the qos type is properly provided we will generate
  # a valid qos queue number.
  g_qos_queue_number=0

  # Format the port name (something like tap_port1)
  port_name="$port_name_base$port_number"

  # The queue number will be the base partition+port number (e.g. for
  # "linux-htb.max-rate" and port number 1, it will be 101).
  queue_number=${map_qos_type_queue_number_partition["$qos_type"]}

  # QoS type valid?
  if [[ "$queue_number" -gt "0" ]]; then

    # Update global qos queue number
    queue_number=$(($queue_number+$port_number))
    g_qos_queue_number=$queue_number
    
    echo "Generating queue number [$g_qos_queue_number] for port: [$port_name] with qos type: [$qos_type]..."

  else
    echo -e "${TEXT_VIEW_NORMAL_RED}Error: Unable to generate qos queue number for qos type: [$qos_type]${TEXT_VIEW_NORMAL}!"
  fi
}

#==================================================================================================================
#
#==================================================================================================================
qos_set_latency()
{
  local tap_port=$1
  local latency=$2
  local command=""
  local default_latency=0

  # Configure (netem latency) traffic shaping on interface.
  
  echo "Setting latency: [$latency] in port: [$tap_port]"
  
  command="sudo ovs-vsctl -- \
  set interface $tap_port ofport_request=7 -- \
  set port $tap_port qos=@qos_netem_latency -- \
  --id=@qos_netem_latency create qos type=linux-netem \
      other-config:latency=$latency \
      queues:122=@$tap_port_queue -- \
  --id=@$tap_port_queue create queue other-config:latency=$latency"
  echo "Executing: [$command]"
  $command 

  command="sudo ovs-ofctl add-flow $ovs_bridge in_port=7,actions=set_queue:122,normal"
  echo "Executing: [$command]"
  $command   
}

#==================================================================================================================
#
#==================================================================================================================
centos_firewall_allow_nfs()
{
  local command=""

  echo "Configuring firewall to enable NFS..."

  command="sudo firewall-cmd --permanent --zone=public --add-service=nfs"
  echo "Executing: [$command]"
  $command 
  
  command="sudo firewall-cmd --permanent --zone=public --add-service=mountd"
  echo "Executing: [$command]"
  $command 
  
  command="sudo firewall-cmd --permanent --zone=public --add-service=rpc-bind"
  echo "Executing: [$command]"
  $command 
  
  command="sudo firewall-cmd --reload"
  echo "Executing: [$command]"
  $command      
}


#==================================================================================================================
#
#==================================================================================================================
centos_install_virtualbox()
{
  sudo dnf config-manager --add-repo=https://download.virtualbox.org/virtualbox/rpm/el/virtualbox.repo
  sudo rpm --import https://www.virtualbox.org/download/oracle_vbox.asc
  sudo dnf search virtualbox
  sudo dnf install VirtualBox-6.1.x86_64
}

#==================================================================================================================
#
#==================================================================================================================
centos_provision_ovs_build()
{
  local command=""

  command="sudo yum install make gcc curl wget"
  echo "Executing: [$command]"
  $command  
  
  command="sudo yum install vim openssl-devel autoconf automake"
  echo "Executing: [$command]"
  $command

  command="sudo yum install rpm-build libtool redhat-rpm-config"
  echo "Executing: [$command]"
  $command  

  command="sudo yum install python-devel openssl-devel kernel-devel kernel-debug-devel"
  echo "Executing: [$command]"
  $command  
}

# Display ovs helper "menu"
ovs_show_menu






