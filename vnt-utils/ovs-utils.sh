#!/bin/sh

#set -x			# activate debugging from here

# The network interface configuration file. Modify as per host.
g_net_iface_config_file="config.env.net-iface"

# The VNT configuration file. Modify VNT configuration
g_vnt_config_file="config.env.vnt"

# VirtualBox looks at this as the network name
network_name=$OVS_PORT_NAME_BASE

# This determines if we are going to use DHCP or static IP address for the host.
# Node: the guests can use either (but are configured for static ip).
use_dhcp="False"

# Traffic shaping specific definitions

# Define some default qos values (update as per required configuration)
# Max rate: 10Gbit/sec (network specific), no latency, no packet loss
qos_default_max_rate=10000000000
qos_default_latency=1000000
qos_default_packet_loss=0

# Array of openvswitch tables (incomplete)
declare -a ovs_tables_array=("Open_vSwitch" "Interface" "Bridge" "Port" "QoS" "Queue" "Flow_Table" "sFlow" "NetFlow" "Datapath")

global_qos_queues_list=""

# We are going to use an array to "partition" the qos queue types numbering.
# This needs to be modified when support for new qos types is added to this
# script. This is a global definition used by misc. functions.
declare -A map_qos_type_params_partition
map_qos_type_params_partition["linux-htb"]=100
map_qos_type_params_partition["linux-netem"]=400

# Gloabal parameters related to qos (ovs internal) configuration
g_qos_queue_number=0
g_qos_ofport_request=0
g_qos_queue_record_uuid=""

# Capture time when file was sourced 
g_sourced_datetime="$(date +%c)"

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
  port_name_sample=$OVS_PORT_NAME_BASE
  port_name_sample+="1"

  vm_name_sample=$VM_BASE_NAME
  vm_name_sample+="1"

  # Environment 
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}Environment"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"

  # Get date/time (useful for keeping track of changes)
  datetime="$(date +%c)"

  echo "VNT configuration file:           [$g_vnt_config_file]"
  echo "Network iface configuration file: [$g_net_iface_config_file]"
  echo "Host name:                        [$HOSTNAME]"
  echo "Sourced time:                     [$g_sourced_datetime]"
  echo "Current time:                     [$datetime]"
  echo "Using DHCP for host's IP:         [$use_dhcp]"
  echo "Network interface:                [$HOST_NETIFACE_NAME]"
  echo "Network interface IP address:     [$HOST_NETIFACE_IP]"
  echo "Default gateway IP address:       [$GATEWAY_IP]"
  echo "OVS bridge name:                  [$OVS_BRIDGE]"
  echo "Tap port interface name:          [$OVS_PORT_NAME_BASE]"
  echo "Tap port interface index:         [$OVS_PORT_INDEX_BASE]"
  echo "Number of VMs in testbed:         [$NUMBER_OF_VMS]"
  echo "VM base name:                     [$VM_BASE_NAME]"
  echo "VM range:                         [$VM_BASE_NAME$first_vm..$VM_BASE_NAME$NUMBER_OF_VMS]"
  echo "VM port range:                    [$OVS_PORT_NAME_BASE$OVS_PORT_INDEX_BASE..$OVS_PORT_NAME_BASE$((NUMBER_OF_VMS-1))]"
  echo "Attach VM(s) to vSwitch:          [$ATTACH_VMS_TO_VSWITCH]"
  echo "Auto start VM(s):                 [$AUTO_START_VMS]"

  echo

  # Deployment
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}Deployment"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"
  show_menu_option "ovs_start                        " " - Start OVS daemons (must be executed as root)"
  show_menu_option "deploy_network                   " " - Deploy network configuration and launch VMs"
  echo

   # Traffic shaping
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}Traffic shaping"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"
  show_menu_option "ovs_port_qos_max_rate_add        " " - set port bandwidth (mbps)"
  show_menu_option "                                 " "   usage:   ovs_port_qos_max_rate_add port_number bandwidth"
  show_menu_option "                                 " "   example: ovs_port_qos_max_rate_add 1 1000000"
  show_menu_option "ovs_port_qos_max_rate_update     " " - update port bandwidth (mbps)"
  show_menu_option "                                 " "   usage:   ovs_port_qos_max_rate_update port_number bandwidth"
  show_menu_option "                                 " "   example: ovs_port_qos_max_rate_update 1 500000"
  show_menu_option "ovs_port_qos_netem_add           " " - set port latency (microseconds)"
  show_menu_option "                                 " "   usage:   ovs_port_qos_netem_add port_number latency"
  show_menu_option "                                 " "   example: ovs_port_qos_netem_add 1 500000"
  show_menu_option "ovs_port_qos_netem_update        " " - update netem qos (latency/packet loss)"
  show_menu_option "                                 " "   usage:   ovs_port_qos_packet_loss_update port_number packet_loss"
  show_menu_option "                                 " "   example: ovs_port_qos_packet_loss_update 1 30"

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
  local port=${2:-$OVS_PORT_NAME_BASE}
  
  echo "Adding ports to bridge $bridge..."

  # Create a tap interface(s) for VMs 1-6 (and add interface to "br0" bridge).
  for ((i = $OVS_PORT_INDEX_BASE; i < $NUMBER_OF_VMS; i++)) do
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
  command="sudo ovs-vsctl add-br $OVS_BRIDGE"
  echo "executing: [$command]..."
  $command
  
  # Activate "br0" device 
  command="sudo ip link set $OVS_BRIDGE up"
  echo "executing: [$command]..."
  $command

  # Add network device "enp5s0" to "br0" bridge. Device "enp5s0" is the
  # name of the actual physical wired network interface. In some devices
  # it may be eth0.
  command="sudo ovs-vsctl add-port $OVS_BRIDGE $HOST_NETIFACE_NAME"
  echo "executing: [$command]..."
  $command
  
  # Delete assigned ip address from "enp5s0" device/interface. This address 
  # was provided (served) by the DHCP server (in the local network).
  # For simplicity, I configured my verizon router to always assign this
  # ip address (192.168.1.206) to "this" host (i.e. the host where I am 
  # deploying ovs).
  command="sudo ip addr del $HOST_NETIFACE_IP/24 dev $HOST_NETIFACE_NAME"
  echo "executing: [$command]..."
  $command

  # Using DHCP?
  if [[ "$use_dhcp" = "True" ]]; then
    # Acquire ip address and assign it to the "br0" bridge/interface
    command="sudo dhclient $OVS_BRIDGE"
    echo "executing: [$command]..."
    $command
  else
    # Add (move) the wired interface ip address to the bridge interface
    command="sudo ip addr add $HOST_NETIFACE_IP/24 dev $OVS_BRIDGE"
    echo "executing: [$command]..."
    $command

    # Add static route to allow access to hosts outside the local subnet
    command="sudo route add default gw $GATEWAY_IP $OVS_BRIDGE"
    echo "executing: [$command]..."
    $command
  fi

  if [[ "$ADD_PORTS_TO_VSWITCH" = true ]]; then
    # Create tap interface(s) for VMs 1-6 (and add interface to "br0" bridge).
    command="ovs_bridge_add_ports $OVS_BRIDGE"
    echo "executing: [$command]..."
    $command
  else
    msg="Warning [$NUMBER_OF_VMS] ports not attached to switch as per configuration!!!"
    show_warning_msg "$msg" 
  fi
}

