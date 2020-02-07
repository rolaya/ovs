#!/bin/sh

# Source host and environment specific VNT configuration
source "ui-utils.sh"

# The global configuration file for CentOS VNT VM
g_kvm_vnt_vm_config_file="config.env.kvm_vnt_vm"

# Network related definitions (update according to local environment)
kvm_ovs_network_name="kvm-ovs-network"
kvm_ovs_network_definitions_path="/home/rolaya/proj/ovs/fork/base/ovs"
kvm_ovs_network_definition_file="kvm-ovs-network.xml"

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

  echo "Configuration file:              [$g_kvm_vnt_vm_config_file]"
  echo "Host name:                       [$HOSTNAME]"
  echo "Sourced time:                    [$g_sourced_datetime]"
  echo "Current time:                    [$datetime]"
  echo "KVM VNT VM name:                 [$KVM_VNT_VM_NAME]"
  echo "KVM VNT VM RAM:                  [$KVM_VNT_VM_RAM]"
  echo "KVM VNT VM size:                 [$KVM_VNT_VM_SIZE]"
  echo "KVM install graphics option:     [$KVM_INSTALL_OPTION_GRAPHICS]"
  echo

  # Deployment
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}Deployment"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"
  show_menu_option "kvm_vnt_vm_install            " " - Install KVM VNT VM"
  show_menu_option "kvm_vnt_vm_purge              " " - \"$KVM_VNT_VM_NAME\" VM purge"
  show_menu_option "kvm_vnt_vm_snapshot_create    " " - \"$KVM_VNT_VM_NAME\" VM snapshot create"
  show_menu_option "kvm_vnt_vm_start              " " - \"$KVM_VNT_VM_NAME\" VM start"
}

#==================================================================================================================
# 
#==================================================================================================================
kvm_vnt_vm_purge()
{
  local command=""

  command="sudo virsh undefine $KVM_VNT_VM_NAME"
  echo "Executing: [$command]"
  $command

  command="sudo virsh destroy $KVM_VNT_VM_NAME"
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

  command="sudo virsh snapshot-create-as --domain $KVM_VNT_VM_NAME --name $snapshot_name"
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
# 
#==================================================================================================================
kvm_vnt_vm_start()
{
  local command=""

  command="sudo virsh start --console --force-boot $KVM_VNT_VM_NAME"
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
               --name $KVM_VNT_VM_NAME
               --os-type=Linux
               --os-variant=centos7.0
               --network bridge=br0-wired
               --ram=$KVM_VNT_VM_RAM
               --vcpus=1
               --disk path=$KVM_LIBVIRT_IMAGES_PATH/$KVM_VNT_VM_NAME.img,bus=virtio,size=$KVM_VNT_VM_SIZE
               --graphics $KVM_INSTALL_OPTION_GRAPHICS
               --location /home/rolaya/iso/CentOS-7-x86_64-DVD-1908.iso
               --extra-args console=ttyS0"
  echo "Executing: [$command]"
  $command                 
}

#==================================================================================================================
# Installs "main" CentOS VM on a KVM based hypervisor.
#==================================================================================================================
kvm_vm_install()
{
  local command=""
  local vn_name=${1:-"vm_name_is_required"}

  command="sudo virt-install
               --name $vn_name
               --os-type=Linux
               --os-variant=centos7.0
               --network bridge=br0-wired
               --ram=$KVM_VNT_VM_RAM
               --vcpus=1
               --disk path=$KVM_LIBVIRT_IMAGES_PATH/$vn_name.img,bus=virtio,size=$KVM_VNT_VM_SIZE
               --graphics $KVM_INSTALL_OPTION_GRAPHICS
               --location /home/rolaya/iso/CentOS-7-x86_64-DVD-1908.iso
               --extra-args console=ttyS0"
  echo "Executing: [$command]"
  $command                 
}

#==================================================================================================================
#
#==================================================================================================================
kvm_vnt_node_install()
{
  local command=""
  local kvm_ram=${1:-$kvm_default_ram}
  local kvm_size=${2:-$kvm_default_size}

  command="sudo virt-install
               --name kvm_node1
               --description \"VTNnode1\"
               --os-type=Linux
               --os-variant=debian9
               --ram=$kvm_ram
               --vcpus=1
               --disk path=/var/lib/libvirt/images/kvm_node1.img,bus=virtio,size=$kvm_size
               --network network:$kvm_ovs_network_name
               --graphics none
               --location /home/rolaya/iso/debian-9.11.0-amd64-netinst.iso 
               --extra-args console=ttyS0"
  echo "Executing: [$command]"
  $command                 
}

#==================================================================================================================
#
#==================================================================================================================
kvm_ovs_network_provision()
{
  local command=""

  command="sudo virsh net-define $kvm_ovs_network_definitions_path/$kvm_ovs_network_definition_file"
  echo "Executing: [$command]"
  $command  

  command="sudo virsh net-start $kvm_ovs_network_name"
  echo "Executing: [$command]"
  $command  
  
  command="sudo virsh net-autostart $kvm_ovs_network_name"
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
}

# Capture time when file was sourced 
g_sourced_datetime="$(date +%c)"

# Provision environment based on configuration file
kvm_read_configuration

# Display helper "menu"
kvm_utils_show_menu