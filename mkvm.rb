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
#require 'fog'
require 'pp'


default_options = {
  #:vmware_host => 'vmware',
  #:vmware_user => 'vmware',
  #:vmware_passwd => 'vmware',
  :verbose => false,
  :arch => 'x86_64',
  :host_group => 'default',
}

def get_os_list()
  os_list = YAML.load(`hammer --output yaml os list`)
  return os_list
end

def get_media_list()
  media_list = YAML.load(`hammer --output yaml medium list`)
  return media_list
end

def get_p_table_list()
  p_table_list = YAML.load(`hammer --output yaml partition-table list`)
end

options = default_options
OptionParser.new do |opts|
  opts.banner = "Usage: mkvm.rb [options]"
  opts.on("-v", "--verbose", "Run verbosely") do
    options[:verbose] = true
  end
  opts.on("-g", "--group host_group", "Host Group") do |group|
    options[:houst_group] = group
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

os_list=get_media_list
pp os_list
