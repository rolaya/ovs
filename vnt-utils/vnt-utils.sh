#!/bin/sh

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
  echo "KVM VNT VM name:                 [$KVM_VNT_HOST_NAME]"
  echo "KVM VNT VM RAM:                  [$KVM_VNT_HOST_RAM]"
  echo "KVM VNT VM size:                 [$KVM_VNT_HOST_SIZE]"
  echo

  # Deployment
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}Deployment"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"
  show_menu_option "kvm_vnt_vm_install                        " " - Install KVM VNT VM"
}

#==================================================================================================================
# Installs "main" CentOS VM on a KVM based hypervisor.
#==================================================================================================================
kvm_vnt_vm_install()
{
  local command=""

  command="sudo virt-install
               --name $KVM_VNT_HOST_NAME
               --os-type=Linux
               --os-variant=centos7.0
               --network bridge=virbr0
               --ram=$KVM_VNT_HOST_RAM
               --vcpus=1
               --disk path=$KVM_LIBVIRT_IMAGES_PATH/$KVM_VNT_HOST_NAME.img,bus=virtio,size=$KVM_VNT_HOST_SIZE
               --graphics vnc,listen=0.0.0.0 --noautoconsole
               --location /home/rolaya/iso/CentOS-7-x86_64-DVD-1908.iso
               --boot kernel_args="console=ttyS0"
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