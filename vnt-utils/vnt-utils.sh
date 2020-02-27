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
  show_menu_option "vnt_node_set_latency     " " - VNT node set latency"
  show_menu_option "vnt_node_del_latency     " " - VNT node delete latency"
  show_menu_option "vnt_node_set_max_rate    " " - VNT node set max rate"
  show_menu_option "vnt_node_del_max_rate    " " - VNT node delete max rate"
  show_menu_option "vnt_node_set_packet_loss " " - VNT node set packet loss"
  show_menu_option "vnt_node_del_packet_loss " " - VNT node delete packet loss"
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
  local port=0
  local current_latency=-1
  local pattern="s/latency=//g"

  # Get qos information for the node
  port_get_qos_info $kvm

  # Get port number from vm name
  vm_name_to_port_number $kvm port

  # Qos configuired and is it linux-netem?
  if [[ "$qos_info_type" = "linux-netem" ]]; then  

    # Given something like "latency=500000", extract value (i.e. "500000")
    current_latency="$(echo "$qos_info_other_config" | grep "latency" | sed "$pattern")"

    # Node configured for latency?
    if [[ "$current_latency" != "" ]]; then  

      # Set latency (in microsecs).
      ovs_port_qos_latency_update $port $latency
    fi
  else

    # Set linux-netem latency
    ovs_port_qos_latency_create $port $latency
  fi
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_node_del_latency()
{
  local kvm=$1
  local pname=0
  local current_latency=-1
  local pattern="s/latency=//g"

  # Get qos information for the node
  port_get_qos_info $kvm

  # Get port number from vm name
  vm_name_to_port_name $kvm pname

  # Qos configuired and is it linux-netem?
  if [[ "$qos_info_type" = "linux-netem" ]]; then  

    # Given something like "latency=500000", extract value (i.e. "500000")
    current_latency="$(echo "$qos_info_other_config" | grep "latency" | sed "$pattern")"

    # Node configured for latency?
    if [[ "$current_latency" != "" ]]; then  

      # Set latency (in microsecs).
      ovs_port_qos_netem_delete $pname
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

  # Construct the unique queue id for the kvm/linux-htb.max-rate
  queue_number=map_qos_type_params_partition["linux-htb.max-rate"]
  queue_number=$((queue_number+port))
  
  # Get queue uuid (if any) associated with the kvm (max-rate information)
  ovs_port_find_qos_queue_record $port $queue_number

  # max-rate qos configured for port/kvm?
  if [[ "$g_qos_queue_record_uuid" = "" ]]; then

    # Create max-rate qos for kvm
    ovs_port_qos_max_rate_create $port $max_rate

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
  local kvm=$1
  local max_rate=$2
  local port=0
  local pname=""
  local queue_number=0
  local condition=""
  local uuid=""
  local qos_uuid=""
  local queue_info=""

  # Get port number from vm name
  vm_name_to_port_number $kvm port

  # Construct the unique queue id for the kvm/linux-htb.max-rate
  queue_number=map_qos_type_params_partition["linux-htb.max-rate"]
  queue_number=$((queue_number+port))
  
  # Get queue uuid (if any) associated with the kvm (max-rate information)
  ovs_port_find_qos_queue_record $port $queue_number

  # max-rate qos configured for port/kvm?
  if [[ "$g_qos_queue_record_uuid" != "" ]]; then

    # Get port number from vm name
    vm_name_to_port_name $kvm pname

    # Find uuid of "eth0" port (for example) in table "port"
    condition="name=$HOST_NETIFACE_NAME"
    ovs_table_find_record "port" "$condition" uuid

    # The uuid for the "HOST_NETIFACE_NAME" must always exist
    if [[ "$uuid" != "" ]]; then

      # Get qos uuid (if any)  
      ovs_table_get_value "port" $uuid "qos" qos_uuid

      # max-rate configured (for at least one port)?
      if [[ "$qos_uuid" != "" ]]; then
      
        uuid=$qos_uuid

        # Get qos queues
        ovs_table_get_value "qos" $uuid "queues" queue_info

        ovs_qos_queues_delete_queue $queue_info
      fi
    
    fi
    # Find

    #ovs_table_get_value "qos"

    #ovs_table_set_value "qos"

    # Update max-rate qos for kvm
    #ovs_port_qos_htb_delete $pname
  fi 
}

#==================================================================================================================
# 
#==================================================================================================================
ovs_qos_queues_delete_queue()
{
  local queue_info=$1

  echo "removing queue info: [$queue_info] from \"queues\" in \"qos\" table"
}


#==================================================================================================================
# 
#==================================================================================================================
vnt_node_set_packet_loss()
{
  local kvm=$1
  local loss=$2
  local port=0
  local current_loss=-1
  local pattern="s/loss=//g"

  # Get qos information for the node
  port_get_qos_info $kvm

  # Get port number from vm name
  vm_name_to_port_number $kvm port

  # Qos configuired and is it linux-netem?
  if [[ "$qos_info_type" = "linux-netem" ]]; then  

    # Given something like "loss=30", extract value (i.e. "30")
    current_loss="$(echo "$qos_info_other_config" | grep "loss" | sed "$pattern")"

    # Node configured for packet loss?
    if [[ "$current_loss" != "" ]]; then  

      # Set packet loss (as a percentage).
      ovs_port_qos_packet_loss_update $port $loss
    fi
  else

    # Set packet loss (as a percentage).
    ovs_port_qos_packet_loss_create $port $loss
  fi
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_node_del_packet_loss()
{
  local kvm=$1
  local pname=0
  local current_loss=-1
  local pattern="s/loss=//g"

  # Get qos information for the node
  port_get_qos_info $kvm

  # Get port number from vm name
  vm_name_to_port_name $kvm pname

  # Qos configuired and is it linux-netem?
  if [[ "$qos_info_type" = "linux-netem" ]]; then  

    # Given something like "loss=30", extract value (i.e. "30")
    current_loss="$(echo "$qos_info_other_config" | grep "loss" | sed "$pattern")"

    # Node configured for packet loss?
    if [[ "$current_loss" != "" ]]; then  

      # Remove packet latency
      ovs_port_qos_netem_delete $pname
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
