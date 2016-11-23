

def filter_on_additional_criteria
		if $verbose
			puts "Filtering on additional criteria."
			puts "filter_on_additional_criteria.filtered_loan_list_count (before additional filter):  #{filtered_loan_list_count}" #filtered_loan_list is still a hash
		end
		unless filtered_loan_list_count == 0
			# many of the below filter criteria have been disabled in favor of relying primarily the default probability determination
			@filtered_loan_list = filtered_loan_list.values[1].select do |o|
				o["term"].to_i == TERMS.months36 && 
				# o["annualInc"].to_f / 12 > 3000 &&
				# o["empLength"].to_i > 23 && #
				# o["inqLast6Mths"].to_i <= 1 &&
				# o["pubRec"].to_i == 0 &&
				o["intRate"].to_f < 27.0 &&
				o["intRate"].to_f > 16.0 
				# o["dti"].to_f <= 20.00 &&
				# o["delinq2Yrs"].to_i < 4 &&
				# ( 	# exclude loans where the monthly installment amount is more than 10% of the borrower's monthly income
				# 	o["installment"].to_f / (o["annualInc"].to_f / 12) < 0.1 
				# ) &&
				# (
				# 	o["purpose"].to_s == PURPOSES.credit_card || 
				# 	o["purpose"].to_s == PURPOSES.credit_card_refinancing ||
				# 	o["purpose"].to_s == PURPOSES.consolidate
				# )
			end
			if $verbose
				puts "filter_on_additional_criteria.filtered_loan_list_count (after additional filter): #{filtered_loan_list_count}"  #filtered_loan_list is now an array
			end
		end
	end