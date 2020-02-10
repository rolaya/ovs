#!/bin/sh

# Source host and environment specific VNT configuration
source "ui-utils.sh"

# The global configuration file for CentOS VNT VM
g_centos_config_file="config.env.kvm_vnt_host"

#==================================================================================================================
#
#==================================================================================================================
centos_utils_show_menu()
{
  local datetime=""

  # Environment 
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}Environment"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"

  # Get date/time (useful for keeping track of changes)
  datetime="$(date +%c)"

  echo "Kernel version:                           [$(uname -r)]"
  echo "CentOS 7 KVM VNT host configuration file: [$g_centos_config_file]"
  echo "Physical host name:                       [$HOSTNAME]"
  echo "Sourced time:                             [$g_sourced_datetime]"
  echo "Current time:                             [$datetime]"  
  echo "KVM VNT host name:                        [$KVM_VNT_HOST_NAME]"

  # VNT host deployment
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}VNT host deployment"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"
  show_menu_option "centos_describe_provisioning   " " - \"$KVM_VNT_HOST_NAME\" VM install steps"
  show_menu_option "centos_provision               " " - \"$KVM_VNT_HOST_NAME\" VM install"
}

#==================================================================================================================
#
#==================================================================================================================
centos_describe_provisioning()
{
  local datetime=""

  show_config_section "General system configuration"

  show_config_item "update /etc/hosts as required to access hosts in local network by name (sudo required)"
  show_config_item "sudo yum update"
  show_config_item "sudo yum group install \"Virtualization Host\""
  show_config_item "sudo yum group install \"Development Tools\""
  show_config_item "sudo yum install qemu-kvm"
  show_config_item "sudo yum install libvirt"
  show_config_item "sudo yum install virt-install"
  show_config_item "sudo yum install virt-viewer"
  show_config_item "sudo yum install virt-manager"
  show_config_item "sudo systemctl start libvirtd"
  show_config_item "sudo systemctl enable libvirtd"
  show_config_item "sudo systemctl status libvirtd"
  show_config_item "sudo setfacl -m u:qemu:rx /home/rolaya"
  show_config_item "sudo yum install git"
  show_config_item "sudo yum install rpm-build"
  show_config_item "sudo yum install openssl-devel"
  show_config_item "sudo yum install python-devel"
  show_config_item "sudo yum install groff"
  show_config_item "sudo yum install graphviz"
  show_config_item "sudo yum install checkpolicy"
  show_config_item "sudo yum install selinux-policy-devel"
  show_config_item "sudo yum install python-twisted-core"
  show_config_item "sudo yum install libcap-ng-devel"
  show_config_item "sudo yum install unbound"
  show_config_item "sudo yum install unbound-devel"
  show_config_item "sudo yum install python-sphinx"
  show_config_item "centos_ovs_provision"
  show_config_item "update /etc/sysconfig/network-scripts configuration files for OVS"
  show_config_item "deploy_network ?????"
  show_config_item "kvm_ovs_network_provision"
  show_config_item "kvm_vnt_node_install (node configuraion in file config.env.kvm_vnt_node)"
  show_config_item "kvm_vnt_node_start"

  note_init "To fix guest stuck at \"Loading initial ramdisk\". Add \"console=ttyS0\" to boot option:"
  note_add "\"linux /vmlinuz-4.9.0-12-amd64\" during boot. This requires entering editing mode"
  note_add "immediately at boot time via \"e\" option"
}

#==================================================================================================================
#
#==================================================================================================================
bash_execute_command()
{
  local command=$1
  
  # Display bash command being executed.
  echo "Executing: [$command]"
  $command
}

#==================================================================================================================
#
#==================================================================================================================
centos_ovs_provision()
{
  local ovs_build_dir="/$HOME/rpmbuild/SOURCES"

  # Install additional OVS build dependencies
  bash_execute_command "sudo yum install wget -y"
  bash_execute_command "sudo yum -y install gcc"
  bash_execute_command "sudo yum -y install gcc-c++"
  bash_execute_command "sudo yum -y install autoconf"
  bash_execute_command "sudo yum -y install automake"
  bash_execute_command "sudo yum -y install libtool"
  bash_execute_command "sudo yum -y install desktop-file-utils"

  # Download "latest" release version of ovs  and unzip on its own build directory.
  bash_execute_command "mkdir -p $ovs_build_dir"
  bash_execute_command "cd $ovs_build_dir"
  bash_execute_command "wget https://www.openvswitch.org/releases/openvswitch-2.12.0.tar.gz"
  bash_execute_command "tar xfz openvswitch-2.12.0.tar.gz"

  # Build OVS RPM and install it.
  bash_execute_command "rpmbuild -bb --nocheck openvswitch-2.12.0/rhel/openvswitch-fedora.spec"
  bash_execute_command "sudo yum install /home/rolaya/rpmbuild/RPMS/x86_64/openvswitch-2.12.0-1.el7.x86_64.rpm -y"

  # Start OVS and enable to start on boot 
  bash_execute_command "sudo systemctl start openvswitch.service"
  bash_execute_command "sudo systemctl enable openvswitch.service"
  bash_execute_command "sudo systemctl status openvswitch.service"  

  # Return to previous dir.
  cd -
}

#==================================================================================================================
#
#==================================================================================================================
centos_provision()
{
  #show_config_item "update /etc/hosts as required to access hosts in local network by name (sudo required)"
  bash_execute_command "sudo yum update -y"
  bash_execute_command "sudo yum group install \"Virtualization Host\" -y"
  bash_execute_command "sudo yum group install \"Development Tools\" -y"
  bash_execute_command "sudo yum install qemu-kvm"
  bash_execute_command "sudo yum install libvirt -y"
  bash_execute_command "sudo yum install virt-install -y"
  bash_execute_command "sudo yum install virt-viewer -y"
  bash_execute_command "sudo yum install virt-manager -y"
  bash_execute_command "sudo systemctl start libvirtd"
  bash_execute_command "sudo systemctl enable libvirtd"
  bash_execute_command "sudo systemctl status libvirtd"
  bash_execute_command "sudo setfacl -m u:qemu:rx /home/rolaya"
  bash_execute_command "sudo yum install git -y"
  bash_execute_command "sudo yum install rpm-build -y"
  bash_execute_command "sudo yum install openssl-devel -y"
  bash_execute_command "sudo yum install python-devel -y"
  bash_execute_command "sudo yum install groff -y"
  bash_execute_command "sudo yum install graphviz -y"
  bash_execute_command "sudo yum install checkpolicy -y"
  bash_execute_command "sudo yum install selinux-policy-devel -y"
  bash_execute_command "sudo yum install python-twisted-core -y"
  bash_execute_command "sudo yum install libcap-ng-devel -y"
  bash_execute_command "sudo yum install unbound -y"
  bash_execute_command "sudo yum install unbound-devel -y"
  bash_execute_command "sudo yum install python-sphinx -y"

  # Provision released version of OVS
  centos_ovs_provision

  #bash_execute_command "update /etc/sysconfig/network-scripts configuration files for OVS"
  #bash_execute_command "deploy_network"
}

#==================================================================================================================
#
#==================================================================================================================
function centos_read_configuration()
{
  # Source host and environment specific VNT configuration
  source "$g_centos_config_file"
}

# Capture time when file was sourced 
g_sourced_datetime="$(date +%c)"

# Provision environment based on configuration file
centos_read_configuration

# Display helper "menu"
centos_utils_show_menu
