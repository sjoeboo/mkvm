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

#Fetch foreman data
def get_foreman_list(debug,thing)
  if debug == true
    hammer_cmd = "hammer --output yaml --debug #{thing} list"
  else
    hammer_cmd = "hammer --output yaml #{thing} list"
  end
  list = YAML.load(`#{hammer_cmd}`)
  return list
end

#prompt/menu
def prompt_menu(list,fields,desc)
  puts "Please select a(n) #{desc}:"
  list.each do |i|
    line = ""
    fields.each do |f|
      if f == 'Id'
        line = line + "#{i[f]}) "
      else
        line = line + "#{i[f]} "
      end
    end
    puts line
  end
  puts "#{desc} #:"
  selection = gets.strip.to_i
  return selection
end

def pick_datastore(datastore_in)
  #We CAN pass datastore as a string, or array of strings.
  # If Array, randomly pick one. else just return the string
  if datastore_in.kind_of?(Array)
    datastore=datastore_in.sample
  else
    datastore=datastore_in
  end
  return datastore
end

#Defaults for options.
default_options = {
  :verbose => false, # -v
  :debug => false, #-d/--debug
  :arch => 'x86_64', # -a
  :host_group => nil, #-g
  :media => nil, #-m
  :os => nil, #-o
  :ptable => nil, #-p
  :compute_resource => nil, #-r
  :cpus => 1, # -x
  :memory => 512, # -q
  :managed => false, #-z
  :guest_type => nil, # -t
  :path => nil, # -e
  :cluster => nil, #-b
  :nic_type => 'VirtualE1000', #-i
  :nic_network => nil, #-l
  :nic_name => nil, #-u
  :volume_datastore => nil, #-w
  :volume_size => nil #-s

}

#Option Parsing
options = default_options
OptionParser.new do |opts|
  opts.banner = "Usage: mkvm.rb [options]"
  opts.on("-a", "--arch",String, "Architecture") do |arch|
    options[:arch] = arch
  end
  opts.on("-c", "--configfile PATH", String, "Set config file") do |path|
    options.merge!(Hash[YAML::load(open(path)).map { |k, v| [k.to_sym, v] }])
  end
  opts.on("-d", "--debug", "Pass --debug to all hammer commands") do
    options[:debug] = true
  end
  opts.on("-e", "--path",String, "Folder Path for VM") do |path|
    options[:path] = path
  end
  opts.on("-g", "--group=host_group",Integer, "Host GroupID ") do |group|
    options[:host_group] = group.to_i
  end
  opts.on("-m", "--media",Integer, "Installation MediaID ") do |media|
    options[:media] = media.to_i
  end
  opts.on("-o", "--os", Integer, "Operating System ID") do |os|
    options[:os] = os.to_i
  end
  opts.on("-p", "--ptable",Integer, "Partition Table ID") do |ptable|
    options[:ptable] = p.to_i
  end
  opts.on("-r", "--compute-resource",Integer, "Compute Resource ID") do |r|
    options[:compute] = r.to_i
  end
  opts.on("-v", "--verbose", "Run verbosely") do
    options[:verbose] = true
  end

end.parse!

if options[:verbose] == true
  pp options
end

#get info to check/prompt if needed
p "Getting Foreman info"
os_list = get_foreman_list(options[:debug],"os")
media_list = get_foreman_list(options[:debug],"medium")
p_table_list= get_foreman_list(options[:debug],"partition-table")
hg_list=get_foreman_list(options[:debug],"hostgroup")
cr_list=get_foreman_list(options[:debug],"compute-resource")

#Check empty options and give prompt/menu
if options[:os] == nil
  options[:os] = prompt_menu(os_list,['Id','Title'],'Operating System')
end
if options[:host_group] == nil
  options[:host_group]=prompt_menu(hg_list,['Id','Title'],'Host Group')
end
if options[:media] == nil
  options[:media]=prompt_menu(media_list,['Id','Name', 'Path'],'Operating System')
end
if options[:ptable] == nil
  options[:ptable]=prompt_menu(p_table_list,['Id','Name', 'OS Family'],'Partition Table')
end
if options[:compute_resource] == nil
  options[:compute_resource]=prompt_menu(cr_list,['Id','Name','Provider'],'Compute Resource')
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
#options[:compute_resource]
if cr_list.select { |c| c['Id'] ==  options[:compute_resource]} == []
  abort "I'm sorry, the compute_resource id #{options[:os]} does not exist in foreman, exiting."
end

#Choose a data store from the possible list.
options[:volume_datastore] = pick_datastore(options[:volume_datastore])
pp options[:volume_datastore]




#hammer -d host create --architecture x86_64 --medium-id 8 --partition-table-id 55 --name mn174-test --hostgroup-id 1 --compute-resource-id 1 --compute-attributes cpus=1,memory_mb=512,cluster='MED RC Cluster 01',path='/Datacenters/HMSDATACENTER/vm/RC VMs (RC Support)/Dev' --interface=compute_type='VirtualE1000',compute_network='VLAN64',name=eth0,primary=true,identifier=eth0,managed=false,provision=true --volume datastore=RC-SANLUN01R6TK-INFINI,size=10,name=mn174-test
