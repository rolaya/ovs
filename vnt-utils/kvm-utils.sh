#!/bin/sh

# Source host and environment specific VNT configuration
source "ui-utils.sh"

# The global configuration file for CentOS VNT VM
g_kvm_vnt_vm_config_file="config.env.kvm_vnt_vm"

#               --graphics vnc,password=tbuser,port=5910,keymap=en-us


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
  show_menu_option "kvm_vnt_vm_purge              " " - Purge KVM VNT VM"
  show_menu_option "kvm_vnt_vm_snapshot_create    " " - Create KVM VNT VM snapshot"
  show_menu_option "kvm_vnt_vm_start              " " - Start KVM VNT VM"
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
               --network bridge=virbr0
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