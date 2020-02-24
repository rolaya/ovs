#!/bin/sh

# Source host and environment specific VNT configuration
source "ui-utils.sh"

# The global configuration file for CentOS VNT VM
g_kvm_vnt_vm_config_file="config.env.kvm_vnt_host"

# The global configuration file for VNT network nodes
g_kvm_vnt_guest_config_file="config.env.kvm-vnt-nodex"

# Network related definitions (update according to local environment)
kvm_ovs_network_name="kvm-ovs-network"
kvm_ovs_network_definition_file="kvm-ovs-network.xml"

# KVM VNT image pool (additional)
KVM_VNT_POOL_IMG_NAME="kvm-vnt-images"
KVM_VNT_POOL_IMG_PATH="/home/$KVM_VNT_POOL_IMG_NAME"

#==================================================================================================================
#
#==================================================================================================================
kvm_utils_show_menu()
{
  local datetime=""

  # Environment 
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}Environment"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"

  # Get date/time (useful for keeping track of changes)
  datetime="$(date +%c)"

  echo "VNT host configuration file:         [$g_kvm_vnt_vm_config_file]"
  echo "Host name:                           [$HOSTNAME]"
  echo "Sourced time:                        [$g_sourced_datetime]"
  echo "Current time:                        [$datetime]"
  echo "KVM VNT host name:                   [$KVM_VNT_HOST_NAME]"
  echo "KVM VNT host RAM:                    [$KVM_VNT_HOST_RAM]"
  echo "KVM VNT host size:                   [$KVM_VNT_HOST_SIZE]"
  echo "KVM install graphics option:         [$KVM_INSTALL_OPTION_GRAPHICS]"
  echo "VNT network node configuration file: [$g_kvm_vnt_guest_config_file]"
  echo
  echo "KVM OVS network name:                [$kvm_ovs_network_name]"
  echo "KVM OVS network config file:         [$kvm_ovs_network_definition_file]"
  echo "KVM VNT guest name:                  [$KVM_VNT_GUEST_NAME]"
  echo "KVM VNT guest RAM:                   [$KVM_VNT_GUEST_RAM]"
  echo "KVM VNT guest size:                  [$KVM_VNT_GUEST_SIZE]"
  echo "KVM VNT guest type:                  [$KVM_VNT_GUEST_TYPE]"
  echo "KVM VNT guest variant:               [$KVM_VNT_GUEST_VARIANT]"
  echo "KVM VNT guest iso:                   [$KVM_VNT_GUEST_ISO]"
  echo "KVM images dir:                      [$KVM_VNT_IMAGES_DIR]"

  echo

  # VNT host deployment
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}VNT host deployment"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"
  show_menu_option "kvm_vnt_vm_install            " " - \"$KVM_VNT_HOST_NAME\" VM install"
  show_menu_option "kvm_vnt_vm_purge              " " - \"$KVM_VNT_HOST_NAME\" VM purge"
  show_menu_option "kvm_vnt_vm_snapshot_create    " " - \"$KVM_VNT_HOST_NAME\" VM snapshot create"
  show_menu_option "kvm_vnt_vm_snapshot_restore   " " - \"$KVM_VNT_HOST_NAME\" VM snapshot restore"
  show_menu_option "kvm_vnt_vm_snapshot_list      " " - \"$KVM_VNT_HOST_NAME\" VM snapshot list"
  show_menu_option "kvm_vnt_vm_start              " " - \"$KVM_VNT_HOST_NAME\" VM start"

  # VNT network node deployment
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}VNT network deployment"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"
  
  show_menu_option "kvm_ovs_network_provision     " " - Provision VNT OVS network"
  show_menu_option "kvm_vnt_guest_list            " " - \"$KVM_VNT_HOST_NAME\" guest list"
  show_menu_option "kvm_vnt_guest_install         " " - \"$KVM_VNT_GUEST_NAME\" guest install"
  show_menu_option "kvm_vnt_guest_import          " " - \"$KVM_VNT_GUEST_NAME\" guest import"
  show_menu_option "kvm_vnt_guest_purge           " " - \"$KVM_VNT_GUEST_NAME\" guest purge"
  show_menu_option "kvm_vnt_guest_start           " " - \"$KVM_VNT_GUEST_NAME\" guest start"
  show_menu_option "kvm_vnt_guest_shutdown        " " - \"$KVM_VNT_GUEST_NAME\" guest shutdown"
  echo
  show_menu_option "kvm_vnt_guest_img_pool_create " " - Create storage pool"
  show_menu_option "kvm_vnt_guest_img_pool_delete " " - Delete storage pool"
}

