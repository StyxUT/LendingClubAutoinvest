require 'minitest/autorun'
require 'rest-client'

require_relative '../lib/autoinvestor/account.rb'
require_relative '../lib/autoinvestor/push_bullet.rb'
require_relative '../lib/autoinvestor/configatron.rb'



class AccountTest < Minitest::Test

	def setup
		push_bullet = PushBullet.new
		@account = Account.new(push_bullet)
	end	  

	def test_available_cash_is_integer
		assert_kind_of(Integer, @account.available_cash)
	end
	
	def test_available_cash_is_not_zero
		refute_equal(0, @account.available_cash)
	end

end