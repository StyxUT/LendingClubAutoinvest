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
	 		puts "Placed folio sell order."
	 		puts "method_url: #{__method__} -> #{method_url}"
	 	end
	 	if $debug
	 		puts "Debug mode - This folio sell order will NOT be placed."
	 		puts "Pulling sell order response from file: '#{configatron.test_files.folio_sell_order_response}'"
		
			response = File.read(File.expand_path("../../" + configatron.test_files.folio_sell_order_response, __FILE__))
		else
			unless payload.nil?
			  	begin
				  	response = RestClient.post(method_url, payload.to_json,
				  	 	"Authorization" => configatron.lending_club.authorization,
				  	 	"Accept" => configatron.folio.content_type,
				  	 	"Content-Type" => configatron.folio.content_type
				  	 	)

					if $verbose
						puts "Folio sell order response:  #{response}"
					end
				rescue
					@pb.add_line("Failure in: #{__method__}\nUnable to place folio sell order with method_url:\n#{method_url}")
					report_sell_order_response(nil) # order failed; ensure reporting
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
				File.open(File.expand_path(configatron.logging.sell_order_response_log), 'a') { |file| file.write("#{Time.now.strftime("%H:%M:%S %d/%m/%Y")}\n#{response}\n\n") }
				
				
				#See this URL for response example: https://www.lendingclub.com/foliofn/APIDocumentationSell.action
				
				if not_in_funding.any?
					@pb.add_line("No longer in funding:  #{not_in_funding.size}") # NOT_AN_IN_FUNDING_LOAN
				end
			rescue
				if $verbose
					puts "Folio sell order response (from Folio):  #{response}"
				end
				@pb.add_line("Failure in: #{__method__}\nUnable to report on folio sell order response.")
			end
		else
			@pb.set_subject "Folio subject update needed."
		end
	end

	def filter_on_greater_than_30_days_late
		if $verbose
			puts "Filtering on greater than 30 days late."
			puts "filter_on_greater_than_30_days_late.owned_loan_list.size (before 30 days late filter): #{@loans.owned_loans_list.size}"
		end
		unless @loans.owned_loans_list.size == 0
			late_loans = @loans.owned_loans_list.values[0].select do 
			|k, v| k["loanStatus"] == "Late (31-120 days)"
			end
			if $verbose
				puts "filter_on_greater_than_30_days_late.late_loans.size (after 30 days late filter): #{late_loans.size}"
			end
		end
		return late_loans
	end

	def build_sell_payload
		sell_hash = {:aid => configatron.lending_club.account, :expireDate => (Date.today+3).to_s, :notes => build_sell_note_list(filter_on_greater_than_30_days_late)} 
		JSON.generate(sell_hash)
	end

	def build_sell_note_list(late_notes)
		note_array = []
				
		late_notes.each do |n|
			 note_array += [
			 	:loanId => n["loanId"], 
				:orderId => n["orderId"],
			 	:noteId => n["noteId"],
			 	:askingPrice => get_asking_price(n)
			 ]
		end 			

		return JSON.generate(note_array)
	end

	def get_asking_price(note)
		rytm = calculate_remaining_yield_to_maturity(note)
		days_delinquent = calculate_days_delinquent(note)
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
		
		#yield to maturity minus principal received and interest received
		remaining_yield_to_maturity = yield_to_maturity - note["principalReceived"] - note["interestReceived"]
		
		return remaining_yield_to_maturity 
	end

	def determine_payment_amount(loan_length, interest_rate, note_amount)
		interest_rate_per_period = interest_rate/100.00/12.00
		
		return (note_amount * ((interest_rate_per_period * (1+interest_rate_per_period)**loan_length) / (((1 + interest_rate_per_period)**loan_length) - 1))).round(2)
	end

end