#==================================================================================================================
# 
#==================================================================================================================
kvm_vnt_guest_list()
{
  local command=""

  command="sudo virsh list --all"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
kvm_vnt_guest_start()
{
  local command=""
  local kvm=$1

  command="sudo virsh start --console --force-boot $kvm"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
kvm_vnt_guest_shutdown()
{
  local command=""
  local kvm=$1

  command="sudo virsh shutdown $1"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
kvm_vnt_guest_img_pool_create()
{
  local command=""

  command="sudo virsh pool-define-as --type dir --name $KVM_VNT_POOL_IMG_NAME --target $KVM_VNT_POOL_IMG_PATH"
  echo "Executing: [$command]"
  $command

  command="sudo virsh pool-list --all"
  echo "Executing: [$command]"
  $command
  
  command="sudo virsh pool-build $KVM_VNT_POOL_IMG_NAME"
  echo "Executing: [$command]"
  $command

  command="sudo virsh pool-start $KVM_VNT_POOL_IMG_NAME"
  echo "Executing: [$command]"
  $command

  command="sudo virsh pool-autostart $KVM_VNT_POOL_IMG_NAME"
  echo "Executing: [$command]"
  $command  

  command="sudo virsh pool-info $KVM_VNT_POOL_IMG_NAME"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
kvm_vnt_guest_img_pool_delete()
{
  local command=""

  command="sudo virsh pool-list --all"
  echo "Executing: [$command]"
  $command

  command="sudo virsh pool-destroy $KVM_VNT_POOL_IMG_NAME"
  echo "Executing: [$command]"
  $command
  
  command="sudo virsh pool-delete $KVM_VNT_POOL_IMG_NAME"
  echo "Executing: [$command]"
  $command

  command="sudo virsh pool-list --all"
  echo "Executing: [$command]"
  $command  
}

#==================================================================================================================
# 
#==================================================================================================================
kvm_vnt_vm_purge()
{
  local command=""

  command="sudo virsh undefine $KVM_VNT_HOST_NAME"
  echo "Executing: [$command]"
  $command

  command="sudo virsh destroy $KVM_VNT_HOST_NAME"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
kvm_vnt_guest_purge()
{
  local command=""
  local kvm_name=${1:-$KVM_VNT_GUEST_NAME}

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
kvm_vnt_vm_snapshot_create()
{
  local command=""
  local snapshot_name=$(date +%F-%T)

  # User provided a snapshot name?
  if [ $# -gt 0 ]; then
    # The snapshot name will be something like: "2020-02-06-17:17:11-snapshot1"
    snapshot_name+="-$1"
  fi

  command="sudo virsh snapshot-create-as --domain $KVM_VNT_HOST_NAME --name $snapshot_name"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
kvm_vnt_vm_snapshot_restore()
{
  local command=""
  local snapshot_name=$1

  command="sudo virsh snapshot-revert $KVM_VNT_HOST_NAME $snapshot_name"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
kvm_vnt_vm_snapshot_list()
{
  local command=""

  command="sudo virsh snapshot-list $KVM_VNT_HOST_NAME"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
kvm_vnt_vm_start()
{
  local command=""

  command="sudo virsh start --console --force-boot $KVM_VNT_HOST_NAME"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# Installs "main" CentOS VM on a KVM based hypervisor.
#==================================================================================================================
kvm_vnt_vm_install()
{
  local command=""

  command="sudo virt-install
               --name $KVM_VNT_HOST_NAME
               --cpu host-passthrough
               --os-type=Linux
               --os-variant=centos7.0
               --network bridge=br0-wired
               --ram=$KVM_VNT_HOST_RAM
               --vcpus=1
               --disk path=$KVM_LIBVIRT_IMAGES_PATH/$KVM_VNT_HOST_NAME.img,bus=virtio,size=$KVM_VNT_HOST_SIZE
               --graphics $KVM_INSTALL_OPTION_GRAPHICS
               --location /home/rolaya/iso/CentOS-7-x86_64-DVD-1908.iso
               --extra-args console=ttyS0"
  echo "Executing: [$command]"
  $command                 
}

#==================================================================================================================
#
#==================================================================================================================
kvm_vnt_guest_install()
{
  local command=""

  # Configuration file provided?
  if [[ $# -eq 1 ]]; then
    # Source provided VNT network node configuration file
    source "$1"
  else
    # Source default VNT network node configuration file
    source "$g_kvm_vnt_guest_config_file"
  fi

  # Set configuration parameters for guest KVM.
  local kvm_name=$KVM_VNT_GUEST_NAME
  local kvm_type=$KVM_VNT_GUEST_TYPE
  local kvm_variant=$KVM_VNT_GUEST_VARIANT
  local kvm_ram=$KVM_VNT_GUEST_RAM
  local kvm_size=$KVM_VNT_GUEST_SIZE
  local kvm_iso=$KVM_VNT_GUEST_ISO

  # Install guest
  command="sudo virt-install
               --name $kvm_name
               --os-type=$kvm_type
               --os-variant=$kvm_variant
               --ram=$kvm_ram
               --vcpus=1
               --disk path=$KVM_VNT_IMAGES_DIR/$KVM_VNT_GUEST_NAME.img,bus=virtio,size=$kvm_size
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
kvm_vnt_guest_import()
{
  local command=""

  # Configuration file provided?
  if [[ $# -eq 1 ]]; then
    # Source provided VNT network node configuration file
    source "$1"
  else
    # Source default VNT network node configuration file
    source "$g_kvm_vnt_guest_config_file"
  fi

  # Set configuration parameters for guest KVM.
  local kvm_name=$KVM_VNT_GUEST_NAME
  local kvm_type=$KVM_VNT_GUEST_TYPE
  local kvm_variant=$KVM_VNT_GUEST_VARIANT
  local kvm_ram=$KVM_VNT_GUEST_RAM
  local kvm_size=$KVM_VNT_GUEST_SIZE
  local kvm_iso=$KVM_VNT_GUEST_ISO

  # Install guest
  command="sudo virt-install --debug
               --name $kvm_name
               --os-type=$kvm_type
               --os-variant=$kvm_variant
               --ram=$kvm_ram
               --vcpus=1
               --disk path=$KVM_VNT_IMAGES_DIR/$KVM_VNT_GUEST_NAME.img,bus=virtio,size=$kvm_size
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
#=================================================================================================================
function kvm_read_configuration()
{
  # Source host and environment specific VNT configuration
  source "$g_kvm_vnt_vm_config_file"

  # Source VNT network node configuration file
  source "$g_kvm_vnt_guest_config_file"
}

# Capture time when file was sourced 
g_sourced_datetime="$(date +%c)"

# Provision environment based on configuration file
kvm_read_configuration

# Display helper "menu"
kvm_utils_show_menu