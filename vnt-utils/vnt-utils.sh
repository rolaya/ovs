#!/bin/sh

# Generic/common UI utils
source "ui-utils.sh"

###################################################################################################################
# Common global utils file.
g_common_config_file="common-utils.sh"
###################################################################################################################

###################################################################################################################
# The global OVS configuration file.
g_ovs_config_file="ovs-utils.sh"
###################################################################################################################

###################################################################################################################
# The global KVM configuration file.
g_kvm_config_file="kvm-utils.sh"
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
  show_menu_option "vnt_node_list            " " - VNT node list"
  show_menu_option "vnt_node_start           " " - VNT node start"
  show_menu_option "vnt_node_shutdown        " " - VNT node shutdown"
  show_menu_option "vnt_node_get_latency     " " - VNT node get latency"
  show_menu_option "vnt_node_set_latency     " " - VNT node set latency"
  show_menu_option "vnt_node_del_latency     " " - VNT node delete latency"

  show_menu_option "vnt_node_get_max_rate    " " - VNT node get max rate"
  show_menu_option "vnt_node_set_max_rate    " " - VNT node set max rate"
  show_menu_option "vnt_node_del_max_rate    " " - VNT node delete max rate"

  show_menu_option "vnt_node_get_packet_loss " " - VNT node get packet loss"
  show_menu_option "vnt_node_set_packet_loss " " - VNT node set packet loss"
  show_menu_option "vnt_node_del_packet_loss " " - VNT node delete packet loss"
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
vnt_node_start()
{
  local kvm=$1

  message "Starting VNT node: [$kvm]"
  
  kvm_start $kvm
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
  local port=-1
  local qos_config=""
  
  message "kvm: [$kvm] set latency: [$loss]"

  # Get current qos information for the given kvm
  port_get_qos_info $kvm

  # "linux-netem" qos?
  if [[ "$g_qos_info_type" = "linux-netem" ]]; then  

    # Update latency (in microsecs).
    ovs_port_qos_netem_update "add" "latency" $latency

  else
  
    # Get port number from vm name
    vm_name_to_port_number $kvm port

    # Format other_config field (something like "other-config:latency:200000").
    qos_config="other-config:latency=$latency"

    # Add/create linux-netem (latency)
    ovs_port_qos_netem_add $port $qos_config
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

  # Get port name and number given kvm name
  vm_name_to_port_name $kvm pname
  vm_name_to_port_number $kvm pnumber

  message "deleting latency from kvm: [$kvm] port: [$pname/$pnumber]..."

  # Get port latency (if any)
  vnt_node_get_latency $kvm current_latency

  # Get port packet loss (if any)
  vnt_node_get_packet_loss $kvm current_loss

  # Latency configured?
  if [[ $current_latency != -1 ]]; then
    
    # Delete all netem
    ovs_port_qos_netem_delete $pname

    # Packet loss configured, we want to keep this?
    if [[ $current_loss != -1 ]]; then

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
vnt_node_set_max_rate()
{
  local kvm=$1
  local max_rate=$2
  local port=0
  local queue_number=0;

  # Get port number from vm name
  vm_name_to_port_number $kvm port

  # Construct the unique queue id for the kvm/linux-htb
  queue_number=${map_qos_type_params_partition["linux-htb"]}
  queue_number=$((queue_number+port))
  
  # Get queue uuid (if any) associated with the kvm (max-rate information)
  ovs_port_find_qos_queue_record $port $queue_number

  # max-rate qos configured for port/kvm?
  if [[ "$g_qos_queue_record_uuid" = "" ]]; then

    # Create max-rate qos for kvm
    ovs_port_qos_max_rate_add $port $max_rate

  else

    # Update max-rate qos for kvm
    ovs_port_qos_max_rate_update $port $max_rate
  fi 
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_node_del_max_rate()
{
  local kvm_name=$1
  local pname=""
  local pnumber=-1
  local command=""

  message "kvm: [$kvm_name] delete max-rate..."

  # Update ovs tables
  ovs_table_qos_item_queues_update $kvm_name

  # Given kvm name gets its port name
  vm_name_to_port_name $kvm_name pname

  # Given kvm name gets its port number
  vm_name_to_port_number $kvm_name pnumber

  command=`sudo ovs-ofctl del-flows br0 "in_port=$pnumber"`
  echo "excuting: [$command]"
  $comman

  command=`sudo ovs-ofctl del-flows br0 "in_port=$pname"`
  echo "excuting: [$command]"
  $comman
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_node_set_packet_loss()
{
  local kvm=$1
  local loss=$2
  local pname=""
  local port=-1
  local qos_config=""

  message "kvm: [$kvm] set packet loss: [$loss]"

  # Get current qos information for the given kvm
  port_get_qos_info $kvm

  # "linux-netem" qos?
  if [[ "$g_qos_info_type" = "linux-netem" ]]; then  

    # Update latency (in microsecs).
    ovs_port_qos_netem_update "add" "loss" $loss

  else
  
    # Get port number from vm name
    vm_name_to_port_number $kvm port

    # Format other_config field (something like "other-config:loss:30").
    qos_config="other-config:loss=$loss"

    # Add/create linux-netem (latency)
    ovs_port_qos_netem_add $port $qos_config
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

  # Get port name and number given kvm name
  vm_name_to_port_name $kvm pname
  vm_name_to_port_number $kvm pnumber

  message "deleting packet loss from kvm: [$kvm] port: [$pname/$pnumber]..."

  # Get port latency (if any)
  vnt_node_get_latency $kvm current_latency

  # Get port packet loss (if any)
  vnt_node_get_packet_loss $kvm current_loss

  # Packet loss configured?
  if [[ $current_loss != -1 ]]; then
    
    # Delete all netem
    ovs_port_qos_netem_delete $pname

    # Latency configured, we want to keep this?
    if [[ $current_latency != -1 ]]; then

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
  local pattern="s/latency=//g"
  local latency=-1
  local other_config_info=""

  # Get qos information for the node
  port_get_qos_info $kvm

  # Qos configuired and is it linux-netem?
  if [[ "$g_qos_info_type" = "linux-netem" ]]; then  

    # Given something like "latency=100000", extract value (i.e. "100000")
    other_config_info="$(echo "$g_qos_info_other_config" | grep "latency" | sed "$pattern")"

    # Node configured for latency?
    if [[ "$other_config_info" != "" ]]; then  

      # other_config configuration items are separated by IFS
      IFS=',' read -ra  g_qos_info_other_config_array <<< "$g_qos_info_other_config"

      # Get latency (if any) 
      array_list_items_find "latency" latency

      echo "current latency: [$latency]"
    fi
  fi

  message "kvm: [$kvm] latency: [$latency]..."

  # return info to caller
  eval "$2='$latency'"
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_node_get_packet_loss()
{
  local kvm=$1
  local pattern="s/loss=//g"
  local packet_loss=-1
  local other_config_info=""
  
  # Get qos information for the node
  port_get_qos_info $kvm

  # Qos configuired and is it linux-netem?
  if [[ "$g_qos_info_type" = "linux-netem" ]]; then  

    # Given something like "loss=30", extract value (i.e. "30")
    other_config_info="$(echo "$g_qos_info_other_config" | grep "loss" | sed "$pattern")"

    # Node configured for packet loss?
    if [[ "$other_config_info" != "" ]]; then  

      # other_config configuration items are separated by IFS
      IFS=',' read -ra  g_qos_info_other_config_array <<< "$g_qos_info_other_config"

      # Get packet loss (if any) 
      array_list_items_find "loss" packet_loss

      echo "current packet loss: [$packet_loss]"
    fi
  fi

  eval "$2='$packet_loss'"
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_node_get_qos_netem()
{
  local kvm=$1
  
  g_qos_info_other_config_array=""

  # Get qos information for the node
  port_get_qos_info $kvm

  # Qos linux-netem?
  if [[ "$g_qos_info_type" = "linux-netem" ]]; then  

    # "other_config" configuration items are separated by IFS
    IFS=',' read -ra  g_qos_info_other_config_array <<< "$g_qos_info_other_config"

    # List netem configuration
    other_config_array_list_items
  fi
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_switch_del_qos()
{
  local uuid=""
  local pname=""
  local kvm_name=""
  local qos_uuid=""

  # For now (regardless of configuration) "purge" all qos.
  for ((i = $VM_NAME_INDEX_BASE; i < $NUMBER_OF_VMS; i++)) do
    kvm_name="kvm-vnt-node$i"
    vnt_node_del_latency $kvm_name
  done

  for ((i = $VM_NAME_INDEX_BASE; i < $NUMBER_OF_VMS; i++)) do
    kvm_name="kvm-vnt-node$i"
    vnt_node_del_packet_loss $kvm_name
  done

   for ((i = $VM_NAME_INDEX_BASE; i < $NUMBER_OF_VMS; i++)) do
    kvm_name="kvm-vnt-node$i"
    vnt_node_del_max_rate $kvm_name
  done 

  ovs_table_clear_values "port" "qos" "name=$HOST_NETIFACE_NAME"
  
  for ((i = $VM_NAME_INDEX_BASE; i < $NUMBER_OF_VMS; i++)) do

    kvm_name="kvm-vnt-node$i"

    vm_name_to_port_name $kvm_name pname

    # ...
    condition="name=$pname"
    ovs_table_clear_values "port" "qos" "$condition"

  done

  # Get all record uuids from qos table
  ovs_table_get_records_uuid "qos"

  # Purge all records from qos table
  ovs_table_purge_records "qos"
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
  # Source common helpers
  source "$g_common_config_file"

  # Source OVS helpers
  source "$g_ovs_config_file"

  # Source KVM helpers
  source "$g_kvm_config_file"
}

# Capture time when file was sourced 
g_sourced_datetime="$(date +%c)"

# Provision environment based on configuration file
vnt_read_configuration

# Display helper "menu"
vnt_utils_show_menu
