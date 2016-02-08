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
  :host_group => nil,
  :media => nil,
  :os => nil,
  :ptable => nil,
}
#Fetch hostgroups
def get_hg_list()
  hg_list = YAML.load(`hammer --output yaml hostgroup list`)
  return hg_list
end
#prompt for HG w/ menu
def prompt_hg(hg_list)
  puts "Select an Host Group (#):"
  hg_list.each do |hg|
    puts "#{hg['Id']}) #{hg['Title']}"
  end
  puts "Host Group #:"
  hg_id=gets.strip
  return hg_id.to_i
end
#fetch os
def get_os_list()
  os_list = YAML.load(`hammer --output yaml os list`)
  return os_list
end
#Prompt for OS with a menu
def prompt_os(os_list)
  puts "Select an Operating System (#):"
  os_list.each do |o|
    puts "#{o['Id']}) #{o['Title']}"
  end
  puts "Operating System #:"
  os_id=gets.strip
  return os_id.to_i
end
#fetch media
def get_media_list()
  media_list = YAML.load(`hammer --output yaml medium list`)
  return media_list
end
#Prompt for media list
def prompt_media(media_list)
  puts "Select Installation Media (#):"
  media_list.each do |m|
    puts "#{m['Id']}) #{m['Name']} (#{m['Path']})"
  end
  puts "Installation Media #:"
  m_id=gets.strip
  return m_id.to_i
end

#fetch p tables
def get_p_table_list()
  p_table_list = YAML.load(`hammer --output yaml partition-table list`)
end
#prompt for ptable
def prompt_ptable(pt_list)
  puts "Select a Partition Table (#):"
  pt_list.each do |pt|
    puts "#{pt['Id']}) #{pt['Name']} (#{pt['OS Family']})"
  end
  puts "Partition Table #:"
  pt_id=gets.strip
  return pt_id.to_i
end

#Option Parsing
options = default_options
OptionParser.new do |opts|
  opts.banner = "Usage: mkvm.rb [options]"
  opts.on("-v", "--verbose", "Run verbosely") do
    options[:verbose] = true
  end
  opts.on("-g", "--group=host_group",Integer, "Host Group") do |group|
    options[:host_group] = group.to_i
  end
  opts.on("-o", "--os=os-id", Integer, "Operating System") do |os|
    options[:os] = os.to_i
  end
  opts.on("-m", "--media=media-id",Integer, "Installation Media") do |media|
    options[:media] = media.to_i
  end
  opts.on("-p", "--ptable=partition-table-id",Integer, "Partition Table") do |p|
    options[:ptable] = p.to_i
  end
  opts.on("-c", "--configfile PATH", String, "Set config file") do |path|
    options.merge!(Hash[YAML::load(open(path)).map { |k, v| [k.to_sym, v] }])
  end
end.parse!

if options[:verbose] == true
  pp options
end

#get info to check/prompt if needed
p "Getting Foreman info"
os_list  = get_os_list()
media_list = get_media_list()
p_table_list = get_p_table_list()
hg_list = get_hg_list()

#Check empty options and give prompt/menu
if options[:os] == nil
  options[:os]=prompt_os(os_list)
end
if options[:host_group] == nil
  options[:host_group]=prompt_hg(hg_list)
end
if options[:media] == nil
  options[:media]=prompt_media(media_list)
end
if options[:ptable] == nil
  options[:ptable]=prompt_ptable(p_table_list)
end
#Check options exist in Foreman
if os_list.select { |o| o['Id'] ==  options[:os]} == []
  abort "I'm sorry, the OS id #{options[:os]} does not exist in foreman, exiting."
end
#options[:hostgroup]
if hg_list.select { |h| h['Id'] ==  options[:host_group]} == []
  abort "I'm sorry, the Host Group id #{options[:os]} does not exist in foreman, exiting."
end
#options[:media]
if media_list.select { |m| m['Id'] ==  options[:media]} == []
  abort "I'm sorry, the Installation Media id #{options[:os]} does not exist in foreman, exiting."
end
#options[:ptable]
if p_table_list.select { |p| p['Id'] ==  options[:ptable]} == []
  abort "I'm sorry, the Partition Table id #{options[:os]} does not exist in foreman, exiting."
end
