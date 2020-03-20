#!/bin/sh

###################################################################################################################
# Common global utils file.
g_common_utils_config_file="common-utils.sh"
###################################################################################################################

# VNT configuration file.
g_vnt_config_file="config.env.vnt"

###################################################################################################################
# The global configuration file for the CentOS KVM host. The KVM host is the host for additional (nested) KVM
# guests (i.e. the VNT network nodes). In the production environment this KVM host currently runs under ESXi. In 
# development environments this KVM host runs on misc. development machines.
g_kvm_host_config_file="config.env.kvm_host"
###################################################################################################################

###################################################################################################################
# The global configuration file for a single KVM guest (VNT network node).
g_kvm_guest_config_file="config.env.kvm-vnt-nodex"
###################################################################################################################

###################################################################################################################
# KVM/OVS network specific configuration. This is the "network" used by all KVM guests. When a KVM guest is
# created (and subsequently started, it is "attached" to this network). Ultimately we apply traffic shaping on
# individual ports of the Open vSwitch associated with this network.
kvm_ovs_network_name="kvm-ovs-network"
kvm_ovs_network_definition_file="kvm-ovs-network.xml"
###################################################################################################################

###################################################################################################################
# KVM VNT image pool (additional)
KVM_POOL_IMG_NAME="kvm-vnt-images"
KVM_POOL_IMG_PATH="/home/$KVM_POOL_IMG_NAME"
###################################################################################################################

#==================================================================================================================
#
#==================================================================================================================
kvm_utils_show_menu()
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

  echo "KVM host configuration file:   [$g_kvm_host_config_file]"
  echo "Host name:                     [$HOSTNAME]"
  echo "Sourced time:                  [$g_sourced_datetime]"
  echo "Current time:                  [$datetime]"

  # Is KVM host running under KVM (development environment)?
  if [[ "$KVM_HOST_HYPERVISOR" = "kvm" ]]; then  
    echo "KVM host name:                 [$KVM_HOST_NAME]"
    echo "KVM host RAM:                  [$KVM_HOST_RAM]"
    echo "KVM host size:                 [$KVM_HOST_SIZE]"
  fi

  echo
  echo "KVM guest configuration file:  [$g_kvm_guest_config_file]"
  echo "KVM OVS network name:          [$kvm_ovs_network_name]"
  echo "KVM OVS network config file:   [$kvm_ovs_network_definition_file]"
  echo "KVM guest name:                [$KVM_GUEST_NAME]"
  echo "KVM guest RAM:                 [$KVM_GUEST_RAM]"
  echo "KVM guest size:                [$KVM_GUEST_SIZE]"
  echo "KVM guest type:                [$KVM_GUEST_TYPE]"
  echo "KVM guest variant:             [$KVM_GUEST_VARIANT]"
  echo "KVM guest iso:                 [$KVM_GUEST_ISO]"
  echo "KVM images dir:                [$KVM_IMAGES_DIR]"
  echo
  echo "Number of KVMs:                [$NUMBER_OF_VMS]"
  echo "KVM base name:                 [$VM_BASE_NAME]"
  echo "KVM range:                     [$VM_BASE_NAME$first_vm..$VM_BASE_NAME$NUMBER_OF_VMS]"
  echo "KVM port range:                [$OVS_PORT_NAME_BASE$OVS_PORT_INDEX_BASE..$OVS_PORT_NAME_BASE$((NUMBER_OF_VMS-1))]"
  echo

  # Is KVM host running under KVM (development environment)?
  if [[ "$KVM_HOST_HYPERVISOR" = "kvm" ]]; then  
    # VNT host deployment
    echo
    echo -e "${TEXT_VIEW_NORMAL_GREEN}VNT host deployment"
    echo "=========================================================================================================================="
    echo -e "${TEXT_VIEW_NORMAL}"
    show_menu_option "kvm_vm_install            " " - \"$KVM_HOST_NAME\" VM install"
    show_menu_option "kvm_vm_purge              " " - \"$KVM_HOST_NAME\" VM purge"
    show_menu_option "kvm_vm_snapshot_create    " " - \"$KVM_HOST_NAME\" VM snapshot create"
    show_menu_option "kvm_vm_snapshot_restore   " " - \"$KVM_HOST_NAME\" VM snapshot restore"
    show_menu_option "kvm_vm_snapshot_list      " " - \"$KVM_HOST_NAME\" VM snapshot list"
    show_menu_option "kvm_vm_start              " " - \"$KVM_HOST_NAME\" VM start"
  fi

  # KVM guest (VNT network node) deployment
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}KVM guest management"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"
  show_menu_option "kvm_list     " " - \"$HOSTNAME\" guest list"
  show_menu_option "kvm_install  " " - \"$KVM_GUEST_NAME\" guest install"
  show_menu_option "kvm_import   " " - \"$KVM_GUEST_NAME\" guest import"
  show_menu_option "kvm_purge    " " - \"$KVM_GUEST_NAME\" guest purge"
  show_menu_option "kvm_start    " " - \"$KVM_GUEST_NAME\" guest start"
  show_menu_option "kvm_shutdown " " - \"$KVM_GUEST_NAME\" guest shutdown"
  echo
  
  # KVM/OVS network provision
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}KVM/OVS network provision"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"
  show_menu_option "kvm_vnt_network_provision " " - Provision VNT KVM network"

  # KVM guest image pool
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}KVM guest image pool management"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"
  show_menu_option "kvm_img_pool_create " " - Create storage pool"
  show_menu_option "kvm_img_pool_delete " " - Delete storage pool"
}

