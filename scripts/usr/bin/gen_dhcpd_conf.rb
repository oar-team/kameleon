#!/usr/bin/ruby
# -*- coding: undecided -*-

# Author: Nicolas Niclausse
# Copyright 2010-2011: INRIA

# script specific to grid5000:
# generate dhcpd config files for kavlan

require 'rubygems'
require 'restfully' # gem install restfully --source http://gemcutter.org
require 'ip' # gem install ruby-ip
require 'getoptlong'
require 'optparse'
require 'ostruct'

headers = "ddns-update-style none;
option space pxelinux;
option pxelinux.magic      code 208 = string;
option pxelinux.configfile code 209 = text;
option pxelinux.pathprefix code 210 = text;
option pxelinux.reboottime code 211 = unsigned integer 32;
option vendorinfo          code 43  = string;
"

conf = File.expand_path('~/.restfully/api.grid5000.fr.yaml')
options = if FileTest.exists?(conf) then YAML.load_file(conf) else {} end
options[:base_uri] = 'https://api.grid5000.fr/sid/grid5000'

def parseopts(args)
  options = OpenStruct.new
  options.debug = false
  options.verbose = false
  options.quiet = false
  options.nodes = []
  opts = OptionParser.new do |opts|
    opts.banner = "Usage: gen_dhcpd_conf.rb [options]"
    opts.separator ""
    opts.separator "Specific options:"
    opts.on("-s","--site SITE",  "generate only DHCP conf for site SITE") do |site|
      options.site = site
    end
    opts.on("-i","--vlan-id N", Integer , "generate only DHCP conf for vlan N") do |vlan|
      options.vlan = vlan
    end
    opts.on("-q", "--[no-]quiet", "Run quietly") do |q|
      options.quiet = q
    end
    opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
      options.verbose = v
    end
    opts.on_tail("-h", "--help", "Show this message") do
      puts opts
      exit
    end
  end
  opts.parse!(args)
  options
end

$opts = parseopts(ARGV)

Restfully::Session.new(options) do |root, session|
  options = {:query => {:version => root['version']}}
  root.sites(options).each do |site|
    mysite=site['uid']
    next if not $opts.site.nil? and mysite != $opts.site
    # optionaly, read mac address from external yaml file
    ref = if FileTest.exists?(mysite+".yaml") then
            YAML.load_file(mysite+".yaml")
          else
            puts mysite +": no yaml file for macs" unless $opts.quiet
            {}
          end
    if $opts.vlan.nil? then
      vlans = (1..9).to_a
      # try to guess global vlan assigned to current site
      (10..21).each do |gvlan|
        begin
          IPSocket::getaddress("gw-kavlan-"+gvlan.to_s+"."+mysite+".grid5000.fr")
          puts "global vlan found for site %s: " % mysite unless $opts.quiet
          vlans.push(gvlan)
        rescue
          next
        end
      end
    else
      vlans = [$opts.vlan]
    end
    vlans.each do |vlan|
      filename = "dhcpd-kavlan-"+vlan.to_s+"-"+mysite+".conf"
      open(filename, 'w') do |f|
        puts "generating "+filename unless $opts.quiet
        f.puts headers
        begin
          gateway = IPSocket::getaddress("gw-kavlan-"+vlan.to_s+"."+mysite+".grid5000.fr")
        rescue
          puts "WARN: Get address error: probably no kavlan DNS setup for site " + mysite + " , skip" if $opts.verbose;
          next
        end
        # /20 for local vlans (1..3) and /18 for routed vlan (4..9)
        if vlan < 4
          ip = IP.new(gateway+"/20")
          ns = gateway
          ntp = gateway
          tftp = gateway
        else
          ip = IP.new(gateway+"/18")
          ntp = IPSocket::getaddress("ntp."+mysite+".grid5000.fr")
          ns = IPSocket::getaddress("dns."+mysite+".grid5000.fr")
          tftp = IPSocket::getaddress("kadeploy-server."+mysite+".grid5000.fr")
        end
        netmask = ip.netmask.to_addr
        broadcast = ip.broadcast.to_addr
        network = ip.network.to_addr
        f.puts "subnet %s netmask %s {" %  [network , netmask]
        f.puts "    default-lease-time 86400;
    max-lease-time 604800;"
        f.puts "    option domain-name \"%s.grid5000.fr\"; " % mysite
        f.puts "    option domain-name-servers %s;" % ns
        f.puts "    option ntp-servers %s; " % ntp
        f.puts "    option routers %s;" % gateway
        f.puts "    option subnet-mask %s; " % netmask
        f.puts "    option broadcast-address %s;" % broadcast
        f.puts "    filename  \"pxelinux.0\";"
        f.puts "    next-server %s;" % tftp

        sites_for_vlan = if vlan < 10
                           [ site ]
                         else
                           root.sites(options)
                         end
        sites_for_vlan.each do |currentsite|
          currentsite.clusters(options).each do |cluster|
            cluster.nodes(options).each do |node|
              sitename=currentsite['uid']
              device = node['network_adapters'].find{|s| s['network_address'] =~ /^\w+-\d+\.\w+\.grid5000\.fr/}
              next if device.nil?
              hostname = device['network_address']
              next if hostname.nil?
              hostname_vlan = hostname.gsub(/^(\w+-\d+)(\..*)$/){$1+"-kavlan-"+vlan.to_s+$2}
              shortname_vlan = hostname_vlan.gsub(/^(\w+-\d+-\w+-\d+)(\..*)$/){$1}
              shortname = hostname.gsub(/^(\w+-\d+)(\..*)$/){$1}
              begin
                vlan_ip = IPSocket::getaddress(hostname_vlan)
              rescue
                puts "WARN: Get address error: probably no DNS setup for vlan " +vlan.to_s+" on  site " + sitename + " , skip" if $opts.verbose;
                next
              end
              if device['mac'].nil? then
                if ref[shortname].nil? then
                  puts "WARN: mac undefined for host %s, skip" % hostname unless $opts.quiet
                  next
                else
                  mac = ref[shortname]['mac_eth0']
                end
              else
                mac = device['mac']
              end
              currenttftp = IPSocket::getaddress("kadeploy-server."+sitename+".grid5000.fr")
              f.puts "   host %s {" % hostname_vlan
              f.puts "     hardware ethernet %s; " % mac
              f.puts "     option host-name \"%s\";" %  shortname_vlan
              f.puts "     fixed-address %s;" % vlan_ip
              f.puts "     next-server %s;" % currenttftp
              f.puts "   }"
            end
          end
        end
        f.puts "}"
      end
    end
  end
end


