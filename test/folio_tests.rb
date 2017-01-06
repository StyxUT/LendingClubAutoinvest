require 'minitest/autorun'

require_relative '../lib/autoinvestor/account.rb'
require_relative '../lib/autoinvestor/push_bullet.rb'
require_relative '../lib/autoinvestor/loans.rb'
require_relative '../lib/autoinvestor/folio.rb'
require_relative '../lib/autoinvestor/configatron.rb'


class FolioTest < Minitest::Test

	def setup
		push_bullet = PushBullet.new
		account = Account.new(push_bullet)
		loans = Loans.new(account, push_bullet)
		@folio = Folio.new(account, loans, push_bullet)
	end	  

	def test_is_instance_of_folio
		assert_instance_of(Folio, @folio)
	end

	def test_filter_on_greater_than_30_days_late
		$debug = true #causes test file to be loaded

		late_loans = @folio.filter_on_greater_than_30_days_late
		
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

	def test_build_note_hash
		@folio.build_note_hash
	end
end