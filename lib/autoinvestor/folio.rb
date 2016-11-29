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

end