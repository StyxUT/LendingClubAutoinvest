require 'minitest/autorun'

require_relative '../lib/autoinvestor/account.rb'
require_relative '../lib/autoinvestor/push_bullet.rb'
require_relative '../lib/autoinvestor/loans.rb'
require_relative '../lib/autoinvestor/folio.rb'
require_relative '../lib/autoinvestor/configatron.rb'


class FolioTest < Minitest::Test

	
	def setup
		@orig_debug_status = $debug
		$debug = true #causes test files to be used

		push_bullet = PushBullet.new
		account = Account.new(push_bullet)
		loans = Loans.new(account, push_bullet)
		@folio = Folio.new(account, loans, push_bullet)
	end	  

	def teardown
		$debug = @orig_debug_status
	end

	def test_is_instance_of_folio
		assert_instance_of(Folio, @folio)
	end

	def test_filter_on_greater_than_30_days_late
		late_loans = @folio.filter_on_greater_than_30_days_late
		
		assert_equal("Late (31-120 days)", late_loans[0]["loanStatus"])
		assert_equal(4, late_loans.size)
	end

	def test_calculate_note_value
		yield_to_maturity = 20.05

		days_delinquent_30 = 30
		days_delinquent_90 = 90
		days_delinquent_120 = 120

		note_value_30 = @folio.calculate_note_value(yield_to_maturity, days_delinquent_30)
		note_value_90 = @folio.calculate_note_value(yield_to_maturity, days_delinquent_90)
		note_value_120 = @folio.calculate_note_value(yield_to_maturity, days_delinquent_120)

		assert_equal(9.21, note_value_30)
		assert_equal(2.68, note_value_90)
		assert_equal(0.28, note_value_120)
	end

	# def test_build_sell_payload
	# 	@folio.build_sell_payload
	# end

	def test_build_sell_note_list
		note_list = JSON.parse(@folio.build_sell_note_list)
		assert_equal(4, note_list.size)
		# puts note_list[0]
		assert_equal(373332, note_list[0]["loanId"])
		assert_equal(85131548, note_list[0]["orderId"])
		assert_equal(97380114, note_list[0]["noteId"])
		skip 'assert_equal("xyz", note_list[0]["askingPrice"], "askingPrice is incorrect")'
	end

	def test_determine_payment_amount
		note_list = @folio.filter_on_greater_than_30_days_late
		assert_equal(0.83, @folio.determine_payment_amount(36, 12, 25.00))
		assert_equal(0.91, @folio.determine_payment_amount(note_list[0]["loanLength"], note_list[0]["interestRate"], note_list[0]["noteAmount"]))
	end

	def test_estimate_last_payment_date
		assert_equal(Date.parse("2016-11-22"), @folio.estimate_last_payment_date(10.68, Date.parse("2015-11-28"), 0.89))

		note_list = @folio.filter_on_greater_than_30_days_late
		# puts note_list
		# puts "loanLength: #{note_list[0]["loanLength"]}"
		# puts "noteAmount: #{note_list[0]["noteAmount"]}"
		# puts "interestRate: #{note_list[0]["interestRate"]}"
		payment_amount = @folio.determine_payment_amount(note_list[2]["loanLength"], note_list[2]["interestRate"], note_list[2]["noteAmount"])
		
		# puts "paymentsReceived: #{note_list[0]["paymentsReceived"]}"
		# puts "issueDate: #{note_list[2]["issueDate"]}"
		# puts "payment_amount: #{payment_amount}"

		#number of seconds is off, consider asserting value of date_diff is 0 days.
		skip 'Broken Test: assert_equal(Date.parse("2015-06-12"), Date.parse(@folio.estimate_last_payment_date(note_list[2]["paymentsReceived"], Date.parse(note_list[2]["issueDate"]), payment_amount)))'
	end

end