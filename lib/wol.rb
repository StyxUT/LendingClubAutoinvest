#!/usr/bin/ruby

require_relative './autoinvestor/configatron.rb'

cmd = "wakeonlan -i #{configatron.wol.host} #{configatron.wol.mac_address}"

exec (cmd)
