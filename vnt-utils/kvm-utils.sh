#!/bin/sh

# Generic/common UI utils
source "ui-utils.sh"

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
  show_menu_option "kvm_ovs_network_provision " " - Provision KVM/OVS network"

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
  local command=""

  command="sudo virsh start --console --force-boot $KVM_HOST_NAME"
  echo "Executing: [$command]"
  $command
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

  # Install guest
  command="sudo virt-install --debug
               --name $kvm_name
               --os-type=$kvm_type
               --os-variant=$kvm_variant
               --ram=$kvm_ram
               --vcpus=1
               --disk path=$KVM_IMAGES_DIR/$KVM_GUEST_NAME.img,bus=virtio,size=$kvm_size
               --network network:$kvm_ovs_network_name
               --graphics $KVM_INSTALL_OPTION_GRAPHICS
               --import"
  echo "Executing: [$command]"
  $command                 
}

#==================================================================================================================
#
#==================================================================================================================
kvm_ovs_network_provision()
{
  local command=""

  # Add new persistent virtual network to libvirt
  command="sudo virsh net-define $kvm_ovs_network_definition_file"
  echo "Executing: [$command]"
  $command  

  command="sudo virsh net-start $kvm_ovs_network_name"
  echo "Executing: [$command]"
  $command  
  
  command="sudo virsh net-autostart $kvm_ovs_network_name"
  echo "Executing: [$command]"
  $command  

  command="sudo virsh net-dumpxml $kvm_ovs_network_name"
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
function kvm_read_configuration()
{
  # Source VNT configuration
  source "$g_vnt_config_file"

  # Source host and environment specific VNT configuration
  source "$g_kvm_host_config_file"

  # Source VNT network node configuration file
  source "$g_kvm_guest_config_file"
}

# Capture time when file was sourced 
g_sourced_datetime="$(date +%c)"

# Provision environment based on configuration file
kvm_read_configuration

# Display helper "menu"
kvm_utils_show_menu
