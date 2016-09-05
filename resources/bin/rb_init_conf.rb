#!/usr/bin/env ruby

# Run initial server configuration from /etc/redborder/rb_init_conf.yml
# 1. Set hostname + cdomain
# 2. Configure network (on-premise only)
# 3. Configure dns (on-premise only)
# 4. Create serf configuration files
#
# note: Don't calculate encrypt_key

require 'yaml'
require 'ipaddr'
require 'netaddr'
require 'system/getifaddrs'
require 'json'
require '/usr/lib/redborder/bin/rb_config_utils.rb'

RBETC = ENV['RBETC'].nil? ? '/etc/redborder' : ENV['RBETC']
INITCONF="#{RBETC}/rb_init_conf.yml"

init_conf = YAML.load_file(INITCONF)

hostname = init_conf['hostname']
cdomain = init_conf['cdomain']
network = init_conf['network']
sync_net = init_conf['sync_net']

# Configure HOSTNAME and CDOMAIN
if Config_utils.check_hostname(hostname)
  if Config_utils.check_domain(cdomain)
    system("hostnamectl set-hostname \"#{hostname}.#{cdomain}\"")
  else 
    p err_msg = "Invalid cdomain. Please review #{INITCONF} file"
    system("logger -t rb_init_conf #{err_msg}")
    exit 1
  end
else
  p err_msg = "Invalid hostname. Please review #{INITCONF} file"
  system("logger -t rb_init_conf #{err_msg}")
  exit 1
end

if !network.nil? # network will not be defined in cloud deployments

  # Disable and stop NetworkManager
  system('systemctl disable NetworkManager')
  system('systemctl stop NetworkManager')

  # Configure DNS
  dns = network['dns']
  open("/etc/sysconfig/network", "w") { |f|
    dns.each_with_index do |dns_ip, i|
      if Config_utils.check_ipv4({:ip => dns_ip})
        f.puts "DNS#{i+1}=#{dns_ip}"
      else
        p err_msg = "Invalid DNS Address. Please review #{INITCONF} file"
        system("logger -t rb_init_conf #{err_msg}")
        exit 1
      end
    end
    f.puts "SEARCH=#{cdomain}"
  }

  # Configure NETWORK
  network['interfaces'].each do |iface|
    dev = iface['device']
    mode = iface['mode']
    open("/etc/sysconfig/network-scripts/ifcfg-#{dev}", 'w') { |f|
      if mode != 'dhcp'
        if Config_utils.check_ipv4({:ip => iface['ipaddr'], :netmask => iface['netmask']})  and Config_utils.check_ipv4(:ip => iface['gateway'])
          f.puts "IPADDR=#{iface['ipaddr']}"
          f.puts "NETMASK=#{iface['netmask']}"
          f.puts "GATEWAY=#{iface['gateway']}" if !iface['gateway'].nil?
        else
          p err_msg = "Invalid network configuration for device #{dev}. Please review #{INITCONF} file"
          system("logger -t rb_init_conf #{err_msg}")
          exit 1
        end
      end
      dev_uuid = File.read("/proc/sys/kernel/random/uuid").chomp
      f.puts "BOOTPROTO=#{mode}"
      f.puts "DEVICE=#{dev}"
      f.puts "ONBOOT=yes"
      f.puts "UUID=#{dev_uuid}"
    }
  end

  # Restart NetworkManager
  system('service network restart &> /dev/null')
end

######################
# Serf configuration #
######################
SERFJSON="/etc/serf/00first.json"
TAGSJSON="/etc/serf/tags"

serf_conf = {}
serf_tags = {}
node_role = "undef" # Check

# local IP to bind to
if !sync_net.nil?
    # Initialize network device
    System.get_all_ifaddrs.each do |netdev|
        if IPAddr.new(sync_net).include?(netdev[:inet_addr])
            serf_conf["bind"] = netdev[:inet_addr].to_s
        end
    end
    if serf_conf["bind"].nil?
        p "Error: no IP address to bind"
        exit(1)
    end
else
  p "Error: unknown sync network"
  exit (1)
end

serf_conf["tags_file"] = TAGSJSON
serf_conf["node_name"] = hostname

# defined role in tags
serf_tags["role"] = node_role

# Create json file configuration
file_serf_conf = File.open(SERFJSON,"w")
file_serf_conf.write(serf_conf.to_json)
file_serf_conf.close

# Create json tags file
file_serf_tags = File.open(TAGSJSON,"w")
file_serf_tags.write(serf_tags.to_json)
file_serf_tags.close
