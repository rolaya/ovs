#!/bin/sh

# Source host and environment specific VNT configuration
source "ui-utils.sh"

# The global configuration file for CentOS VNT VM
g_centos_config_file="config.env.kvm_vnt_vm"

#==================================================================================================================
#
#==================================================================================================================
centos_describe_provisioning()
{
  local datetime=""

  # Environment 
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}Environment"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"

  # Get date/time (useful for keeping track of changes)
  datetime="$(date +%c)"

  echo "Kernel version:                  [$(uname -r)]"
  echo "Configuration file:              [$g_centos_config_file]"
  echo "Host name:                       [$HOSTNAME]"
  echo "Sourced time:                    [$g_sourced_datetime]"
  echo "Current time:                    [$datetime]"
  echo "KVM VNT VM name:                 [$KVM_VNT_HOST_NAME]"
  echo

  show_config_section "General system configuration"

  nfs_show_config_item "update /etc/hosts as required to access hosts in local network by name (sudo required)"
  nfs_show_config_item "sudo yum update"
  nfs_show_config_item "sudo yum group install \"Virtualization Host\""
  nfs_show_config_item "sudo yum group install \"Development Tools\""
  nfs_show_config_item "sudo yum install git"
  nfs_show_config_item "sudo yum install rpm-build"
  nfs_show_config_item "sudo yum install openssl-devel"
  nfs_show_config_item "sudo yum install python-devel"
  nfs_show_config_item "sudo yum install groff"
  nfs_show_config_item "sudo yum install graphviz"
  nfs_show_config_item "sudo yum install checkpolicy"
  nfs_show_config_item "sudo yum install selinux-policy-devel"
  nfs_show_config_item "sudo yum install python-twisted-core"
  nfs_show_config_item "sudo yum install libcap-ng-devel"
  nfs_show_config_item "sudo yum install unbound"
  nfs_show_config_item "sudo yum install unbound-devel"
  nfs_show_config_item "sudo yum install python-sphinx"
  nfs_show_config_item "wget https://www.openvswitch.org/releases/openvswitch-2.12.0.tar.gz"
  nfs_show_config_item "rpmbuild -bb --nocheck openvswitch-2.12.0/rhel/openvswitch-fedora.spec"
  nfs_show_config_item "sudo yum install /home/rolaya/rpmbuild/RPMS/x86_64/openvswitch-2.12.0-1.el7.x86_64.rpm -y"
  nfs_show_config_item "sudo systemctl start openvswitch.service"
  nfs_show_config_item "sudo systemctl enable openvswitch.service"
  nfs_show_config_item "sudo systemctl status openvswitch.service"
  nfs_show_config_item "update /etc/sysconfig/network-scripts configuration files for OVS"
  nfs_show_config_item "deploy_network"
}

#==================================================================================================================
#
#==================================================================================================================
function kvm_read_configuration()
{
  # Source host and environment specific VNT configuration
  source "$g_centos_config_file"
}

# Capture time when file was sourced 
g_sourced_datetime="$(date +%c)"

# Provision environment based on configuration file
kvm_read_configuration

# Display helper "menu"
centos_describe_provisioning
