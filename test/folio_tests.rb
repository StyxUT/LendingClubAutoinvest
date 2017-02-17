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


	def test_build_sell_note_list
		note_list = JSON.parse(@folio.build_sell_note_list)
		assert_equal(35, note_list.size)
		# puts note_list[0]
		assert_equal(20288615, note_list.first["loanId"])
		assert_equal(29091105, note_list.first["orderId"])
		assert_equal(51684758, note_list.first["noteId"])
		assert_equal("xyz", note_list[0]["askingPrice"], "askingPrice is incorrect")
	end

	def test_caclulate_remaining_yield_to_maturity
		late_notes = @folio.filter_on_greater_than_30_days_late

		assert_equal(11.23, @folio.calculate_remaining_yield_to_maturity(late_notes.first).round(2))
		assert_equal(62.96, @folio.calculate_remaining_yield_to_maturity(late_notes.last).round(2))
	end

	def test_calculate_days_delinquent
		late_notes = @folio.filter_on_greater_than_30_days_late
		late_notes.first["lastPaymentDate"] = (DateTime.now - 55).to_date.to_s
		assert_equal(24, @folio.calculate_days_delinquent(late_notes.first))
	end

	def test_get_asking_price
		late_note = @folio.filter_on_greater_than_30_days_late.first
		late_note["lastPaymentDate"] = (DateTime.now - 55).to_date.to_s
		assert_equal(5.68, @folio.get_asking_price(late_note))
	end

end