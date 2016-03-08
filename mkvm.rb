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
require 'io/console'
#require 'fog'
require 'pp'

#check hammer authentication
#Fetch foreman data
def get_foreman_list(debug,thing,passwd)
  hammer_cmd = "hammer --output yaml"
  if debug == true
    hammer_cmd = hammer_cmd + " --debug"
  end
  if passwd !=nil
    hammer_cmd = hammer_cmd + " --password #{passwd}"
  end
  hammer_cmd =  hammer_cmd + " #{thing} list"

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

def passwd_prompt()
  puts "Foreman password:"
  passwd = STDIN.noecho {|i| i.gets}.chomp
  return passwd
end

#simple boolean test if the name is already in foreman or not.
def host_search(debug,name,passwd)
  hammer_cmd = "hammer --output yaml"
  if debug == true
    hammer_cmd = hammer_cmd + " --debug"
  end
  if passwd !=nil
    hammer_cmd = hammer_cmd + " --password #{passwd}"
  end
  hammer_cmd =  hammer_cmd + " host list --search #{name}"

  list = YAML.load(`#{hammer_cmd}`)
  if list == []
    return true
  else
    return false
  end
end

#craft the create host command
def create_host_cmd(options,passwd)
  hammer_cmd = "hammer"
  if options[:debug] == true
    hammer_cmd = hammer_cmd + " --debug"
  end
  if passwd !=nil
    hammer_cmd = hammer_cmd + " --password #{passwd}"
  end
  hammer_cmd = hammer_cmd + " host create --name #{options[:name]}"
  if options[:build] == true
    hammer_cmd = hammer_cmd + " --build true"
  else
    hammer_cmd = hammer_cmd + " --build false"
  end
  hammer_cmd = hammer_cmd + " --hostgroup-id #{options[:host_group]}"
  hammer_cmd = hammer_cmd + " --architecture-id #{options[:arch]}"
  hammer_cmd = hammer_cmd + " --operatingsystem-id #{options[:os]}"
  hammer_cmd = hammer_cmd + " --medium-id #{options[:media]}"
  hammer_cmd = hammer_cmd + " --partition-table-id #{options[:ptable]}"
  hammer_cmd = hammer_cmd + " --compute-resource-id #{options[:compute_resource]}"
  hammer_cmd = hammer_cmd + " --compute-attributes guest_id='#{options[:guest_type]}',cpus=#{options[:cpus]},memory_mb=#{options[:memory]},cluster='#{options[:cluster]}',path='#{options[:path]}',start=#{options[:start]}"
  if options[:nic_ip] != nil
    hammer_cmd = hammer_cmd + " --ip #{options[:nic_ip]}"
  end
  if options[:nic_mac] != nil
    hammer_cmd = hammer_cmd + " --mac #{options[:nic_mac]}"
  end
  hammer_cmd = hammer_cmd + " --interface=compute_type=#{options[:nic_type]},compute_network=#{options[:nic_network]},name=#{options[:name]},primary=true,identifier=#{options[:nic_name]},managed=#{options[:nic_managed]},provision=true"
  hammer_cmd = hammer_cmd + " --volume datastore=#{options[:volume_datastore]},size_gb=#{options[:volume_size]},name=#{options[:name]}"

  return hammer_cmd
end

def print_host_info(debug,name,passwd)
  hammer_cmd = "hammer "
  if debug == true
    hammer_cmd = hammer_cmd + " --debug"
  end
  if passwd !=nil
    hammer_cmd = hammer_cmd + " --password #{passwd}"
  end
  hammer_cmd = hammer_cmd + " host list --search #{name}"
  out=`#{hammer_cmd}`
  puts out
end


#Defaults for options.
default_options = {
  :verbose => false,
  :debug => false,
  :test => false,
  :passwd => false,
  :arch => '1',
  :host_group => 1,
  :media => nil,
  :os => 1,
  :ptable => 1,
  :compute_resource => 1,
  :cpus => 1, #-c
  :memory => 512,
  :guest_type => 'rhel7_64Guest',
  :path => nil,
  :cluster => nil,
  :nic_type => 'VirtualE1000',
  :nic_network => nil,
  :nic_name => 'eth0',
  :nic_managed => true,
  :nic_ip => nil,
  :nic_mac => nil,
  :volume_datastore => nil,
  :volume_size => 10,
  :quick => false,
  :start => true,
  :build => true,
}

