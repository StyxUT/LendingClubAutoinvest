#!/usr/bin/ruby
# wol.rb: sends out a magic packet to wake up your PC
#
# Copyright (c) 2004 zunda <zunda at freeshell.org>
# 
# This program is free software. You can re-distribute and/or
# modify this program under the same terms of ruby itself ---
# Ruby Distribution License or GNU General Public License.
#
require_relative 'autoinvestor/configatron.rb'

# target machine
mac = configatron.wol.mac.to_s	# hex numbers

# target network
host = configatron.wol.host.to_s
local = true
#	host = 'example.com'
#	local = false

require 'socket'
port = 9	# Discard Protocol
message = "\xFF".force_encoding(Encoding::ASCII_8BIT)*6 + [ mac.gsub( /:/, '' ) ].pack( 'H12' )*16
txbytes = UDPSocket.open do |so|
	if local then
		so.setsockopt( Socket::SOL_SOCKET, Socket::SO_BROADCAST, true )
	end
	so.send( message, 0, host, port )
end
if $verbose
	puts "#{txbytes} bytes sent to #{host}:#{port}."
end