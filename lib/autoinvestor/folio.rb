class Folio

	def initialize(account, loans, push_bullet)
		@account = account
		@loans = loans
		@pb = push_bullet
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

	def calculate_note_value(yield_to_maturity, days_delinquent)
		#excel formula for charge off probability:  =0.0882253028*POWER(days_delinquent,0.5038668843)
		charge_off_percentage = 0.0882253028 * (days_delinquent**0.5038668843)

		return ((yield_to_maturity - (yield_to_maturity * charge_off_percentage)) * 0.9).round(2)  #discount by 10%
	end

	def build_sell_payload (note_hash)
		sell_hash = {:aid => configatron.lending_club.account, :expireDate => (Date.today+3).to_s, :notes => build_sell_note_list} 
		# '{"aid": ' + configatron.lending_club.account.to_s + ",\n" + '"expireDate":"' + "#{(Date.today+3).to_s}"'
		payload = JSON.generate(sell_hash)
		puts payload
	end

	def build_sell_note_list
		late_notes = filter_on_greater_than_30_days_late

		note_array = []
				
		late_notes.each do |n|
			 note_array += [
			 	:loanId => n["loanId"], 
				:orderId => n["orderId"],
			 	:noteId => n["noteId"]
			 	# :askingPrice => get_asking_price
			 ]
		end 			

		return JSON.generate(note_array)
	end

	def determine_payment_amount(loan_length, interest_rate, note_amount)
		interest_rate_per_period = interest_rate/100.00/12.00
		
		return (note_amount * ((interest_rate_per_period * (1+interest_rate_per_period)**loan_length) / (((1 + interest_rate_per_period)**loan_length) - 1))).round(2)
	end

	def estimate_last_payment_date(payments_received, issue_date, payment_amount)
		# puts payments_received/payment_amount
		# puts issue_date.next_month(payments_received/payment_amount)
		return issue_date.next_day(payments_received/payment_amount*30)
	end
end