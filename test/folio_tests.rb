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
		assert_equal(35, late_loans.size)
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
		assert_equal(35, note_list.size)
		# puts note_list[0]
		assert_equal(20288615, note_list[0]["loanId"])
		assert_equal(29091105, note_list[0]["orderId"])
		assert_equal(51684758, note_list[0]["noteId"])
		skip 'assert_equal("xyz", note_list[0]["askingPrice"], "askingPrice is incorrect")'
	end

	def test_determine_asking_price
		# note_list = JSON.parse(@folio.build_sell_note_list)
		skip "Not yet implemented"
		assert_equal(expected_asking_price, actual_asking_price)
	end

	def test_caclulate_remaining_yield_to_maturity
		late_notes = @folio.filter_on_greater_than_30_days_late

		assert_equal(11.23, @folio.calculate_remaining_yield_to_maturity(late_notes.first).round(2))
		assert_equal(62.96, @folio.calculate_remaining_yield_to_maturity(late_notes.last).round(2))
	end

	def test_determine_payment_amount
		skip "No longer needed due to lastPaymentDate in detailed data from owned notes"
		note_list = @folio.filter_on_greater_than_30_days_late
		assert_equal(0.83, @folio.determine_payment_amount(36, 12, 25.00))
		assert_equal(1.01, @folio.determine_payment_amount(note_list[0]["loanLength"], note_list[0]["interestRate"], note_list[0]["noteAmount"]))
	end

	def test_calculate_days_delinquent
		late_notes = @folio.filter_on_greater_than_30_days_late
		new_last_payment_date = DateTime.now - 10.days
		puts "new_last_payment_date: #{new_last_payment_date}"
		late_notes.first["lastPaymentDate"] = '2017-1-20'
		assert_equal(18, @folio.calculate_days_delinquent(late_notes.first))
	end

	def test_get_asking_price
		skip "not yet implemented"	
		late_note = @folio.filter_on_greater_than_30_days_late.first
		puts "get_asking_price: #{@folio.get_asking_price(late_note)}"	
	end

end