#==================================================================================================================
# 
#==================================================================================================================
kvm_list()
{
  local command=""

  command="sudo virsh list --all"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
kvm_start()
{
  local command=""
  local kvm=${1:-$KVM_GUEST_NAME}

  command="sudo virsh start --console --force-boot $kvm"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
kvm_start_headless()
{
  local command=""
  local kvm=${1:-$KVM_GUEST_NAME}

  message "starting headless kvm: [$kvm]" $TEXT_VIEW_NORMAL_GREEN

  command="sudo virsh start --force-boot $kvm"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
kvm_shutdown()
{
  local command=""
  local kvm=${1:-$KVM_GUEST_NAME}

  command="sudo virsh shutdown $kvm"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
kvm_purge()
{
  local command=""
  local kvm_name=${1:-$KVM_GUEST_NAME}

  command="sudo virsh undefine $kvm_name"
  echo "Executing: [$command]"
  $command

  command="sudo virsh destroy $kvm_name"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
kvm_snapshot_create()
{
  local command=""
  local snapshot_name=$(date +%F-%T)

  # User provided a snapshot name?
  if [ $# -gt 0 ]; then
    # The snapshot name will be something like: "2020-02-06-17:17:11-snapshot1"
    snapshot_name+="-$1"
  fi

  command="sudo virsh snapshot-create-as --domain $KVM_GUEST_NAME --name $snapshot_name"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
kvm_snapshot_restore()
{
  local command=""
  local snapshot_name=$1

  command="sudo virsh snapshot-revert $KVM_GUEST_NAME $snapshot_name"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
kvm_snapshot_list()
{
  local command=""
  local kvm_name=${1:-$KVM_GUEST_NAME}

  command="sudo virsh snapshot-list $kvm_name --tree"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
kvm_vm_start()
{
  local kvm_name=${1:-$KVM_GUEST_NAME}

  kvm_start $kvm_name
}

#==================================================================================================================
# Installs "main" CentOS VM on a KVM based hypervisor.
#==================================================================================================================
kvm_vm_install()
{
  local command=""

  command="sudo virt-install
               --name $KVM_HOST_NAME
               --cpu host-passthrough
               --os-type=Linux
               --os-variant=centos7.0
               --network bridge=br0-wired
               --ram=$KVM_HOST_RAM
               --vcpus=1
               --disk path=$KVM_LIBVIRT_IMAGES_PATH/$KVM_HOST_NAME.img,bus=virtio,size=$KVM_HOST_SIZE
               --graphics $KVM_INSTALL_OPTION_GRAPHICS
               --location /home/rolaya/iso/CentOS-7-x86_64-DVD-1908.iso
               --extra-args console=ttyS0"
  echo "Executing: [$command]"
  $command                 
}

#==================================================================================================================
#
#==================================================================================================================
kvm_install()
{
  local command=""

  # Configuration file provided?
  if [[ $# -eq 1 ]]; then
    # Source provided VNT network node configuration file
    source "$1"
  else
    # Source default VNT network node configuration file
    source "$g_kvm_guest_config_file"
  fi

  # Set configuration parameters for guest KVM.
  local kvm_name=$KVM_GUEST_NAME
  local kvm_type=$KVM_GUEST_TYPE
  local kvm_variant=$KVM_GUEST_VARIANT
  local kvm_ram=$KVM_GUEST_RAM
  local kvm_size=$KVM_GUEST_SIZE
  local kvm_iso=$KVM_GUEST_ISO

  # Install guest
  command="sudo virt-install
               --name $kvm_name
               --os-type=$kvm_type
               --os-variant=$kvm_variant
               --ram=$kvm_ram
               --vcpus=1
               --disk path=$KVM_IMAGES_DIR/$KVM_GUEST_NAME.img,bus=virtio,size=$kvm_size
               --network network:$kvm_ovs_network_name
               --graphics $KVM_INSTALL_OPTION_GRAPHICS
               --location /home/rolaya/iso/$kvm_iso
               --extra-args console=ttyS0"
  echo "Executing: [$command]"
  $command                 
}

#==================================================================================================================
#
#==================================================================================================================
kvm_import()
{
  local command=""

  # Configuration file provided?
  if [[ $# -eq 1 ]]; then
    # Source provided VNT network node configuration file
    source "$1"
  else
    # Source default VNT network node configuration file
    source "$g_kvm_guest_config_file"
  fi

  # Set configuration parameters for guest KVM.
  local kvm_name=$KVM_GUEST_NAME
  local kvm_type=$KVM_GUEST_TYPE
  local kvm_variant=$KVM_GUEST_VARIANT
  local kvm_ram=$KVM_GUEST_RAM
  local kvm_size=$KVM_GUEST_SIZE
  local kvm_iso=$KVM_GUEST_ISO
  local kvm_network_ovs=$KVM_NETWORK_OVS
  local kvm_network_mgmt=$KVM_NETWORK_MGMT

  # Install/import guest
  command="sudo virt-install --debug
              --name $kvm_name
              --os-type=$kvm_type
              --os-variant=$kvm_variant
              --ram=$kvm_ram
              --vcpus=1
              --disk path=$KVM_IMAGES_DIR/$KVM_GUEST_NAME.img,bus=virtio,size=$kvm_size
              --network network:$kvm_network_mgmt
              --graphics $KVM_INSTALL_OPTION_GRAPHICS
              --import"
  echo "Executing: [$command]"
  $command                 
}

#==================================================================================================================
#
#==================================================================================================================
kvm_import_headless()
{
  local command=""

  # Configuration file provided?
  if [[ $# -eq 1 ]]; then
    # Source provided VNT network node configuration file
    source "$1"
  else
    # Source default VNT network node configuration file
    source "$g_kvm_guest_config_file"
  fi

  # Set configuration parameters for guest KVM.
  local kvm_name=$KVM_GUEST_NAME
  local kvm_type=$KVM_GUEST_TYPE
  local kvm_variant=$KVM_GUEST_VARIANT
  local kvm_ram=$KVM_GUEST_RAM
  local kvm_size=$KVM_GUEST_SIZE
  local kvm_iso=$KVM_GUEST_ISO
  local kvm_network_ovs=$KVM_NETWORK_OVS
  local kvm_network_mgmt=$KVM_NETWORK_MGMT

  # Install/import (headless)
  command="sudo virt-install --debug
              --name $kvm_name
              --os-type=$kvm_type
              --os-variant=$kvm_variant
              --ram=$kvm_ram
              --vcpus=1
              --disk path=$KVM_IMAGES_DIR/$KVM_GUEST_NAME.img,bus=virtio,size=$kvm_size
              --network network:$kvm_network_mgmt
              --nographics
              --noautoconsole
              --import"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
#
#==================================================================================================================
kvm_import_by_name()
{
  local command=""
  local kvm_name=$1

  # Update configuration (i.e. the name of the VM on the guest configuration file)
  kvm_guest_configuration_update $kvm_name

  # Source default VNT network node configuration file
  source "$g_kvm_guest_config_file"

  # Set configuration parameters for guest KVM.
  local kvm_name=$KVM_GUEST_NAME
  local kvm_type=$KVM_GUEST_TYPE
  local kvm_variant=$KVM_GUEST_VARIANT
  local kvm_ram=$KVM_GUEST_RAM
  local kvm_size=$KVM_GUEST_SIZE
  local kvm_iso=$KVM_GUEST_ISO
  local kvm_network_ovs=$KVM_NETWORK_OVS
  local kvm_network_mgmt=$KVM_NETWORK_MGMT

  # Install/import guest
  command="sudo virt-install --debug
              --name $kvm_name
              --os-type=$kvm_type
              --os-variant=$kvm_variant
              --ram=$kvm_ram
              --vcpus=1
              --disk path=$KVM_IMAGES_DIR/$KVM_GUEST_NAME.img,bus=virtio,size=$kvm_size
              --network network:$kvm_network_mgmt
              --graphics $KVM_INSTALL_OPTION_GRAPHICS
              --import"
  echo "Executing: [$command]"

  $command                 
}

#==================================================================================================================
#
#==================================================================================================================
kvm_clone()
{
  local command=""
  local kvm_name=$1

  # Clone guest
  command="sudo virt-clone --debug --original kvm-vnt-node1 --auto-clone --name $kvm_name"
  echo "Executing: [$command]"
  $command                 
}

#==================================================================================================================
#
#==================================================================================================================
qt()
{
  local command=""

  #x="name"
  #net_name=""
  #net_name=$(sed -n "/$x/{s/.*<$x>\(.*\)<\/$x>.*/\1/;p}" kvm-mgmt-network.xml)
  #echo "sdasdnkasdas $net_name"  
}

#==================================================================================================================
#
#==================================================================================================================
kvm_guest_configuration_update()
{
  local kvm_name=$1
  local command=""
  local kvm_number=-1
  local kvm_guest_config="$g_kvm_guest_config_file"
  local pattern=""

  # Insure KVM name is provided
  if [[ "$kvm_name" != "" ]]; then  

    # Get KVM number from KVM name
    vm_name_to_vm_number $kvm_name kvm_number
    
    # Format search/replace pattern, we want to replace something like kvm-vnt-nodeX 
    # with like kvm-vnt-node1.
    pattern="s/${VM_BASE_NAME}[0-9]/${VM_BASE_NAME}$kvm_number/g"

    # User feedback
    message "updating configuration file: [$kvm_guest_config], pattern: [$pattern]"

    # Update "generic" guest configuration file (just replacing the KVM name (for now))
    sed -i "$pattern" $kvm_guest_config

  else
    message "usage: kvm_reprovision_net_interfaces kvm-name" $TEXT_VIEW_NORMAL_RED
  fi    
}

#==================================================================================================================
#
#==================================================================================================================
kvm_reprovision_net_interfaces()
{
  local kvm_name=$1
  local command=""
  local kvm_guest_config="$g_kvm_guest_config_file"

  if [[ "$kvm_name" != "" ]]; then  

    message "upgrading kvm: [$kvm_name] network interfaces" $TEXT_VIEW_NORMAL_RED

    # Undefine given KVM
    command="sudo virsh undefine $kvm_name"
    echo "Executing: [$command]"
    $command

    # Update guest configuration file
    kvm_guest_configuration_update $kvm_name

    # Import the KVM with new configuration
    kvm_import_headless $kvm_guest_config

    # We need the KVM running to be able to add another network interface 
    # (and the import process launched the KVM, so attach new interace).
    # Note: this KVM/libvirt framework mechanism may be explored for "other"
    # functionality (KVM updates of other kinds).
    kvm_attach_interface $kvm_name

  else
    message "usage: kvm_reprovision_net_interfaces kvm-name" $TEXT_VIEW_NORMAL_RED
  fi    
}

#==================================================================================================================
#
#==================================================================================================================
kvm_attach_interface()
{
  local kvm_name=$1
  local command=""

  if [[ "$kvm_name" != "" ]]; then  

    message "adding qos management interface to kvm: [$kvm_name]" $TEXT_VIEW_NORMAL_GREEN

    # Attach the management interface to the KVM, this will allow us to ssh, etc into the KVM
    command="sudo virsh attach-interface 
                  --domain $kvm_name
                  --type network
                  --source $KVM_NETWORK_OVS
                  --model virtio
                  --config 
                  --live"
    echo "Executing: [$command]"
    $command

  else
    message "usage: kvm_attach_interface kvm-name" $TEXT_VIEW_NORMAL_RED
  fi  
}

#==================================================================================================================
#
#==================================================================================================================
kvm_get_iface_info()
{
  local kvm_name=$1
  local command=""

  if [[ "$kvm_name" != "" ]]; then  
    command="sudo virsh domiflist $kvm_name"
    echo "Executing: [$command]"
    $command
  else
    message "usage: kvm_get_iface_info kvm-name" $TEXT_VIEW_NORMAL_RED
  fi  
}

#==================================================================================================================
#
#==================================================================================================================
kvm_get_ovs_port()
{
  local kvm_name=$1
  local command=""
  local iface_info=""
  local iface=""
  local iface_info_delimeted=""
  local pattern="s/kvm-ovs-network//g"
  local iface_info_array=""
  local array_len=0
  local index=0
  local iface_config_array=""
  local iface_config_value=""
  local temp_value=""
  local port_name=""

  # Init
  unset iface_info_array
  unset iface_config_array

  # Insure kvm name is provided
  if [[ "$kvm_name" != "" ]]; then

    # get kvm network interface list
    command="sudo virsh domiflist $kvm_name"
    echo "Executing: [$command]"
    iface_info="$($command)"

    # Convert LF to , (for use as the IFS)
    iface_info_delimeted=$(echo "$iface_info" | tr '\n' ',')

    # Some records will be actual interface information, some will be comments
    # and headers for example and interface entry will look somethig like:
    # "vnet1      bridge     kvm-ovs-network virtio      52:54:00:d8:7e:f3"
    IFS=',' read -ra  iface_info_array <<< "$iface_info_delimeted"

    array_len=${#iface_info_array[@]}

    echo "processing: [$array_len] uuids..."

    # Find qos queue based on port number
    for iface in "${iface_info_array[@]}"; do

      #echo "queue number: ${uuid%%=*} $record_queue_number"
      echo "iface[$index]: [$iface]"

      temp_value=""

      # Search for "kvm-ovs-network" in current entry
      temp_value="$(echo "$iface" | grep "$kvm_ovs_network_name")"

      # Found OVS/QoS management interface?
      if [[ "$temp_value" != "" ]]; then

        # Read all values into array. We expect the values to be in this order:
        # "Interface Type Source Model MAC". We are intersted in the "Interface",
        # something like vnet1 (this is the OVS port we apply QoS to).
        read -a iface_config_array <<< $iface

        # For informational purposes, display all values
        for iface_config_value in "${iface_config_array[@]}"; do
          echo "iface config: [$iface_config_value]"
        done

        # Get the port name
        port_name=${iface_config_array[0]}
        echo "kvm: [$kvm_name] QoS port name: [$port_name]"

      fi

    ((index++))
  
  done      
  else
    message "usage: kvm_get_ovs_port kvm-name" $TEXT_VIEW_NORMAL_RED
  fi

  eval "$2='$port_name'"
}

#==================================================================================================================
#
#==================================================================================================================
kvm_get_ip_address()
{
  local kvm_name=$1
  local net_name=$2
  local command=""
  local dhcp_info=""
  local ip_address=""
  local dhcp_lease=""
  local dhcp_info_delimeted=""
  local pattern="s/$kvm_name//g"
  local dhcp_info_array=""
  local array_len=0
  local index=0
  local dhcp_config_array=""
  local dhcp_config_value=""
  local temp_value=""

  # Init
  unset dhcp_info_array
  unset dhcp_config_array

  # Insure kvm name and network name are provided
  if [[ "$kvm_name" != "" ]] && [[ "$net_name" != "" ]]; then

    # Get dhcp lease list the entries are something like:
    # "Expiry Time         MAC address        Protocol IP address          Hostname       Client ID or DUID"
    # 2020-03-14 00:25:19  52:54:00:65:ba:9f  ipv4     192.168.122.150/24  kvm-vnt-node1  -
    command="sudo virsh net-dhcp-leases $net_name"
    echo "Executing: [$command]"
    dhcp_info="$($command)"

    # Convert LF to , (for use as the IFS)
    dhcp_info_delimeted=$(echo "$dhcp_info" | tr '\n' ',')

    # Some records will be actual dhcp lease information, some will be comments
    # and headers.
    IFS=',' read -ra  dhcp_info_array <<< "$dhcp_info_delimeted"

    array_len=${#dhcp_info_array[@]}

    echo "processing: [$array_len] dhcp lease entries..."

    # Find dhcp lease for given kvm
    for dhcp_lease in "${dhcp_info_array[@]}"; do

      echo "dhcp lease[$index]: [$dhcp_lease]"

      temp_value=""

      # Search for "kvm-vnt-node1" (for example) in current entry
      temp_value="$(echo "$dhcp_lease" | grep "$kvm_name")"

      # Found OVS/QoS management interface?
      if [[ "$temp_value" != "" ]]; then

        # Read all values into array. We expect the values to be in this order:
        # "Expiry Time  MAC address  Protocol IP address  Hostname  Client ID or DUID"
        read -a dhcp_config_array <<< $dhcp_lease

        # For informational purposes, display all values
        for dhcp_config_value in "${dhcp_config_array[@]}"; do
          echo "dhcp config: [$dhcp_config_value]"
        done

        # Get the ip address
        ip_address=${dhcp_config_array[4]}
        ip_address="${ip_address%/*}"

        echo "kvm: [$kvm_name] ip address: [$ip_address]"

      fi

    ((index++))
  
    done

  else
    message "usage: kvm_get_ip_address kvm-name net-name" $TEXT_VIEW_NORMAL_RED
  fi

  eval "$3='$ip_address'"
}

#==================================================================================================================
#
#==================================================================================================================
kvm_vnt_network_provision()
{
  xmli="name"
  local command=""
  local net_file=${1:-$kvm_ovs_network_definition_file}
  local net_name=""

  # Get the "<name>" (network name)
  net_name=$(grep -oP "(?<=<$xmli>).*(?=</$xmli)" $net_file)

  message "Defining network: [$net_name] from configuration file: [$net_file]" $TEXT_VIEW_NORMAL_GREEN

  # Add new persistent virtual network to libvirt
  command="sudo virsh net-define $net_file"
  echo "Executing: [$command]"
  $command  

  command="sudo virsh net-start $net_name"
  echo "Executing: [$command]"
  $command  
  
  command="sudo virsh net-autostart $net_name"
  echo "Executing: [$command]"
  $command  

  command="sudo virsh net-dumpxml $net_name"
  echo "Executing: [$command]"
  $command  

  command="sudo virsh net-list"
  echo "Executing: [$command]"
  $command  
}

#==================================================================================================================
# 
#==================================================================================================================
kvm_img_pool_create()
{
  local command=""

  command="sudo virsh pool-define-as --type dir --name $KVM_POOL_IMG_NAME --target $KVM_POOL_IMG_PATH"
  echo "Executing: [$command]"
  $command

  command="sudo virsh pool-list --all"
  echo "Executing: [$command]"
  $command
  
  command="sudo virsh pool-build $KVM_POOL_IMG_NAME"
  echo "Executing: [$command]"
  $command

  command="sudo virsh pool-start $KVM_POOL_IMG_NAME"
  echo "Executing: [$command]"
  $command

  command="sudo virsh pool-autostart $KVM_POOL_IMG_NAME"
  echo "Executing: [$command]"
  $command  

  command="sudo virsh pool-info $KVM_POOL_IMG_NAME"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
kvm_img_pool_delete()
{
  local command=""

  command="sudo virsh pool-list --all"
  echo "Executing: [$command]"
  $command

  command="sudo virsh pool-destroy $KVM_POOL_IMG_NAME"
  echo "Executing: [$command]"
  $command
  
  command="sudo virsh pool-delete $KVM_POOL_IMG_NAME"
  echo "Executing: [$command]"
  $command

  command="sudo virsh pool-list --all"
  echo "Executing: [$command]"
  $command  
}

#==================================================================================================================
#
#=================================================================================================================
function kvm_gen_mac_addr()
{
  local MACADDR=""
   
  MACADDR="52:54:00:$(dd if=/dev/urandom bs=512 count=1 2>/dev/null | md5sum | sed 's/^\(..\)\(..\)\(..\).*$/\1:\2:\3/')"; 
  
  echo $MACADDR
}

#==================================================================================================================
#
#=================================================================================================================
function kvm_read_configuration()
{
  # Generic/common UI utils
  source "ui-utils.sh"

  # Source common helpers
  source "$g_common_utils_config_file"

  # Source VNT configuration
  source "$g_vnt_config_file"

  # Source host and environment specific VNT configuration
  source "$g_kvm_host_config_file"

  # Source VNT network node configuration file
  source "$g_kvm_guest_config_file"
}

# CONSOLE_MODE environment variable not set?
if [[ -z "$CONSOLE_MODE" ]]; then
  CONSOLE_MODE=true
  DISPLAY_API_MENUS=true
fi

# Executing from bash console?
if [[ "$CONSOLE_MODE" == "true" ]]; then
  
  # Capture time when file was sourced 
  g_sourced_datetime="$(date +%c)"

  # Provision environment based on configuration file
  kvm_read_configuration

  if [[ "$DISPLAY_API_MENUS" == "true" ]]; then

    # Display helper "menu"
    kvm_utils_show_menu
  fi
fi
