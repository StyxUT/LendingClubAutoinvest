require 'minitest/autorun'
require 'rest-client'
require 'byebug'

require_relative '../lib/autoinvestor/account.rb'
require_relative '../lib/autoinvestor/push_bullet.rb'
require_relative '../lib/autoinvestor/loans.rb'
require_relative '../lib/autoinvestor/configatron.rb'


class LoansTest < Minitest::Test

	def setup
		@orig_debug_status = $debug
		$debug = true
		@push_bullet = PushBullet.new
		account = Account.new(@push_bullet)
		
		@loans = Loans.new(account, @push_bullet)
	end	  

	def teardown
		$debug = @orig_debug_status
	end

	def test_purchase_loans
		skip "Needs tests..."
	end

	def test_check_for_release
		configatron.lending_club.max_checks = 2
		assert_equal(false, @loans.check_for_release)
	end

	def test_get_default_predictions
		skip "@loans.get_default_predictions"
	end

	def test_get_owned_loans_list_is_rest_response
		$verbose = false
		assert_kind_of(Hash, @loans.owned_loans_list)
	end

	def test_owned_loans_list_is_hash
		assert_kind_of(Hash, @loans.owned_loans_list)
	end

	def test_filtered_loan_list_count
		$verbose = false

		@loans.filtered_loan_list
		@loans.get_default_predictions
		@loans.filter_on_default_probability
		assert_equal(108, @loans.filtered_loan_list_count)

		@loans.filter_on_additional_criteria
		assert_equal(62, @loans.filtered_loan_list_count)
	end

	def test_report_post_default_filter_interst_rates
		$verbose = false

		@loans.filtered_loan_list
		@loans.get_default_predictions
		@loans.filter_on_default_probability
		puts "Push Bullet message: #{@push_bullet.message}"
		# assert_equal(108, @loans.filtered_loan_list_count)
	end

	def test_owned_loans_list
		# $debug = true #causes test file to be loaded

		owned_loans_list = @loans.owned_loans_list
		# puts owned_loans_list.values[0][0]
		# puts owned_loans_list

		assert_equal(373332, owned_loans_list.values[0][0]["loanId"])
		assert_equal(97380114, owned_loans_list.values[0][0]["noteId"])
		assert_equal(85131548, owned_loans_list.values[0][0]["orderId"])
		# assert_equal(373332, owned_loans_list.values[0][0]["loanId"])
		
	end

	def test_filtered_loan_list_is_array_after_additional_filters
		@loans.filter_on_additional_criteria
		assert_kind_of(Array, @loans.filtered_loan_list)
	end

end