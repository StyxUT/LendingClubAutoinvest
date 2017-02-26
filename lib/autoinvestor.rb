#!/usr/bin/ruby

require_relative 'autoinvestor/push_bullet.rb'
require_relative 'autoinvestor/account.rb'
require_relative 'autoinvestor/loans.rb'
require_relative 'autoinvestor/folio.rb'
require_relative 'autoinvestor/configatron.rb'

require 'rubygems'
require 'bundler/setup'
require 'rest-client'
require 'json'


#require 'byebug'

$debug = false 
$verbose = true


1.times{
	push_bullet = PushBullet.new
	account = Account.new(push_bullet)
	loans = Loans.new(account, push_bullet)
  	loans.purchase_loans
}

# 1.times{
# 	push_bullet = PushBullet.new
# 	account = Account.new(push_bullet)
# 	loans = Loans.new(account, push_bullet)
# 	folio = Folio.new(account, loans, push_bullet)
# 	folio.sell_delinquent_notes
# }
