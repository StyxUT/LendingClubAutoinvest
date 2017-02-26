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
		$verbose = false

		@push_bullet = PushBullet.new
		account = Account.new(@push_bullet)
		loans = Loans.new(account, @push_bullet)
		@folio = Folio.new(account, loans, @push_bullet)
	end	  

	def teardown
		$debug = @orig_debug_status
	end

	def test_post_notes_to_folio
		skip "post_notes_to_folio"
	end

	def test_sell_delinquent_note
		skip "sell_delinquent_notes"
	end

	def test_is_instance_of_folio
		assert_instance_of(Folio, @folio)
	end

	def test_report_folio_sell_order_response_errored
		errored_response = File.read(File.expand_path('../../' + configatron.test_files.errored_folio_sell_order_response, __FILE__))
		@folio.report_folio_sell_order_response(errored_response)
		
		assert_equal(0, @folio.success_count)
		assert_equal(21, @folio.cannot_sell_count)
		assert_equal(3, @folio.pending_bankruptcy_count)
		assert_equal(2, @folio.payment_processing_count)
	end

	def test_report_folio_sell_order_response_success
		success_response = File.read(File.expand_path('../../' + configatron.test_files.folio_sell_order_response, __FILE__))
		@folio.report_folio_sell_order_response(success_response)
		
		assert_equal(27, @folio.success_count)
		assert_equal(0, @folio.cannot_sell_count)
		assert_equal(3, @folio.pending_bankruptcy_count)
		assert_equal(2, @folio.payment_processing_count)
	end

	def test_filter_on_greater_than_30_days_late
		late_loans = @folio.filter_on_greater_than_30_days_late
		
		assert_equal("Late (31-120 days)", late_loans[0]["loanStatus"])
		assert_equal(29, late_loans.size)
	end

	def test_build_sell_payload
		payload = JSON.parse(@folio.build_sell_payload)
		# puts "\nPayload: #{payload}"
		# puts "\nPayload Notes: #{payload['notes']}"

		notes = payload['notes']

		assert_equal(2628791, payload["aid"])
		assert_equal((Date.today + 3).strftime("%m/%d/%Y"), payload["expireDate"])
		assert_equal(3, payload.count)
		assert_equal(29, notes.count)
		assert_equal(20288615, notes.first["loanId"])
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
		late_notes = @folio.filter_on_greater_than_30_days_late
		assert_equal(29, late_notes.size)
		# puts "\nlate_notes: #{late_notes}"
		# puts "\nlate_notes.first: #{late_notes.first}"

		late_notes.first['lastPaymentDate'] = (Date.today - 55).to_s
		assert_equal(20288615, late_notes.first['loanId'])

		note_list = @folio.build_sell_note_list(late_notes)
		# puts "\nnote_list: #{note_list}"

		assert_equal(20288615, note_list.first[:loanId])
		assert_equal(29091105, note_list.first[:orderId])
		assert_equal(51684758, note_list.first[:noteId])	
		assert_equal(5.16, note_list.first[:askingPrice])
	end

	def test_caclulate_remaining_yield_to_maturity
		late_notes = @folio.filter_on_greater_than_30_days_late

		assert_equal(11.23, @folio.calculate_remaining_yield_to_maturity(late_notes.first).round(2))
		assert_equal(62.96, @folio.calculate_remaining_yield_to_maturity(late_notes.last).round(2))
	end

	def test_calculate_days_delinquent
		late_notes = @folio.filter_on_greater_than_30_days_late 
		late_notes.first["lastPaymentDate"] = (Date.today - 55).to_date.to_s
		assert_equal(24, @folio.calculate_days_delinquent(late_notes.first))
	end

	def test_get_asking_price
		late_note = @folio.filter_on_greater_than_30_days_late.first
		late_note["lastPaymentDate"] = (Date.today - 55).to_date.to_s
		assert_equal(5.16, @folio.get_asking_price(late_note))
	end

end