#==================================================================================================================
#
#==================================================================================================================
ovs_purge_network_deployment()
{
  local port=${2:-$OVS_PORT_NAME_BASE}

  # "Manually" delete port/interfaces and bridge created via "ovs_deploy_network"
  # Note: it is possible to purge all bridge, etc configuration when starting
  # daemons via command line options (need to try this...).
  for ((i = $OVS_PORT_INDEX_BASE; i < $NUMBER_OF_VMS; i++)) do
    sudo ovs-vsctl del-port $port$i
  done
  
  sudo ovs-vsctl del-br $OVS_BRIDGE
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
  set port $HOST_NETIFACE_NAME qos=@newqos -- \
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
  command="sudo ovs-ofctl add-flow $OVS_BRIDGE in_port=5,actions=set_queue:123,normal"
  echo "excuting: [$command]"
  $command

  command="sudo ovs-ofctl add-flow $OVS_BRIDGE in_port=6,actions=set_queue:234,normal"
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
  set port $HOST_NETIFACE_NAME qos=@newqos1 -- \
  --id=@newqos1 create qos type=linux-htb \
      other-config:max-rate=1000000000 \
      queues:122=@tap_port3_queue -- \
  --id=@tap_port3_queue create queue other-config:max-rate=30000000"
  echo "excuting: [$command]"
  $command
  
  command="sudo ovs-ofctl add-flow $OVS_BRIDGE in_port=7,actions=set_queue:122,normal"
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
  # "qos_id_eth0_vnet0_linux-netem". Ultimately the QoS table
  # record is identified by the record's uuid (something like:
  # bdc3fe06-edcc-419b-80bd-d523a0628aa2).
  temp="qos_id"
  temp+="_$HOST_NETIFACE_NAME"
  temp+="_$interface"
  temp+="_$qos_type"
  eval "$1='$temp'"

  echo "generated qos id: [$temp]"
}

