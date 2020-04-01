#!/bin/sh

###################################################################################################################
# Common global utils file.
g_common_utils_config_file="common-utils.sh"
###################################################################################################################

###################################################################################################################
# The global OVS configuration file.
g_ovs_utils_config_file="ovs-utils.sh"
###################################################################################################################

###################################################################################################################
# The global KVM configuration file.
g_kvm_utils_config_file="kvm-utils.sh"
###################################################################################################################

#==================================================================================================================
#
#==================================================================================================================
vnt_utils_show_menu()
{
  local datetime=""
  local first_vm="1"

  # Environment 
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}Environment"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"

  # Get date/time (useful for keeping track of changes)
  datetime="$(date +%c)"

  echo "Host name:                     [$HOSTNAME]"
  echo "Sourced time:                  [$g_sourced_datetime]"
  echo "Current time:                  [$datetime]"

  echo
  echo "Number of KVMs:                [$NUMBER_OF_VMS]"
  echo "KVM base name:                 [$VM_BASE_NAME]"
  echo "KVM range:                     [$VM_BASE_NAME$first_vm..$VM_BASE_NAME$NUMBER_OF_VMS]"
  echo "KVM port range:                [$OVS_PORT_NAME_BASE$OVS_PORT_INDEX_BASE..$OVS_PORT_NAME_BASE$((NUMBER_OF_VMS-1))]"
  echo

  # KVM guest (VNT network node) deployment
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}KVM guest management"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"
  show_menu_option "vnt_node_list              " " - VNT node list"
  show_menu_option "vnt_nodes_start            " " - VNT nodes start"
  show_menu_option "vnt_nodes_shutdown         " " - VNT nodes shutdown"
  show_menu_option "vnt_nodes_show_ip_address  " " - VNT nodes show management interface ip address"
  show_menu_option "vnt_node_start             " " - VNT node start"
  show_menu_option "vnt_node_start_headless    " " - VNT node start"
  show_menu_option "vnt_node_shutdown          " " - VNT node shutdown"
  show_menu_option "vnt_node_get_latency       " " - VNT node get latency"
  show_menu_option "vnt_node_set_latency       " " - VNT node set latency"
  show_menu_option "vnt_node_del_latency       " " - VNT node delete latency"

  show_menu_option "vnt_node_get_max_rate      " " - VNT node get max rate"
  show_menu_option "vnt_node_set_max_rate      " " - VNT node set max rate"
  show_menu_option "vnt_node_del_max_rate      " " - VNT node delete max rate"

  show_menu_option "vnt_node_get_packet_loss   " " - VNT node get packet loss"
  show_menu_option "vnt_node_set_packet_loss   " " - VNT node set packet loss"
  show_menu_option "vnt_node_del_packet_loss   " " - VNT node delete packet loss"
  show_menu_option "vnt_mcast_snooping_enable  " " - VNT multicast snooping enable"
  show_menu_option "vnt_mcast_snooping_disable " " - VNT multicast snooping disable"


  #show_menu_option "vnt_node_htb_get_max_rate " " - VNT node get max rate"
  #show_menu_option "vnt_node_htb_set_max_rate " " - VNT node set max rate"
  #show_menu_option "vnt_node_htb_del_max_rate " " - VNT node delete max rate"

  echo

  note_init "Set qos usage:"
  note_add  "vnt_node_set_latency kvm-vnt-node1 100000 (sets 100ms delay)"
  note_add  "vnt_node_set_packet_loss kvm-vnt-node1 30 (sets 30% packet loss)"
  note_add  "vnt_node_set_max_rate kvm-vnt-node1 10000000 (sets 10Mbit/sec rate)"
  echo

  note_init "Get qos usage (-1 indicates specific qos is not configured):"
  note_add  "vnt_node_get_latency kvm-vnt-node1"
  note_add  "vnt_node_get_packet_loss kvm-vnt-node1"
  note_add  "vnt_node_get_max_rate kvm-vnt-node1"
  echo

  note_init "Delete qos usage"
  note_add  "vnt_node_del_latency kvm-vnt-node1"
  note_add  "vnt_node_del_packet_loss kvm-vnt-node1"
  note_add  "vnt_node_del_max_rate kvm-vnt-node1"
  echo

  #show_menu_option "vnt_switch_del_qos       " " - VNT switch delete qos"
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_node_list()
{
  kvm_list
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_nodes_start()
{
  local kvm=""

  message "Starting [$NUMBER_OF_VMS] VNT vms..."
  
  for ((i = $VM_NAME_INDEX_BASE; i <= $NUMBER_OF_VMS; i++)) do

    kvm="$VM_BASE_NAME$i"

    # Start KVM (without a console)
    kvm_start_headless $kvm

  done
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_nodes_shutdown()
{
  local kvm=""

  message "Shutting down [$NUMBER_OF_VMS] VNT vms..."
  
  for ((i = $VM_NAME_INDEX_BASE; i <= $NUMBER_OF_VMS; i++)) do

    kvm="$VM_BASE_NAME$i"

    # Stop KVM
    kvm_shutdown $kvm

  done
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_nodes_show_ip_address()
{
  local kvm=""
  local ipaddr=""

  message "Discovering kvms management interface ip address..."
  
  for ((i = $VM_NAME_INDEX_BASE; i <= $NUMBER_OF_VMS; i++)) do

    kvm="$VM_BASE_NAME$i"

    # Get KVM IP address (of management interface)
    kvm_get_ip_address $kvm $KVM_NETWORK_MGMT ipaddr

    message "kvm: [$kvm] ip address: [$ipaddr]" "$TEXT_VIEW_NORMAL_GREEN"

  done
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_node_ssh()
{
  local kvm=$1
  local user=${2:-"$VM_USER_NAME"}
  local ipaddr=""

  # Get KVM IP address (of management interface)
  kvm_get_ip_address $kvm $KVM_NETWORK_MGMT ipaddr

  message "SSHing as [$user] into [$kvm] via ip: [$ipaddr]..."

  # SSH into kvm
  ssh $user@$ipaddr
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_node_start()
{
  local kvm=$1

  message "Starting VNT node: [$kvm]"
  
  kvm_start $kvm
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_node_start_headless()
{
  local kvm=$1

  message "Starting VNT node: [$kvm]"
  
  kvm_start_headless $kvm
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_node_shutdown()
{
  local command=""
  local kvm=$1

  kvm_shutdown $kvm
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_node_set_latency()
{
  local kvm=$1
  local latency=$2
  local pname=""
  local pnumber=-1
  local qos_config=""
  
  message "kvm: [$kvm] set latency: [$latency]" "$TEXT_VIEW_NORMAL_RED"

  # Get current qos information for the given kvm
  vnt_node_get_qos_info $kvm

  # Port number was derived above, save it
  pnumber=$g_qos_info_port_number

  # "linux-netem" qos?
  if [[ "$g_qos_info_type" = "linux-netem" ]]; then  

    # Update latency (in microsecs).
    ovs_port_qos_netem_update "add" "latency" $latency

  else
  
    # Format other_config field (something like "other-config:latency:200000").
    qos_config="other-config:latency=$latency"

    # Add/create linux-netem (latency)
    ovs_port_qos_netem_add $pnumber $qos_config
  fi
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_node_del_latency()
{
  local kvm=$1
  local pnane=""
  local pnumber=-1
  local qos_config=""
  local current_loss=-1
  local current_latency=-1
  local keep_other_config=${2:-"true"}

  # Get port name and number given kvm name
  vm_name_to_port_name $kvm pname
  vm_name_to_port_number $kvm pnumber

  if [[ $keep_other_config != "true" ]] && [[ $keep_other_config != "false" ]]; then
    keep_other_config="true"
  fi

  message "Deleting latency from kvm: [$kvm] port: [$pname] keep other config: [$keep_other_config]..." "$TEXT_VIEW_NORMAL_RED"

  # Get port latency (if any)
  vnt_node_get_latency $kvm current_latency

  # Get port packet loss (if any)
  vnt_node_get_packet_loss $kvm current_loss

  # Latency configured?
  if [[ $current_latency != -1 ]]; then
    
    # Delete all netem
    ovs_port_qos_netem_delete $pname

    # Packet loss configured, we want to keep this?
    if [[ $keep_other_config == "true" ]] && [[ $current_loss != -1 ]]; then

      # Format other_config field (something like "other-config:loss:30").
      qos_config="other-config:loss=$current_loss"

      # Add/create linux-netem (loss)
      ovs_port_qos_netem_add $pnumber $qos_config
    fi
  fi
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_node_htb_get_max_rate()
{
  local kvm=$1
  local max_rate=-1
  
  message "Get max-rate for kvm: [$kvm]..." "$TEXT_VIEW_NORMAL_RED"

  # Get qos information for the node
  vnt_node_get_qos_info $kvm

  # Get max-rate (if any) 
  array_list_items_find "max-rate" max_rate "${g_qos_info_other_config_array[@]}" 

  eval "$2='$max_rate'"
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_node_htb_set_max_rate()
{
  local kvm=$1
  local max_rate=$2
  local pnumber=-1
  local queue_number=0;

  message "kvm: [$kvm] set max-rate: [$max_rate]..." "$TEXT_VIEW_NORMAL_RED"

  # Get port number from vm name
  vm_name_to_port_number $kvm pnumber

  # Construct the unique queue id for the kvm/linux-htb
  queue_number=${map_qos_type_params_partition["linux-htb"]}
  queue_number=$((queue_number+pnumber))
  
  # Get queue uuid (if any) associated with the kvm (max-rate information)
  ovs_port_find_qos_queue_record $pnumber $queue_number

  # max-rate qos configured for port/kvm?
  if [[ "$g_qos_queue_record_uuid" = "" ]]; then

    # Create max-rate qos for kvm
    ovs_port_qos_max_rate_add $pnumber $max_rate

  else

    # Update max-rate qos for kvm
    ovs_port_qos_max_rate_update $pnumber $max_rate
  fi 
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_node_htb_del_max_rate()
{
  local kvm_name=$1
  local pname=""
  local pnumber=-1
  local command=""

  message "kvm: [$kvm_name] delete max-rate..." "$TEXT_VIEW_NORMAL_RED"

  # Update ovs tables
  ovs_table_qos_item_queues_update $kvm_name

  # Given kvm name gets its port name
  vm_name_to_port_name $kvm_name pname

  # Given kvm name gets its port number
  vm_name_to_port_number $kvm_name pnumber

  command=`sudo ovs-ofctl del-flows br0 "in_port=$pnumber"`
  echo "excuting: [$command]"
  $command

  command=`sudo ovs-ofctl del-flows br0 "in_port=$pname"`
  echo "excuting: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_node_get_max_rate()
{
  local kvm=$1
  local maxrate=-1
  
  # Get qos information for the node
  vnt_node_get_qos_info $kvm

  # Get ingress policing rate (if any) 
  array_list_items_find "ingress_policing_rate" maxrate "${g_qos_ingress_policing_config_array[@]}"

  if [[ $maxrate > 0 ]]; then
    # Convert to mbps bps
    maxrate=$((maxrate*1000))
  else
    # To keep interface consistent across qos get, return -1 to indicate max-rate is not set
    maxrate=-1
  fi

  message "kvm: [$kvm] max-rate: [$maxrate]..." "$TEXT_VIEW_NORMAL_RED"

  eval "$2='$maxrate'"
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_node_set_max_rate()
{
  local kvm=$1
  local max_rate=$2
  local pnumber=-1
  local current_max_rate=-1

  message "kvm: [$kvm] set ingress policing rate: [$max_rate]..." "$TEXT_VIEW_NORMAL_RED"

  # Get port name from vm name
  vm_name_to_port_name $kvm pnumber

  # Get current max rate
  vnt_node_get_max_rate $kvm current_max_rate

  if [[ $current_max_rate != -1 ]]; then
    # Update max-rate qos for kvm
    ovs_port_qos_ingress_update $pnumber $max_rate
  else
    # Create ingress policing rate
    ovs_port_qos_ingress_create $pnumber $max_rate
  fi
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_node_del_max_rate()
{
  local kvm=$1
  local pname=""
  local command=""
  local rate=-1

  # Get port name given kvm name
  vm_name_to_port_name $kvm pname

  message "kvm: [$kvm/$pname] delete ingress policing rate..." "$TEXT_VIEW_NORMAL_RED"

  # Get port packet loss (if any)
  vnt_node_get_max_rate $kvm rate

  # Ingress policing rate configured?
  if [[ $rate != -1 ]]; then
    
    # Delete ingress policing rate from interface
    ovs_port_qos_ingress_policing_rate_delete $pname
  fi
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_node_set_packet_loss()
{
  local kvm=$1
  local loss=$2
  local pname=""
  local pnumber=-1
  local qos_config=""

  message "kvm: [$kvm] set packet loss: [$loss]" "$TEXT_VIEW_NORMAL_RED"

  # Get current qos information for the given kvm
  vnt_node_get_qos_info $kvm

  # Port number was derived above, save it
  pnumber=$g_qos_info_port_number

  # "linux-netem" qos?
  if [[ "$g_qos_info_type" = "linux-netem" ]]; then  

    # Update latency (in microsecs).
    ovs_port_qos_netem_update "add" "loss" $loss

  else
  
    # Format other_config field (something like "other-config:loss:30").
    qos_config="other-config:loss=$loss"

    # Add/create linux-netem (latency)
    ovs_port_qos_netem_add $pnumber $qos_config
  fi
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_node_del_packet_loss()
{
  local kvm=$1
  local pnane=""
  local pnumber=-1
  local qos_config=""
  local current_loss=-1
  local current_latency=-1
  local keep_other_config=${2:-"true"}

  # Get port name and number given kvm name
  vm_name_to_port_name $kvm pname
  vm_name_to_port_number $kvm pnumber

  if [[ $keep_other_config != "true" ]] && [[ $keep_other_config != "false" ]]; then
    keep_other_config="true"
  fi
  
  message "deleting packet loss from kvm: [$kvm] port: [$pname] keep other config: [$keep_other_config]..." "$TEXT_VIEW_NORMAL_RED"

  # Get port latency (if any)
  vnt_node_get_latency $kvm current_latency

  # Get port packet loss (if any)
  vnt_node_get_packet_loss $kvm current_loss

  # Packet loss configured?
  if [[ $current_loss != -1 ]]; then
    
    # Delete all netem
    ovs_port_qos_netem_delete $pname

    # Latency configured, we want to keep this?
    if [[ $keep_other_config == "true" ]] && [[ $current_latency != -1 ]]; then

      # Format other_config field (something like "other-config:latency:100000").
      qos_config="other-config:latency=$current_latency"

      # Add/create linux-netem (packet latency)
      ovs_port_qos_netem_add $pnumber $qos_config
    fi
  fi
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_node_get_latency()
{
  local kvm=$1
  local latency=-1

  message "Get latency for kvm: [$kvm]..." "$TEXT_VIEW_NORMAL_RED"

  # Get qos information for the node
  vnt_node_get_qos_info $kvm

  # Get latency (if any) 
  array_list_items_find "latency" latency "${g_qos_info_other_config_array[@]}" 

  # return info to caller
  eval "$2='$latency'"
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_node_get_packet_loss()
{
  local kvm=$1
  local packet_loss=-1
  
  message "Get packet loss for kvm: [$kvm]..." "$TEXT_VIEW_NORMAL_RED"

  # Get qos information for the node
  vnt_node_get_qos_info $kvm

  # Get packet loss (if any) 
  array_list_items_find "loss" packet_loss "${g_qos_info_other_config_array[@]}" 

  eval "$2='$packet_loss'"
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_mcast_snooping_enable()
{
  ovs_multicast_snooping_enable
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_mcast_snooping_disable()
{
  ovs_multicast_snooping_disable
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_switch_del_qos()
{
  # Reset "qos" field from every "port" in the system
  ovs_port_table_clear_qos

  # Reset "queues" from every "qos" in the system
  ovs_qos_table_clear_queues

  # Reset "interface" table qos ("ingress_policing_rate")
  ovs_interface_table_reset_ingress_policing

  # Purge all records from "queue" table
  ovs_table_purge_records "queue"

  # Purge all records from "qos" table
  ovs_table_purge_records "qos"
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_table_clear_value()
{
  local table=$1
  local uuid=$2
  local column=$3

  ovs_table_clear_column_values $table $uuid $column
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_table_clear_values()
{
  local table=$1
  local column=$2
  local condition=$3
  local uuid=""
  local column_value=""

  message "clearing values: table: [$table] column: [$column] condition: [$condition]"
  
  # Find record given condition
  ovs_table_find_record $table $condition uuid

  # QoS configured?
  if [[ "$uuid" != "" ]]; then

    # Get qos uuid associated with port
    ovs_table_get_value $table $uuid $column column_value

      # QoS configured?
    if [[ "$column_value" != "" ]]; then 
      ovs_table_clear_column_values $table $uuid $column
    fi
  fi
}

#==================================================================================================================
#
#=================================================================================================================
function vnt_read_configuration()
{
  # Generic/common UI utils
  source "ui-utils.sh"
  
  # Source common helpers
  source "$g_common_utils_config_file"

  # Source OVS helpers
  source "$g_ovs_utils_config_file"

  # Source KVM helpers
  source "$g_kvm_utils_config_file"
}

# Executing form bash console?
if [[ "$CONSOLE_MODE" == "true" ]]; then

  # Capture time when file was sourced 
  g_sourced_datetime="$(date +%c)"

  # Provision environment based on configuration file
  vnt_read_configuration

  if [[ "$DISPLAY_API_MENUS" == "true" ]]; then

    # Display helper "menu"
    vnt_utils_show_menu
  fi
fi
