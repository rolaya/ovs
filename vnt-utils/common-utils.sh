#!/bin/sh

# Generic/common UI utils
source "ui-utils.sh"

###################################################################################################################
# The global OVS configuration file.
g_ovs_config_file="ovs-utils.sh"
###################################################################################################################

###################################################################################################################
# The global KVM configuration file.
g_kvm_config_file="kvm-utils.sh"
###################################################################################################################

q_queues_queue_list=""

#==================================================================================================================
# 
#==================================================================================================================
vm_name_to_port_number()
{
  local kvm_name=$1
  local port_number=0
  local pattern="s/${VM_BASE_NAME}//g"

  # Given a KVM node name (e.g. kvm-vnt-node1) return its port number (1 less than the name index)
  port_number=$(echo "$kvm_name" | sed "$pattern")
  port_number=$((port_number-1))

  echo "kvm name:    [$kvm_name]"
  echo "port number: [$port_number]"

  # Return port number to caller.
  eval "$2='$port_number'"
}

#==================================================================================================================
# 
#==================================================================================================================
vm_name_to_port_name()
{
  local kvm_name=$1
  local pnumber=0
  local port_name=""

  # Given KVM name, gets its corresponding port number
  vm_name_to_port_number $kvm_name pnumber

  # Format the port name for the KVM (something like "vnet0")
  port_name="$OVS_PORT_NAME_BASE$pnumber"
  
  echo "node name: [$kvm_name]"
  echo "port name: [$port_name]"

  # Return port name to caller.
  eval "$2='$port_name'"
}

#==================================================================================================================
# 
#==================================================================================================================
port_name_to_vm_number()
{
  local port_name=$1
  local port_number=0
  local pattern="s/${OVS_PORT_NAME_BASE}//g"

  # Given a port name (e.g. vnet0) return its vm number (1 more tnan the name index)
  port_number=$(echo "$port_name" | sed "$pattern")
  port_number=$((port_number+1))

  # Return port number to caller.
  eval "$2='$port_number'"
}

#==================================================================================================================
# Convert port name to vm name (e.g. vnet0 to kvm-vnt-node1)
#==================================================================================================================
port_name_to_vm_name()
{
  local port_name=$1
  local vm_name=""
  local vm_number=-1
  local pattern="s/${OVS_PORT_NAME_BASE}/${VM_BASE_NAME}/g"

  # Given port name vnetx (e.g. vnet0) return index+1
  port_name_to_vm_number $port_name vm_number

  # Given port name vnetx (e.g. vnet0) return "kvm-vnt-node"
  vm_name=$(echo "$port_name" | sed "$pattern")
  vm_name=$(echo "$vm_name" | sed 's/[0-9]//g')

  # Return port number to caller.
  eval "$2='$vm_name$vm_number'"
}

#==================================================================================================================
#==================================================================================================================
ovs_table_qos_item_queues_list()
{
  local port_number=$1
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

  echo "Find qos queue record uuid for port: [$port_number] queue number: [$queue_number]..."

  # Initialize qos queue record uuid
  g_qos_queue_record_uuid=""

  # Find record in "port" table whose "name" is $HOST_NETIFACE_NAME (the name of our wired ethernet interface).
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
ovs_table_qos_item_queues_update()
{
  local kvm_name=$1
  local queue_number=0
  local command=""
  local table=""
  local condidion=""
  local uuid=""
  local qos_uuid=""
  local value=""
  local old_ifs=""
  local index=0
  local queues_added=0
  local uuid_array=""
  local arraylength=0
  local uuids=""
  local record_queue_number=""
  local record_uuid=""
  local pname=""
  local pnumber=-1
  local queues_queue=""
  local qos_queues=""

  # Initialization
  q_queues_queue_list=""
  qos_queues=""

  # Given kvm name gets its port name
  vm_name_to_port_name $kvm_name pname

  # Given kvm name gets its port number
  vm_name_to_port_number $kvm_name pnumber

  # Derive the queue number we are interested in
  queue_number=${map_qos_type_params_partition["linux-htb.max-rate"]}
  queue_number=$((queue_number+$pnumber))

  echo "Purging qos for kvm: [$kvm_name] with port: [$pname/$pnumber] queue number: [$queue_number]..."

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
  
  # Backup IFS (this is a shell "system/environment" wide setting)
  old_ifs=$IFS

  # Remove {} from qos_queues_uuid
  uuids=$(echo "$global_qos_queues_list" | sed 's/{//g')
  uuids=$(echo "$uuids" | sed 's/}//g')

  # Use space as delimiter
  IFS=' ,'

  # uuids are separated by IFS
  read -ra  uuid_array <<< "$uuids"

  # Number of queues elements
  arraylength=${#uuid_array[@]}

  echo "processing: [$arraylength] uuids..."

  # Find qos queue based on port number
  for queues_queue in "${uuid_array[@]}"; do

    # Extract the queue number from the queues, a single queue value is something like:
    # 101=50ebde1e-1700-4edb-b18e-366353da3827
    record_queue_number=${queues_queue%%=*}

    echo "queue number: ${queues_queue%%=*} $record_queue_number"
    echo "uuid[$index]: [$queues_queue]"

    echo "record_queue_number: $record_queue_number"
    echo "queue_number:        $queue_number"

    # Keep this queue?
    if [[ "$record_queue_number" != "$queue_number" ]]; then

      # Update queues list    
      q_queues_queue_list=$q_queues_queue_list$queues_queue

      # Update number of queues that we are going to keep
      ((queues_added++))

    else

      # Save the actual record uuid, something like:
      # 50ebde1e-1700-4edb-b18e-366353da3827
      record_uuid=$(echo ${queues_queue:(-36)})
      echo "$record_uuid"
      g_qos_queue_record_uuid=$record_uuid

      # Display queue to be removed
      echo "queues queue item: [$queues_queue] to be removed..."
    fi

    ((index++))
    
    # Append ", " as required
    if [[ "$index" < "$arraylength" ]] && [[ "$arraylength" > "2" ]] && [[ "$queues_added" > "0" ]]; then
      q_queues_queue_list=$q_queues_queue_list", "
    fi

  done

  # Restore IFS
  IFS=$old_ifs

  # Wrap queues list with {}
  qos_queues="{$q_queues_queue_list}"

  echo "Removing queue record: [$g_qos_queue_record_uuid] from queues"
  echo "Updated queues list [$qos_queues]"

  # Update qos table with new list of queues
  ovs_table_set_value "qos" $qos_uuid "queues" "$qos_queues"

  # Delete queue record
  ovs_table_delete_record "queue" $record_uuid
}
