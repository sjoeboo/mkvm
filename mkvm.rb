#!/usr/bin/env ruby
#
# Author: Matthew Nicholson
# Github: http://github.com/sjoeboo/mkvm
#
# "Simple" Script to:
#   * Create a vm in VMware
#   * Set vm to PXE boot
#   * Create host entry in Foreman for the vm
#
#   (It is assumed that DNS/dhcp is either out of scope, or foreman controls it)

#Requirements
require 'yaml'
require 'optparse'
require 'fog'
require 'pp'


default_options = {
  :vmware_host => 'vmware',
  :vmware_user => 'vmware',
  :vmware_passwd => 'vmware',
  :verbose => false,
  :secure => false,
}

options = default_options
OptionParser.new do |opts|
  opts.banner = "Usage: mkvm.rb [options]"
  opts.on("-v", "--verbose", "Run verbosely") do
    options[:verbose] = true
  end
  opts.on("-h", "--host VMWARE_HOST", "VMWware Host") do |host|
    options[:vmware_host] = host
  end
  opts.on("-u", "--user VMWARE_USER", "VMWware User") do |user|
    options[:vmware_user] = user
  end
  opts.on("-p", "--passwd VMWARE_PASSWD", "VMWware password") do |passwd|
    options[:vmware_passwd] = passwd
  end
  opts.on("-s", "--secure", " SSL cert validation for VMWare") do
    options[:vmware_secure] = true
  end
  opts.on("-d", "--datacenter VMWARE_DATACENTER", "VMWare Datacenter") do |datacenter|
    options[:vmware_datacenter] = datacenter
  end
  opts.on("-d", "--folder VMWARE_FOLDER", "VMWare Folder to use as base") do |folder|
    options[:vmware_folder] = folder
  end
  opts.on("-c", "--configfile PATH", String, "Set config file") do |path|
    options.merge!(Hash[YAML::load(open(path)).map { |k, v| [k.to_sym, v] }])
  end
end.parse!

if options[:verbose] == true
  pp options
end


credentials = {
    :provider	=> "vsphere",
    :vsphere_username	=> options[:vmware_user],
    :vsphere_password	=> options[:vmware_passwd],
    :vsphere_server	=> options[:vmware_host],
    :vsphere_ssl	=> options[:secure],
    :vsphere_expected_pubkey_hash => options[:vmware_pubkey],
}
connection = Fog::Compute.new(credentials)
folders = connection.list_folders(datacenter: options[:vmware_datacenter], path: options[:vmware_folder])
clusters = connection.list_clusters(datacenter: options[:vmware_datacenter])
networks = connection.list_networks(datacenter: options[:vmware_datacenter])
datastores = connection.list_datastores(datacenter: options[:vmware_datacenter])

#pp folders
#pp clusters
#pp networks
#pp datastores
folders.each do |folder|
  if  folder[:name] == options[:vmware_folder]
    next
  elsif folder[:parent] == options[:vmware_folder]
    puts "#{folder[:name]}"
  end
end
