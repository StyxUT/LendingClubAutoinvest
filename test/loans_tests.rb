require 'minitest/autorun'
require 'rest-client'

require_relative '../lib/autoinvestor/account.rb'
require_relative '../lib/autoinvestor/push_bullet.rb'
require_relative '../lib/autoinvestor/loans.rb'
require_relative '../lib/autoinvestor/configatron.rb'


class LoansTest < Minitest::Test

	def setup
		push_bullet = PushBullet.new
		account = Account.new(push_bullet)
		
		@loans = Loans.new(account, push_bullet)
	end	  

	def test_get_owned_loans_list_is_rest_response
		assert_kind_of(RestClient::Response, @loans.get_owned_loans_list)
	end

	def test_owned_loans_list_is_hash
		assert_kind_of(Hash, @loans.owned_loans_list)
	end

	def test_filtered_loan_list_is_array_after_additional_filters
		@loans.filter_on_additional_criteria
		assert_kind_of(Array, @loans.filtered_loan_list)
	end

end