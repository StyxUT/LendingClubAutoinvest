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
				response = JSON.parse(response)
			begin
				File.open(File.expand_path(configatron.logging.sell_order_response_log), 'a') { |file| file.write("\n\n#{Time.now.strftime("%H:%M:%S %m/%d/%Y")}\n#{response}\n\n") }
				
				# invested = response.values[1].select { |o| o["executionStatus"].include? 'ORDER_FULFILLED' }
				# not_in_funding = response.values[1].select { |o| o["executionStatus"].include? 'NOT_AN_IN_FUNDING_LOAN' }

				# @pb.set_subject("#{invested.size.to_i} of #{purchasable_loan_count}/#{[fundable_loan_count.to_i, filtered_loan_list_count].max}")
				# @pb.add_line("Successfully Invested:  #{invested.inject(0) { |sum, o| sum + o["investedAmount"].to_f }}") # dollar amount invested
				# if not_in_funding.any?
				# 	@pb.add_line("No longer in funding:  #{not_in_funding.size}") # NOT_AN_IN_FUNDING_LOAN
				# end

				#See this URL for response example: https://www.lendingclub.com/foliofn/APIDocumentationSell.action

				    # {
				    #     sellNoteStatus: "SUCCESS"
				    #     sellNoteConfirmations: [2]
				        
				    #     0: {
				    #         loanId: 1238176
				    #         noteId: 10177006
				    #         askingPrice: 4.66
				    #         executionStatus: [1]
				    #         0: "SUCCESS_LISTING_FOR_SALE"
				    #     }
				        
				    #     1: {
				    #         loanId: 1178925
				    #         noteId: 9351290
				    #         askingPrice: 3
				    #         executionStatus: [1]
				    #         0: "SUCCESS_LISTING_FOR_SALE"
				    #     }
				    # }

				# if not_in_funding.any?
				# 	@pb.add_line("No longer in funding:  #{not_in_funding.size}") # NOT_AN_IN_FUNDING_LOAN
				# end
			rescue => e
				@pb.add_line("Failure in: #{__method__}\nUnable to report on folio sell order response.")
				File.open(File.expand_path(configatron.logging.sell_error_list_log), 'a') { |file| file.write("\n\n#{Time.now.strftime("%H:%M:%S %m/%d/%Y")}\nError while trying to report on Folio sale order response.\nError Message:  #{e.message}\nError Backtrace:  #{e.backtrace}") }
			end
		else
			@pb.set_subject "Folio order failed, response is nil.  Folio subject update needed."
		end
	end

	def filter_on_greater_than_30_days_late
		if $verbose
			puts "Filtering on greater than 30 days late."
			puts "filter_on_greater_than_30_days_late.owned_loan_list.count (before 30 days late filter): #{@loans.owned_loans_list.count}"
		end
		unless @loans.owned_loans_list.size == 0
			late_loans = @loans.owned_loans_list.values[0].select do 
				|k, v| k["loanStatus"] == "Late (31-120 days)" && 
				k["canBeTraded"] == TRUE # limit to loans that can be traded
			end
			if $verbose
				puts "filter_on_greater_than_30_days_late.late_loans.size (after 30 days late filter): #{late_loans.size}"
			end
		end
		return late_loans
	end

	def build_sell_payload		
		sell_hash = {:aid => configatron.lending_club.account, :expireDate => (Date.today+3).strftime("%m/%d/%Y"), :notes => build_sell_note_list(filter_on_greater_than_30_days_late)}
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

		if $verbose
			puts "build_sell_payload.note_array: #{note_array}"
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
		#add a month to last payment date to use as the start of the delinqueny
		date_diff = Date.today - (Date.parse(note["lastPaymentDate"]) >> 1)
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