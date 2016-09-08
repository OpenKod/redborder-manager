#!/usr/bin/env ruby

require 'digest'
require 'base64'
require 'yaml'
require 'net/ip'
require 'system/getifaddrs'
require 'netaddr'
require 'base64'

module Config_utils


    @modelist_path="/usr/lib/redborder/mode-list.yml"
    #Function to check if mode is valid (if defined in mode-list.yml)
    #Returns true if it's valid and false if not
    #TODO: protect from exception like file not found
    def Config_utils.check_mode(mode)
        mode_list = YAML.load_file(@modelist_path)
        return mode_list.include?(mode)
    end

    # Function that return an encript key from a provided string
    # compliance with serf encrypt_key (password of 16 bytes in base64 format)
    def self.get_encrypt_key(password)
        ret = nil
        unless password.nil?
            if password.class == String
                ret = Base64.encode64(Digest::MD5.hexdigest(password)[0..15]).chomp
            end
        end
        ret
    end

    # Function to check if mode is valid (if defined in mode-list.yml)
    # Returns true if it's valid and false if not
    # TODO: protect from exception like file not found
    def self.check_mode(mode)
        mode_list = YAML.load_file(MODELIST_PATH)
        return mode_list.include?(mode)
    end

    # Function to check a valid IPv4 IP address
    # ipv4 parameter can be a hash with two keys:
    # - :ip -> ip to be checked
    # - :netmask -> mask to be checked
    # Or can be a string with CIDR or standard notation.
    def self.check_ipv4(ipv4)
        ret = true
        begin
            # convert ipv4 from string format "192.168.1.0/255.255.255.0" into hash {:ip => "192.168.1.0", :netmask => "255.255.255.0"}
            if ipv4.class == String
                unless ipv4.match(/^(?<ip>\d+\.\d+\.\d+\.\d+)\/(?<netmask>(?:\d+\.\d+\.\d+\.\d+)|\d+)$/).nil?
                    ipv4 = ipv4.match(/^(?<ip>\d+\.\d+\.\d+\.\d+)\/(?<netmask>(?:\d+\.\d+\.\d+\.\d+)|\d+)$/)
                else
                    ret = false
                end
            end
            x = NetAddr::CIDRv4.create("#{ipv4[:ip].nil? ? "0.0.0.0" : ipv4[:ip]}/#{ipv4[:netmask].nil? ? "255.255.255.255" : ipv4[:netmask]}")
        rescue NetAddr::ValidationError => e
            # error: netmask incorrect
            ret = false
        rescue => e
            # general error
            ret = false
        end
        ret
    end

   # Function to chefk a valid domain. Based on rfc1123 and sethostname().
   # Suggest rfc1178
   # Max of 253 characters with hostname
   def self.check_domain(domain)
     ret = false
     unless (domain =~ /^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$/).nil?
       ret = true
     end
     ret
   end

   # Function to check hostname. # Based on rfc1123 and sethostname()
   # Max of 63 characters
   def self.check_hostname(name)
     ret = false
     unless (name =~ /^([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$/).nil?
       ret = true
     end
     ret
   end

   #TODO: Function to check encrypt key format
   def Config_utils.check_encryptkey(encrypt_key)
       return true
   end
   


end

## vim:ts=4:sw=4:expandtab:ai:nowrap:formatoptions=croqln: