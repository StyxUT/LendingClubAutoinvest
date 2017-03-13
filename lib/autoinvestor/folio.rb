class Folio

	def initialize(account, loans, push_bullet)
		@account = account
		@loans = loans
		@pb = push_bullet
	end

	def sell_delinquent_notes
		post_notes_to_folio

		if configatron.push_bullet.enabled 
			@pb.send_message # send PushBullet message
		end
	end

	def status
		@status
	end

	def success_count
		@success_count
	end

	def cannot_sell_count
		@cannot_sell_count
	end

	def pending_bankruptcy_count
		@pending_bankruptcy_count
	end

	def payment_processing_count
		@payment_processing_count
	end

	def payload_count
		@payload_count
	end

	def post_notes_to_folio
		payload = build_sell_payload
		method_url = "#{configatron.lending_club.base_url}/#{configatron.lending_club.api_version}/accounts/#{configatron.lending_club.account}/trades/sell"

	 	if $verbose
	 		puts "\nPlacing Folio sell order."
	 		puts "method_url: #{__method__} -> #{method_url}"
	 	end
	 	if $debug
	 		puts "\nDebug mode - This folio sell order will NOT be placed."
	 		puts "Pulling sell order response from file: '#{configatron.test_files.folio_sell_order_response}'"
		
		 	response = File.read(File.expand_path("../" + configatron.test_files.folio_sell_order_response, __FILE__))
		else
		 	unless payload.nil?
		 		File.open(File.expand_path(configatron.logging.sell_order_list_log), 'a') { |file| file.write("\n\n#{Time.now.strftime("%H:%M:%S %m/%d/%Y")}\n#{payload}") }
		 	  	begin
				  	response = RestClient.post(method_url, payload,
				  	 	"Authorization" => configatron.lending_club.authorization,
				  	 	"Accept" => configatron.lending_club.content_type,
				  	 	"Content-Type" => configatron.lending_club.content_type
				  	 	)
		 			if $verbose
		 				puts "Folio sell order response:  #{response}"
		 			end
		 		rescue => e
		 			@pb.add_line("Failure in: #{__method__}\nUnable to place folio sell order with method_url:\n#{method_url}")
		 			File.open(File.expand_path(configatron.logging.sell_error_list_log), 'a') { |file| file.write("\n\n#{Time.now.strftime("%H:%M:%S %m/%d/%Y")}\nError while trying to post Folio sale order.\nError Message:  #{e.message}\nError Backtrace:  #{e.backtrace}") }
		 			report_folio_sell_order_response(nil) # order failed; ensure reporting
		 			return
		 		end
		 	end
		 end
		 report_folio_sell_order_response(response)
	end

	def report_folio_sell_order_response(response)
		unless response.nil?
			begin
				File.open(File.expand_path(configatron.logging.sell_order_response_log), 'a') { |file| file.write("\n\n#{Time.now.strftime("%H:%M:%S %m/%d/%Y")}\n#{response}\n\n") }
				response = JSON.parse(response)

				@status = response['sellNoteStatus']
				@success_count = response['sellNoteConfirmations'].count { |k| k['executionStatus'][0] == 'SUCCESS_LISTING_FOR_SALE'}
				@cannot_sell_count = response['sellNoteConfirmations'].count { |k| k['executionStatus'][0] == 'CANNOT_SELL_NOTES'}
				@pending_bankruptcy_count = response['sellNoteConfirmations'].count { |k| k['executionStatus'][0] == 'PENDING_BANKRUPTCY'}
				@payment_processing_count = response['sellNoteConfirmations'].count { |k| k['executionStatus'][0] == 'CANNOT_SELL_NOTE_IN_PAYMENT_PROCESSING'}

				@pb.set_folio_subject("Folio Sell Order - #{status} - #{success_count} of #{payload_count}")
				@pb.add_line "Success Count: #{success_count}"
				@pb.add_line "Cannot Sell Count: #{cannot_sell_count}"
				@pb.add_line "Pending Bankruptcy Count: #{pending_bankruptcy_count}"
				@pb.add_line "Payment Processing Count: #{payment_processing_count}"	
			rescue => e
				@pb.add_line("Failure in: #{__method__}\nUnable to report on folio sell order response.")
				File.open(File.expand_path(configatron.logging.sell_error_list_log), 'a') { |file| file.write("\n\n#{Time.now.strftime("%H:%M:%S %m/%d/%Y")}\nError while trying to report on Folio sale order response.\nError Message:  #{e.message}\nError Backtrace:  #{e.backtrace}") }
			end
		else
			@pb.set_folio_subject('Folio order failed - order response is nil.')
		end
	end

	def filter_on_greater_than_30_days_late
		if $verbose
			puts "Filtering on greater than 30 days late."
			puts "filter_on_greater_than_30_days_late.owned_loan_list.count (before > 30 days late & eligible filter): #{@loans.owned_loans_list.count}"
		end
		unless @loans.owned_loans_list.size == 0
			eligible_late_loans = @loans.owned_loans_list.values[0].select do 
				|k, v| k["loanStatus"] == "Late (31-120 days)" && 
				k["canBeTraded"] == TRUE # limit to loans that can be traded
			end
			if $verbose
				puts "filter_on_greater_than_30_days_late.eligible_late_loans.size (after > 30 days late & eligible filter): #{eligible_late_loans.size}"
			end
		end
		return eligible_late_loans
	end

	def build_sell_payload		
		sell_hash = {:aid => configatron.lending_club.account, :expireDate => (Date.today+configatron.folio.expire_days).strftime("%m/%d/%Y"), :notes => build_sell_note_list(filter_on_greater_than_30_days_late)}
		return sell_hash.to_json
	end

	def build_sell_note_list(late_notes)
		note_array = []
	
		late_notes.each do |n|
			 note_array += [
			 	:loanId => n["loanId"].to_i, 
				:orderId => n["orderId"].to_i,
			 	:noteId => n["noteId"].to_i,
			 	:askingPrice => get_asking_price(n)
			 ]
		end 			
		@payload_count = note_array.count

		if $verbose
			# puts "build_sell_payload.note_array: #{note_array}"
			puts "build_sell_payload.note_array.count: #{note_array.count}"
		end

		return note_array
	end

	def get_asking_price(note)
		rytm = calculate_remaining_yield_to_maturity(note)
		days_delinquent = calculate_days_delinquent(note)

		# Use a minimum of 30 days delinquent because we're currently unable to properly handle cases where partial payments have moved the last payment date forward which in cases causing a borrower to appear current (i.e. have a negative calculated days_delinquent value).
		if days_delinquent < 30
			days_delinquent = 30
		end

		return calculate_note_value(rytm, days_delinquent)
	end

	def calculate_days_delinquent(note)
		if note["lastPaymentDate"] == nil
			# A payment has never been made.  Use one month after issueDate as the start of delinquency.
			date_diff = Date.today - (Date.parse(note["issueDate"]) >> 1)
		else
			#add a month to last payment date to use as the start of the delinqueny'
			date_diff = Date.today - (Date.parse(note["lastPaymentDate"]) >> 1)
		end
		 return date_diff.to_i
	end

	def calculate_note_value(remaining_yield_to_maturity, days_delinquent)
		#excel formula for charge off probability:  =0.0882253028*POWER(days_delinquent,0.5038668843)
		charge_off_percentage = 0.0882253028 * (days_delinquent**0.5038668843)

		return ((remaining_yield_to_maturity - (remaining_yield_to_maturity * charge_off_percentage)) * 0.9).round(2)  #discount by 10%
	end

	def calculate_remaining_yield_to_maturity(note)
		payment_amount = determine_payment_amount(note["loanLength"], note["interestRate"], note["noteAmount"])
		yield_to_maturity = payment_amount * note["loanLength"]
		
		#yield to maturity minus principal received and minus interest received
		remaining_yield_to_maturity = yield_to_maturity - note["principalReceived"] - note["interestReceived"]
		
		return remaining_yield_to_maturity 
	end

	def determine_payment_amount(loan_length, interest_rate, note_amount)
		interest_rate_per_period = interest_rate/100.00/12.00
		
		return (note_amount * ((interest_rate_per_period * (1+interest_rate_per_period)**loan_length) / (((1 + interest_rate_per_period)**loan_length) - 1))).round(2)
	end

end