#Option Parsing
options = default_options
OptionParser.new do |opts|
  opts.banner = "Usage: mkvm.rb [options] NAME"
  opts.on("-v", "--verbose", "Run verbosely [false]") do
    options[:verbose] = true
  end
  opts.on("-d", "--debug", "Pass --debug to all hammer commands [false]") do
    options[:debug] = true
  end
  opts.on("-f", "--configfile PATH", String, "Set config file (yaml, values will merge with defaults/cli options [nil]") do |path|
    options.merge!(Hash[YAML::load(open(path)).map { |k, v| [k.to_sym, v] }])
  end
  opts.on("-t", "--test", "Test, will not create vm, just output resulting hammer command[false]") do
    options[:test] = true
  end
  opts.on("-p", "--passwd", "Prompt for password to pass to hammer with each call [false]") do
    options[:passwd] = true
  end
  opts.on("-a", "--arch ARCH",Integer, "Architecture ID [1]") do |arch|
    options[:arch] = arch
  end
  opts.on("-c", "--cpus CPUS",Integer, "CPUS [1]") do |cpus|
    options[:cpus] = cpus
  end
  opts.on("-b", "--cluster CLUSTER",String,"VMware Cluster [nil]") do |clu|
    options[:cluster] = clu
  end
  opts.on("-e", "--path PATH",String, "Folder Path for VM [nil]") do |path|
    options[:path] = path
  end
  opts.on("-g", "--group HOST_GROUP",Integer, "Host GroupID [1]") do |group|
    options[:host_group] = group.to_i
  end
  opts.on("-i", "--media MEDIA",Integer, "Installation MediaID [nil] ") do |media|
    options[:media] = media.to_i
  end
  opts.on("-m", "--memory MEMORY",Integer, "Memory(RAM) in MB [512]") do |mem|
    options[:memory] = mem.to_i
  end
  opts.on( "--nic-name ETH0",String, "NIC name [eth0]") do |nic_name|
    options[:nic_name] = nic_name
  end
  opts.on( "--nic-network VLAN64",String, "Network/VLAN for NIC [VLAN01]") do |vlan|
    options[:nic_network] = vlan
  end
  opts.on( "--nic-type VirtualE1000",String, "NIC Hardware Type [VirtualE1000]") do |nic_type|
    options[:nic_type] = nic_type
  end
  opts.on( "--nic-ip 192.168.1.10",String, "NIC IP [nil]") do |nic_ip|
    options[:nic_ip] = nic_ip
  end
  opts.on( "--nic-mac 00:32:32:32:32",String, "NIC Mac [random]") do |nic_mac|
    options[:nic_mac] = nic_mac
  end
  opts.on( "--vol-datastore DATASTORE",String, "Datastore/LUN [nil]") do |ds|
    options[:volume_datastore] = ds
  end
  opts.on( "--vol-size SIZE_GB",Integer, "Volume size in GB [10]") do |vol_size|
    options[:volume_size] = vol_size
  end
  opts.on("-k", "--guest_type TYPE",String, "Guest Type ['Red Hat Enterprise  Linux 7 (64-bit)']") do |guest|
    options[:guest_type] = guest
  end
  opts.on("-l", "--nic_managed", "Set NIC to be foreman managed(DNS/DHCP) [false]") do |managed|
    options[:nic_managed] = managed
  end
  opts.on("-o", "--os OS", Integer, "Operating System ID" [1]) do |os|
    options[:os] = os.to_i
  end
  opts.on("-x", "--ptable PTABLE",Integer, "Partition Table ID [1]") do |ptable|
    options[:ptable] = p.to_i
  end
  opts.on("-r", "--compute-resource COMPUTE-RESOURCE",Integer, "Compute Resource ID [1]") do |r|
    options[:compute] = r.to_i
  end
  opts.on("-q", "--quick", "Quick/quiet Mode, ie, do not check foreman/prmopt for valid values before submitting, don't output host details at the end [false]") do |quick|
    options[:quick] = quick
  end
  opts.on("-u", "--start", "Start/Boot the vm after creation [false]") do |start|
    options[:start] = start
  end
  opts.on("-w", "--no-build", "Do not tell Foreman to build the host, only create ") do
    options[:build] = false
  end

end.parse!
options[:name] = ARGV.pop
raise "Need to specify a hostname/VM name" unless options[:name]

if options[:verbose] == true
  pp options
end

if options[:passwd] == true
  passwd = passwd_prompt()
else
  passwd = nil
end


#If in quick mode, no need to fetch data/check it
if options[:quick] == false
  #get info to check/prompt if needed
  puts "Getting Foreman info"
  os_list = get_foreman_list(options[:debug],"os",passwd)
  media_list = get_foreman_list(options[:debug],"medium",passwd)
  p_table_list= get_foreman_list(options[:debug],"partition-table",passwd)
  hg_list=get_foreman_list(options[:debug],"hostgroup",passwd)
  cr_list=get_foreman_list(options[:debug],"compute-resource",passwd)
  arch_list=get_foreman_list(options[:debug],'architecture',passwd)
  #can do a search for hosts so we don't need ot get them all, plus we're not going to prompt for it with a menu.
  #compute, interface, and volume attributes can't be checked...?

  #Check empty options and give prompt/menu
  if options[:arch] == nil
    options[:arch] = prompt_menu(arch_list,['Id','Name'],'Arch')
  end
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
  puts "Checking validity..."
  #Check if name/hostname is taken already
  if !host_search(options[:debug],options[:name],passwd)
    abort "Host/VM name is already taken, please try again."
  end

  if arch_list.select { |a| a['Id'] ==  options[:arch]} == []
    abort "I'm sorry, the Arch id #{options[:arch]} does not exist in foreman, exiting."
  end
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
end

#Choose a data store from the possible list.
options[:volume_datastore] = pick_datastore(options[:volume_datastore])

hammer_cmd = create_host_cmd(options,passwd)

if options[:test] == true
  puts "Test mode, I would have run the command:"
  puts hammer_cmd
  abort "Exiting"
else
  puts "Making VM.."
  `#{hammer_cmd}`
end

if options[:quick] != true && options[:test] != true
  #show host info
  print_host_info(options[:debug],options[:name],passwd)
end