#==================================================================================================================
#
#==================================================================================================================
ovs_port_qos_netem_add()
{
  local port_number=$1
  local qos_config="$2"
  local port_name=""

  # Get port name based on port numbed
  port_number_to_port_name $port_number port_name

  message "Adding qos [$qos_config] to port: [$port_name]:" "$TEXT_VIEW_NORMAL_GREEN"

  # Create netem latency
  ovs_port_qos_netem_create $port_name "$qos_config"
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
ovs_port_qos_max_rate_add()
{
  local port_number=$1
  local port_name=""
  local qos_type=""
  local qos_other_config=""
  local qos_other_config_value=$2

  # Format the port name based on the port base name and port number (something like tab_port1)
  port_name="$OVS_PORT_NAME_BASE$port_number"
  qos_type="linux-htb"
  qos_other_config="max-rate"

  message "port: [$port_name] add max-rate: [$qos_other_config_value]..." "$TEXT_VIEW_NORMAL_GREEN"

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
  local table=""
  local qos=""
  local port_number=0
  local port_name=""

  # Format the "complete" qos type, something like "linux-htm.max-rate"
  qos="$qos_type.$qos_other_config"

  message "Creating qos:"
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
    port_name=$HOST_NETIFACE_NAME

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
    port_number=$(echo "$interface" | sed 's/[^0-9]*//g')

    # Get queue number based on qos type and port number
    ovs_setup_qos_params $qos_type $port_number

    # Update local value
    queue_number=$g_qos_queue_number
    of_port_request=$g_qos_ofport_request

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

      # Convert LF to space (for use as the IFS)
      delimeted_uuids=$(echo "$uuids" | tr '\n' ' ')

      # uuids are separated by IFS
      IFS=' ' read -ra  uuid_array <<< "$delimeted_uuids"
      
      # (for debugging) save the uuid of the qos, queue records
      linux_htb_qos_record_uuid="${uuid_array[0]}"
      linux_htb_queue_record_uuid="${uuid_array[1]}"

      # Format and execute flow command (creates and initializes new record in Queue table)
      command="sudo ovs-ofctl add-flow $OVS_BRIDGE in_port=$of_port_request,actions=set_queue:$queue_number,normal"
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
    echo "bridge:              [$OVS_BRIDGE]"
    echo "port:                [$HOST_NETIFACE_NAME]"
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
#
#==================================================================================================================
ovs_port_qos_ingress_create()
{
  local command=""
  local interface=$1
  local max_rate=$2
  local max_rate_mbps=0

  # Rate expected in Mbps
  max_rate_mbps=$((max_rate/1000))

  message "Creating ingress policing rate:"
  echo "port:          [$interface]"
  echo "max rate:      [$max_rate]"
  echo "max rate:      [$max_rate_mbps]"

  # Configure ingress policing (required for vnt private network max-rate qos)
  command="sudo ovs-vsctl set interface $interface ingress_policing_rate=$max_rate_mbps"
  echo "excuting: [$command]"
  $command
}

#==================================================================================================================
#
#==================================================================================================================
ovs_port_qos_ingress_update()
{
  local port_number=$1
  local port_max_rate=$2

  # Update QoS max rate.
  message "port: [$port_number] update max-rate: [$port_max_rate]..." "$TEXT_VIEW_NORMAL_GREEN"

  # Delete ingress policing rate from interface
  ovs_port_qos_ingress_policing_rate_delete $port_number

  # Create ingress policing rate
  ovs_port_qos_ingress_create $pnumber $max_rate  
}

#==================================================================================================================
# Handles packet loss and latency
#==================================================================================================================
ovs_port_qos_netem_create()
{
  local command=""
  local port_name=$1
  local qos_other_config="$2"
  local qos_id=""
  local table=""
  local qos_type=""
  local qos_uuid=""

  # We use linux-netem for latency and packet loss.
  qos_type="linux-netem"

  message "Creating qos: port: [$port_name] type: [$qos_type] config: [$qos_other_config]"

  # Perform some parameter
  if [[ $# -eq 2 ]]; then

    # Make the qos_id as unique as possible (contains port, interface qos type and other qos config),
    # something like "qos_id_eth0_vnet0_linux-netem"
    qos_id_format qos_id $port_name $qos_type $qos_other_config

    # Format and execute traffic shaping command (creates and initializes a single 
    # qos record). This command returns a uuid "qos" records created. The second 
    # This is the record we update when we want to modify the linux-netem (either
    # latency or packet loss).
    command="sudo ovs-vsctl -- \
    set port $port_name qos=@$qos_id -- \
    --id=@$qos_id create qos type=$qos_type $qos_other_config"
    echo "excuting: [$command]"
    qos_uuid="$($command)"

    echo "Created QoS configuration:"
    echo "Host interface:   [$HOST_NETIFACE_NAME]"
    echo "bridge:           [$OVS_BRIDGE]"
    echo "port:             [$port_name]"
    echo "type:             [$qos_type]"
    echo "config:           [$qos_other_config]"
    echo "qos id:           [$qos_id]"
    echo "qos_uuid:         [$qos_uuid]"

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

  echo "deleting max-rate for port: [$ovs_port]"

  # Insure port is supplied (something like tap_port1)
  if [[ $# -eq 1 ]]; then

    condition="name=$ovs_port"

    # Find record in "port" table whose "name" is the port name supplied by caller.
    ovs_table_find_record $table "$condition" uuid

    if [[ "$uuid" != "" ]]; then

      # Get qos uuid associated with port
      ovs_table_get_value $table $uuid "qos" qos_uuid

      # Clear "qos" field in "port" table
      ovs_table_clear_column_values $table $uuid $column

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

  for ((i = $OVS_PORT_INDEX_BASE; i < $NUMBER_OF_VMS; i++)) do

    port_name="$OVS_PORT_NAME_BASE$i"

    # Delete tap port tap_portx from ovs bridge
    ovs_port_qos_netem_delete $port_name

  done
}

#==================================================================================================================
# Delete all netem configuration
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

  message "deleting port: [$ovs_port] netem..."

  # Insure port is supplied (something like tap_port1)
  if [[ $# -eq 1 ]]; then

    condition="name=$ovs_port"

    # Find record in "port" table whose "name" is the port name supplied by caller.
    ovs_table_find_record $table "$condition" uuid

    if [[ "$uuid" != "" ]]; then

      # Get qos uuid associated with port
      ovs_table_get_value $table $uuid "qos" qos_uuid

      # Clear "qos" field in "port" table
      ovs_table_clear_column_values $table $uuid $column

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
    echo "Usage: ovs_port_qos_netem_delete port (e.g. ovs_port_qos_netem_delete vnet0)..."
  fi
}

#==================================================================================================================
# Delete ingress policing rate configuration
#==================================================================================================================
ovs_port_qos_ingress_policing_rate_delete()
{
  local ovs_port=$1
  local table="interface"
  local condition=""
  local uuid=""
  local column=""
  local value="0"

  message "deleting interface: [$ovs_port] ingress policing rate..."

  # Insure port (interface) is supplied (something like vnet1)
  if [[ $# -eq 1 ]]; then

    condition="name=$ovs_port"

    # Find record in "interface" table.
    ovs_table_find_record $table "$condition" uuid

    if [[ "$uuid" != "" ]]; then

      column="ingress_policing_rate"
      
      # Set the ingress policing rate
      ovs_table_set_value $table $uuid $column $value

    else
      echo -e "${TEXT_VIEW_NORMAL_BLUE}Warning: record [$condition] not found in table: [$table]${TEXT_VIEW_NORMAL}"
    fi

  else
    echo "Usage: ovs_port_qos_ingress_policing_rate_delete port (e.g. ovs_port_qos_ingress_policing_rate_delete vnet0)..."
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
# Updates QoS - netem (packet loss/latency)
#==================================================================================================================
ovs_port_qos_netem_construct()
{
  local command=$1
  local netem_type=$2
  local netem_value=$3
  local netem_current_value=-1
  local netem_qos_latency=""
  local netem_qos_loss=""
  local qos_other_config=""

  # Update netem QoS.
  message "Constructing new linux-netem..."

  echo "kvm name:    [$g_qos_info_kvm_name]"
  echo "port name:   [$g_qos_info_port_name]"
  echo "port number: [$g_qos_info_port_number]"
  echo "netem:       [$netem_type]"
  echo "value:       [$netem_value]"

  # Update qos with latency?
  if [[ $netem_type = "latency" ]]; then

    # Request to add/update netem?
    if [[ $command = "add" ]]; then

      # Format latency configuration
      netem_qos_latency="other-config:$netem_type=$netem_value"

      # Get current packet loss configuration (if any)
      vnt_node_get_packet_loss $g_qos_info_kvm_name netem_current_value

      # Packet loss configured?
      if [[ $netem_current_value != -1 ]]; then
        netem_qos_loss="other-config:loss=$netem_current_value"
      fi

    else

      # Request to delete netem?
      netem_qos_latency=""
    fi

  # Update qos with packet loss?
  elif [[ $netem_type = "loss" ]]; then

    # Request to add/update netem?
    if [[ $command = "add" ]]; then
      
      # Format packet loss configuration
      netem_qos_loss="other-config:$netem_type=$netem_value"
  
      # Get current loss configuration
      vnt_node_get_latency $g_qos_info_kvm_name netem_current_value

      # Latency configured?
      if [[ $netem_current_value != -1 ]]; then
        netem_qos_latency="other-config:latency=$netem_current_value"
      fi

    else

      # Request to delete netem?
      netem_qos_loss=""
    fi
  fi

  qos_other_config="$netem_qos_latency $netem_qos_loss"

  eval "$4='$qos_other_config'"

  echo "netem latency: [$netem_qos_latency]"
  echo "netem loss:    [$netem_qos_loss]"
  echo "qos_config:    [$qos_other_config]"
}

#==================================================================================================================
# Updates QoS - netem (packet loss/latency)
#==================================================================================================================
ovs_port_qos_netem_update()
{
  local command=$1
  local netem_type=$2
  local netem_value=$3
  local kvm_name=""
  local port_name=""
  local port_number=-1
  local qos_type="linux-netem"
  local qos_config=""

  # Update netem QoS.
  message "Updating netem qos..." "$TEXT_VIEW_NORMAL_GREEN"

  # Use "global" information.
  kvm_name="$g_qos_info_kvm_name"
  port_number="$g_qos_info_port_number"
  port_name="$g_qos_info_port_name"

  echo "kvm name:    [$g_qos_info_kvm_name]"
  echo "port name:   [$g_qos_info_port_name]"
  echo "port number: [$g_qos_info_port_number]"
  echo "netem:       [$netem_type]"
  echo "value:       [$netem_value]"
  echo "command:     [$command]"

  # We have some type of netem qos for the kvm, update it using new information.
  ovs_port_qos_netem_construct $command $netem_type $netem_value qos_config

  # Delete qos entry
  ovs_port_qos_netem_delete $port_name

  if [[ "$qos_config" != "" ]]; then

    # Recreate the qos entry with the new value
    ovs_port_qos_netem_add $port_number "$qos_config"
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
  message "port: [$port_number] update max-rate: [$port_max_rate]..." "$TEXT_VIEW_NORMAL_GREEN"

  # Insure uuid and max rate supplied (and max rate is a number)
  if [[ $# -eq 2 ]] && [[ $2 -gt 1 ]]; then

    ovs_setup_qos_params $qos_type $port_number
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
  local port=${2:-$OVS_PORT_NAME_BASE}

  echo "Purging $NUMBER_OF_VMS ports from $bridge bridge..."

  for ((i = $OVS_PORT_INDEX_BASE; i < $NUMBER_OF_VMS; i++)) do

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

  # Remote ports from bridge
  command="ovs_bridge_del_ports $OVS_BRIDGE"
  echo "Executing: [$command]"
  $command

  # Delete physical wired port from ovs bridge
  command="sudo ovs-vsctl del-port $OVS_BRIDGE $HOST_NETIFACE_NAME"
  echo "Executing: [$command]"
  $command

  # Deactivate "br0" device 
  command="sudo ip link set $OVS_BRIDGE down"
  echo "Executing: [$command]"
  $command

  # Delete bridge named "br0" from ovs
  command="sudo ovs-vsctl del-br $OVS_BRIDGE"
  echo "Executing: [$command]"
  $command

  # Bring up physical wired interface
  command="sudo ip link set $HOST_NETIFACE_NAME up"
  echo "Executing: [$command]"
  $command

  if [[ "$use_dhcp" = "True" ]]; then
    # Acquire ip address and assign it to the physical wired interface
    command="sudo dhclient $HOST_NETIFACE_NAME"
    echo "Executing: [$command]"
    $command    
  else
    # Remove static route
    command="sudo route del default"
    echo "executing: [$command]..."
    $command

    # Restore IP address to wired interface
    command="sudo ip addr add $HOST_NETIFACE_IP/24 dev $HOST_NETIFACE_NAME"
    echo "executing: [$command]..."
    $command

    # Add static route to allow access to hosts outside the local subnet
    command="sudo route add default gw $GATEWAY_IP $HOST_NETIFACE_NAME"
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

  for ((i = $OVS_PORT_INDEX_BASE; i < $NUMBER_OF_VMS; i++)) do

    # Set VM network configuration
    vm_set_network_interface $VM_BASE_NAME$i "1" $network_name$i

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
  local vm_name="$VM_BASE_NAME$vm_number"
  local port="$network_name$vm_number"

  echo "Attaching VM: [$vm_name] to bridge: [$OVS_BRIDGE], port: [$port]..."

  # Add port to bridge
  ovs_bridge_add_port $port $OVS_BRIDGE

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
  
  if [[ "$ATTACH_VMS_TO_VSWITCH" = true ]]; then

    # "Attach" VM's network interface to bridge ports
    vms_set_network_interface

    if [[ "$AUTO_START_VMS" = true ]]; then
      
      # Start all VMs in the testbed
      vms_start
    
    else
      msg="Warning [$NUMBER_OF_VMS] VM(s) not started as per configuration!!!"
      show_warning_msg "$msg"
    fi
  else
    msg="Warning [$NUMBER_OF_VMS] VM(s) not attached to switch as per configuration!!!"
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

  for ((i = $VM_NAME_INDEX_BASE; i < $NUMBER_OF_VMS; i++)) do

    # Create QoS record (defaulting to max ethernet rate on each port)
    ovs_port_qos_max_rate_add "$i" $qos_default_max_rate
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
  echo "Launching all VMs in the network..."

  for ((i = $VM_NAME_INDEX_BASE; i <= $NUMBER_OF_VMS; i++)) do

    # Start VM
    vm_start $VM_BASE_NAME$i

  done
}

#==================================================================================================================
# 
#==================================================================================================================
vms_stop()
{
  echo "Powering off all VMs in the network..."

  for ((i = $VM_NAME_INDEX_BASE; i <= $NUMBER_OF_VMS; i++)) do

    # Power off VM
    vm_stop $VM_BASE_NAME$i

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
ovs_table_get_records_uuid()
{
  local table=$1
  local command=""
  local result=""
  local uuids=""
  local index=1
  local pattern="s/_uuid//g"
  local delimeted_uuids=""

  message "Retrieving table: [$table] uuids"

  # Get all records (and all information) in given table
  command="sudo ovs-vsctl list $table"
  echo "Executing: [$command]"
  result="$($command)"
  echo "$result"
  
  # Get uuid value, something like "_uuid               : 151ee65e-87de-4624-8e0c-05b4c30289ca"
  uuids="$(echo "$result" | grep "_uuid")"

  # Remove "_uuid               " from records
  uuids="$(echo "$uuids" | sed "$pattern")"

  # Remove leading space
  pattern="s/^[[:space:]]*//"
  uuids="$(echo "$uuids" | sed "$pattern")"

  # Remove ":"
  pattern="s/: //"
  uuids="$(echo "$uuids" | sed "$pattern")"

  # Convert LF to "," (for use as the IFS)
  delimeted_uuids=$(echo "$uuids" | tr '\n' ',')

  # uuids are separated by IFS
  IFS=',' read -ra  uuid_array <<< "$delimeted_uuids"

  # Display all uuids
  arraylength=${#uuid_array[@]}

  echo "processing: [$arraylength] uuids..."

  for uuid in "${uuid_array[@]}"; do

    uuid=$(echo ${uuid:(-36)})

    echo "uuid[$index]: [$uuid]"

    ((index++))
  done
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_table_purge_records()
{
  local table=$1
  local index=1

  # Get all uuids from given table
  ovs_table_get_records_uuid $table

  # Get number of records to purge from table
  arraylength=${#uuid_array[@]}

  message "Purging: [$arraylength] records from table: [$table]"

  # Purge all records
  for uuid in "${uuid_array[@]}"; do

    uuid=$(echo ${uuid:(-36)})

    echo "uuid[$index]: [$uuid]"

    ovs_table_delete_record $table $uuid

    ((index++))
  done
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_table_uuid_list_display()
{
  local index=1

  # Get number of records
  arraylength=${#uuid_array[@]}

  message "Displaying: [$arraylength] records"

  # Display all records
  for uuid in "${uuid_array[@]}"; do

    uuid=$(echo ${uuid:(-36)})

    echo "uuid[$index]: [$uuid]"

    ((index++))
  done
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_table_list_records()
{
  local table=$1
  local index=0

  # Get all uuids from given table
  ovs_table_get_records_uuid $table

  # Get number of records to purge from table
  arraylength=${#uuid_array[@]}

  message "Listing: [$arraylength] uuid records from table: [$table]"

  # Purge all records
  for uuid in "${uuid_array[@]}"; do

    uuid=$(echo ${uuid:(-36)})

    echo "uuid[$index]: [$uuid]"

    ((index++))
  done
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_qos_table_clear_queues()
{
  local index=0
  local table="qos"
  local field="queues"
  local queues=""

  # Get all uuids from given table
  ovs_table_get_records_uuid $table

  # Get number of records to purge from table
  arraylength=${#uuid_array[@]}

  message "Clearing [$arraylength] $field records from table: [$table]"

  # Purge all records
  for uuid in "${uuid_array[@]}"; do

    uuid=$(echo ${uuid:(-36)})

    ovs_table_get_value $table $uuid $field queues

    echo "uuid[$index]: [$uuid] port: [$queues]"

    # Clear current record's qos field
    ovs_table_clear_value $table $uuid $field

    ((index++))
  done
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_interface_table_reset_ingress_policing()
{
  local index=0
  local table="interface"
  local column="ingress_policing_rate"
  local ingress_policing_rate=""
  local value="0"

  # Get all uuids from given table
  ovs_table_get_records_uuid $table

  # Get number of records to purge from table
  arraylength=${#uuid_array[@]}

  message "Resetting [$arraylength] $field records from table: [$table]"

  # Purge all records
  for uuid in "${uuid_array[@]}"; do

    uuid=$(echo ${uuid:(-36)})

    ovs_table_get_value $table $uuid $column ingress_policing_rate

    echo "uuid[$index]: [$uuid] ingress_policing_rate: [$ingress_policing_rate]"

    # reset current record's ingress_policing_rate field
    ovs_table_set_value $table $uuid $column $value

    ((index++))
  done
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_port_table_clear_qos()
{
  local index=0
  local table="port"
  local pname=""

  # Get all uuids from given table
  ovs_table_get_records_uuid $table

  # Get number of records to purge from table
  arraylength=${#uuid_array[@]}

  message "Clearing [$arraylength] qos records from table: [$table]"

  # Purge all records
  for uuid in "${uuid_array[@]}"; do

    uuid=$(echo ${uuid:(-36)})

    ovs_table_get_value $table $uuid "name" pname

    echo "uuid[$index]: [$uuid] port: [$pname]"

    # Clear current record's qos field
    ovs_table_clear_value $table $uuid "qos"

    ((index++))
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

  command="sudo ovs-ofctl add-flow $OVS_BRIDGE in_port=$in_port,actions=set_queue:$queue,normal"
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

  message "Get [$column] value in table: [$table] with record id: [$record]"

  command="sudo ovs-vsctl get $table $record $column"
  echo "Executing: [$command]"
  value="$($command)"

  if [[ "$value" != "" ]]; then
    echo "table:     [$table]"
    echo "record:    [$record]"
    echo "column:    [$column]"
    echo "raw value: [$value]"
    value=$(echo "$value" | sed 's/{//g')
    value=$(echo "$value" | sed 's/}//g')
    echo "value:     [$value]"
  fi

  eval "$4='$value'"
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_table_set_value()
{
  local command=""
  local table=$1
  local record=$2
  local column=$3
  local value=$4

  echo "Updating column: [$column] to value: [$value] in table: [$table] with record id: [$record]"

  command="sudo ovs-vsctl set $table $record $column=$value"
  echo "Executing: [$command]"
  value="$($command)"
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_table_clear_column_values()
{
  local command=""
  local table=$1
  local record=$2
  local column=$3
  local value=""

  message "Clearing [$column] in table: [$table] for record: [$record]"

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

  message "Deleting record: [$uuid] from table: [$table]"

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
  local index=0
  local uuid_array=""
  local arraylength=0
  local uuids=""
  local record_queue_number=""
  local record_uuid=""

  echo "Find qos queue record uuid for port: [$port_number] queue number: [$queue_number]..."

  # Initialize qos queue record uuid
  g_qos_queue_record_uuid=""

  # Find record in "port" table whose "name" is enp5s0 (the name of our wired ethernet interface).
  table="port"
  condition="name=$HOST_NETIFACE_NAME"
  ovs_table_find_record $table "$condition" uuid

  # Get qos uuid associated with port
  table="port"
  value="qos"
  ovs_table_get_value $table $uuid $value qos_uuid

  # Get list of qos queues uuids (for now, result in global variable)
  table="qos"
  ovs_table_get_list $table $qos_uuid "queues"
  
  # Remove {} from qos_queues_uuid
  uuids=$(echo "$global_qos_queues_list" | sed 's/{//g')
  uuids=$(echo "$uuids" | sed 's/}//g')

  # uuids are separated by IFS
  IFS=' ,' read -ra  uuid_array <<< "$uuids"

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

  echo "Qos queue record uuid for port [$port_number]: [$g_qos_queue_record_uuid]"
}

#==================================================================================================================
#==================================================================================================================
ovs_setup_qos_params()
{
  local qos_type=$1
  local port_number=$2
  local partition_number=0
  local queue_number=0
  local ofport_request=0
  local port_name=""

  # Initialize global, if the qos type is properly provided we will generate
  # a valid qos queue number and ofport request number
  g_qos_queue_number=0
  g_qos_ofport_request=0
  
  # Format the port name (something like tap_port1)
  port_name="$OVS_PORT_NAME_BASE$port_number"

  # The queue number will be the base partition+port number (e.g. for
  # "linux-htb" and port number 1, it will be 101).
  partition_number=${map_qos_type_params_partition["$qos_type"]}

  # QoS type valid?
  if [[ "$partition_number" -gt "0" ]]; then

    # Update global qos queue number
    queue_number=$(($partition_number+$port_number))
    ofport_request=$(($partition_number+$port_number))
    g_qos_queue_number=$queue_number
    g_qos_ofport_request=$ofport_request
    
    echo "Generating queue number   [$g_qos_queue_number] for port: [$port_name] with qos type: [$qos_type]..."
    echo "Generating ofport request [$g_qos_ofport_request] for port: [$port_name] with qos type: [$qos_type]..."

  else
    echo -e "${TEXT_VIEW_NORMAL_RED}Error: Unable to generate qos queue number for qos type: [$qos_type]${TEXT_VIEW_NORMAL}!"
  fi
}

#==================================================================================================================
#==================================================================================================================
ovs_enable_multicast_snooping()
{
  local command=""
  local kname=""
  local pname=""

  # Configure bridge br0 to enable multicast snooping
  message "Configurig bridge $OVS_BRIDGE to enable multicast snooping" "$TEXT_VIEW_NORMAL_GREEN"
  command="sudo ovs-vsctl set Bridge $OVS_BRIDGE mcast_snooping_enable=true"
  echo "Executing: [$command]"
  $command  

  # Set the multicast snooping aging time br0 to 300 seconds
  message "Configuring multicast snooping aging time on $OVS_BRIDGE to 300 seconds" "$TEXT_VIEW_NORMAL_GREEN"
  command="sudo ovs-vsctl set Bridge $OVS_BRIDGE other_config:mcast-snooping-aging-time=300"
  echo "Executing: [$command]"
  $command 

  # Set the multicast snooping table size br0 to 2048 entries
  message "Configuring multicast snooping table size on $OVS_BRIDGE to 2048 entries" "$TEXT_VIEW_NORMAL_GREEN"
  command="sudo ovs-vsctl set Bridge $OVS_BRIDGE other_config:mcast-snooping-table-size=2048"
  echo "Executing: [$command]"
  $command

  # Disable flooding of unregistered multicast packets to all ports
  message "Disabling flooding of unregistered multicast packets to all $OVS_BRIDGE ports" "$TEXT_VIEW_NORMAL_GREEN"
  command="sudo ovs-vsctl set Bridge $OVS_BRIDGE other_config:mcast-snooping-disable-flood-unregistered=true"
  echo "Executing: [$command]"
  $command

  for ((i = 1; i <= $NUMBER_OF_VMS; i++)) do

    # Format kvm name something like kvm-vnt-node1
    kname="$VM_BASE_NAME$i"

    vm_name_to_port_name $kname pname

    ovs_port_enable_multicast_snooping $pname

  done
}

#==================================================================================================================
#==================================================================================================================
ovs_port_enable_multicast_snooping()
{
  local command=""
  local port_name=$1 

  # Enable flooding of multicast packets (except Reports) on a specific port
  message "Enabling flooding of multicast packets (except Reports) on port $port_name" "$TEXT_VIEW_NORMAL_GREEN"
  command="sudo ovs-vsctl set Port $port_name other_config:mcast-snooping-flood=true"
  echo "Executing: [$command]"
  $command  

  # Enable flooding of Reports on a specific port
  message "Enabling flooding of Reports on port $port_name" "$TEXT_VIEW_NORMAL_GREEN"
  command="sudo ovs-vsctl set Port $port_name other_config:mcast-snooping-flood-reports=true"
  echo "Executing: [$command]"
  $command
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

  command="sudo ovs-ofctl add-flow $OVS_BRIDGE in_port=7,actions=set_queue:122,normal"
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

#==================================================================================================================
#
#=================================================================================================================
function provision_environment()
{
  echo "Sourcing configuration file: [$g_net_iface_config_file]"
  echo "Sourcing configuration file: [$g_vnt_config_file]"

  # Source host and environment specific VNT configuration
  source "ui-utils.sh"

  # Source host and environment specific VNT configuration
  source "qos-utils.sh"
  source "$g_net_iface_config_file"
  source "$g_vnt_config_file"
}

# Executing form bash console?
if [[ "$CONSOLE_MODE" == "true" ]]; then

  # Provision environment based on configuration file
  provision_environment

  if [[ "$DISPLAY_API_MENUS" == "true" ]]; then

    # Display ovs helper "menu"
    ovs_show_menu
  fi
fi






