require 'yinum'

class Loans
	TERMS = Enum.new(:TERMS, :months60 => 60, :months36 => 36)
	PURPOSES = Enum.new(:PURPOSES, :credit_card_refinancing => 'credit_card_refinance', :consolidate => 'debt_consolidation', :other => 'other', :credit_card => 'credit_card', :home_improvement => 'home_improvement', :small_business => 'small_business')

	def initialize(account, push_bullet)
		@account = account
		@pb = push_bullet
	end

	def purchase_loans
		# preload relatively static data in order to reduce processing time once loans have been released
		@account.available_cash
		owned_loans_list


		# if check_for_release
			if default_predictions.nil?
				terminate_early
			else
			 	apply_filtering_criteria
			 	place_order(build_order_list)
			end
		# end

		if configatron.push_bullet.enabled 
			@pb.send_message # send PushBullet message
		end
	end

	def apply_filtering_criteria
		filtered_loan_list #prepopulate from loan_list before applying filters
		filter_on_default_probability
		filter_on_additional_criteria
		filter_on_owned_loans
	end

	#force refresh of @loan_list with each call
	def fresh_loan_list
		@loan_list = JSON.parse(get_available_loans)
		if $verbose
			puts "fresh_loan_list.@loan_list.values[1].size: #{@loan_list.values[1].size}"
		end
		@loan_list # make @loan_list the return value
	end

	def loan_list
		@loan_list ||= fresh_loan_list
		if $verbose
			puts "loan_list.@loan_list.values[1].size: #{@loan_list.values[1].size}"
		end
		@loan_list # make @loan_list the return value
	end

	def filtered_loan_list
		@filtered_loan_list ||= loan_list
		if $verbose
			puts "@filtered_loan_list: #{@filtered_loan_list}"
		end
		@filtered_loan_list # make @filtered_loan_list the return value
	end

	def filtered_loan_list_count
		begin
			return filtered_loan_list.values[1].size
		rescue
			return 0
		end
	end
	
	def owned_loans_list
		@owned_loans_list ||= JSON.parse(get_owned_loans_list)
		if $verbose
			#puts "@owned_loans_list: #{@owned_loans_list}"
		end
		@owned_loans_list # make @owned_loans_list the return value
	end

	def default_predictions
		@default_predictions ||= get_default_predictions
		if $verbose
			# puts "@default_predictions: #{@default_predictions}"
		end
		@default_predictions # make @default_predictions the return value
	end

	def fundable_loan_count
		@fundable_loan_count ||= @account.available_cash / configatron.lending_club.investment_amount
		if $verbose
			puts "@fundable_loan_count: #{@fundable_loan_count}"
		end
		@fundable_loan_count # make fundable_loan_count the return value
	end

	def purchasable_loan_count
		@purchasable_loan_count ||= [fundable_loan_count, filtered_loan_list_count].min
		if $verbose
			puts "@purchasable_loan_count: #{@purchasable_loan_count}"
		end
		@purchasable_loan_count # make @purchasable_loan_count the return value
	end

	# LendingClub server time and local server time may not always be synced or loans may be release a bit early or late.  
	# Check for the release of new loans "max_checks" times and attempt to purchase loans when/if loans are released.
	def check_for_release
	 	check_count = 0
	 	max_checks = configatron.lending_club.max_checks
	 	starting_loan_list_size = fresh_loan_list.values[1].size
	 	puts "starting_loan_list_size: #{starting_loan_list_size}"
	 	while check_count < max_checks
	 		check_count = check_count + 1
	 		puts "check_for_release #{check_count}"
	 		current_loan_list_size = fresh_loan_list.values[1].size
	 		puts "current_loan_list_size: #{current_loan_list_size}"
	 		if current_loan_list_size > starting_loan_list_size 
	 			puts "Loans have been released. Preparing to purchasing loans."
	 			@pb.add_line("Pre-Filtered Loan Count:  #{current_loan_list_size}")
	 			return true
	 		end
	 		puts "Pre-Filtered Loan Count:  #{current_loan_list_size}"
	 		sleep(1) # wait X seconds before checking again
	 	end
	 	@pb.add_line("After #{check_count} checks the number of available loans remained at or below #{starting_loan_list_size}.")
	 	return false
	 end

	def get_available_loans
		method_url = "#{configatron.lending_club.base_url}/#{configatron.lending_club.api_version}/loans/listing" #only show loans released in the most recent release (add "?showAll=true" to see all loans)
		if $debug
			puts "Pulling available loans (from test file): '#{configatron.test_files.available_loans}'"
			response = File.read(File.expand_path("../../../" + configatron.test_files.available_loans, __FILE__))
			puts "Pre-Filtered Loan size (from test file):  #{JSON.parse(response).values[1].size}"
		else
			begin
				puts "get_available_loans.Pulling fresh Loans data."
			 	puts "method_url: #{__method__} -> #{method_url}"
				response = RestClient.get( method_url, 
				 		"Authorization" => configatron.lending_club.authorization,
				 		"Accept" => configatron.lending_club.content_type,
				 		"Content-Type" => configatron.lending_club.content_type
					)
				puts "Pre-Filtered Loan count:  #{JSON.parse(response).values[1].size}"
			rescue
				@pb.add_line("Failure in: #{__method__}\nUnable to get a list of available loans.")
			end
		end
		return response
	end	 

	def filter_on_default_probability
		if $verbose
			puts "Filter on default probability."
			puts "filter_on_default_probability.	 (before default filter): #{filtered_loan_list_count}"
		end
		unless default_predictions.nil?
			default_probabilities = JSON.parse(default_predictions)
			probabilities = JSON.parse(default_probabilities.values[0])

			#add members to delete_list array where default probability is more than X.XX.  These will be filtered out.
			delete_list = []
			probabilities.select {|o| 
			 	o["defaultProb"].to_f > configatron.default_predictor.max_default_prob # if greater, add to delete list
			 }.each {|k,v| delete_list << k["memberId"]}
			
			delete_list.each {|i| @filtered_loan_list.values[1].delete_if {|k,v| k["memberId"] == i.to_i}}
			puts "filter_on_default_probability.filtered_loan_list_count (after default filter): #{filtered_loan_list_count}"
		end
	end

	def get_default_predictions
		method_url = "#{configatron.default_predictor.base_url}:#{configatron.default_predictor.port}/predict"
		if $verbose
			puts "Getting default predictions."
			puts "method_url: #{__method__} -> #{method_url}"
		end
		if $debug
			begin
				puts "Pulling test loans for default predictor (from test file): '#{configatron.default_predictor.test_file}'"
				response = RestClient.post( method_url, File.read(File.expand_path("../../../" + configatron.default_predictor.test_file, __FILE__)), 
			  	 		"Accept" => configatron.default_predictor.content_type,
			  	 		"Content-Type" => configatron.default_predictor.content_type
			  		)
			rescue
				error_message = "Failure in: #{__method__}\nUnable to obtain default predictions.  The default predictor service may not be running at #{configatron.default_predictor.base_url}:#{configatron.default_predictor.port}"
				@pb.add_line(error_message)
				write_to_log(configatron.logging.error_list_log, error_message)
				return nil
			end
		else
			begin
				response = RestClient.post( method_url, loan_list.to_json, # default predictor service expects the loan list as JSON data 
				  		"Accept" => configatron.default_predictor.content_type,
				  		"Content-Type" => configatron.default_predictor.content_type
				 	)
				
				puts "get_default_predictions.response: #{response}"
			rescue
				error_message = "Failure in: #{__method__}\nUnable to obtain default predictions.  The default predictor service may not be running at #{configatron.default_predictor.base_url}:#{configatron.default_predictor.port}"
				@pb.add_line(error_message)
				write_to_log(configatron.logging.error_list_log, error_message)
				return nil
			end
		end
		#make a valid JSON document so the response can be parsed to a HASH
		json_doc = '{"predictions":' + response + '}'
	end

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

	def filter_on_owned_loans
		if $verbose
			puts "Filter on owned loans."
			puts "filter_on_owned_loans.filtered_loan_list_count (before owned loan removal): #{filtered_loan_list_count}"
		end
		unless filtered_loan_list_count == 0
			# extract loanId's from a hash of already owned loans and remove those loans from the list of filtered loans
			owned_loans_list.values[0].map {|o| o["loanId"]}.each { |i| @filtered_loan_list.delete_if {|key, value| key["id"] == i} }
		end
		if $verbose
			puts "filter_on_owned_loans.filtered_loan_list_count (after owned loan removal) #{filtered_loan_list_count}"
		end
	end
	
	def get_owned_loans_list
		method_url = "#{configatron.lending_club.base_url}/#{configatron.lending_club.api_version}/accounts/#{configatron.lending_club.account}/detailednotes"
		if $verbose
			puts "Pulling list of already owned loans."
			puts "method_url: #{__method__} -> #{method_url}"
		end
		# if $debug
		# 	response = File.read(File.expand_path("../../../" + configatron.test_files.owned_loans_detail, __FILE__))
		# else
			begin 
				response = RestClient.get(method_url,
				 		"Authorization" => configatron.lending_club.authorization,
				 		"Accept" => configatron.lending_club.content_type,
				 		"Content-Type" => configatron.lending_club.content_type
					)	
			rescue
				@pb.add_line("Failure in: #{__method__}\nUnable to get the list of already owned loans.")
			end
		# end	
		File.open(File.expand_path("./" + configatron.test_files.owned_loans_detail), 'w') { |file| file.write(response)}
		return response
	end
	
	def build_order_list
		@pb.add_line("Placing an order for #{purchasable_loan_count} loans.")

		if purchasable_loan_count > 0 && filtered_loan_list_count > 0
			# sort the loans with the highest interest rate to the front  
			# 	--this is so highest interest rate loans will be purchased first when there isn't enough available money to purchase all desirable loans
			@filtered_loan_list.sort! { |a,b| b["intRate"].to_f <=> a["intRate"].to_f }

			order_list = Hash["aid" => configatron.lending_club.account, "orders" => 
				filtered_loan_list.first(purchasable_loan_count).map do |o|
					Hash[
							'loanId' => o["id"].to_i,
						 	'requestedAmount' => configatron.lending_club.investment_amount, 
						 	'portfolioId' => configatron.lending_club.portfolio_id
						]
				end
			]
			if $verbose
				puts order_list
			end
		end
		begin
			#log order
			write_to_log(configatron.logging.order_list_log, order_list)
		ensure
			return order_list
		end
	end

	def place_order(order_list)
	 	method_url = "#{configatron.lending_club.base_url}/#{configatron.lending_club.api_version}/accounts/#{configatron.lending_club.account}/orders"
	 	if $verbose
	 		puts "Placing purchase order."
	 		puts "method_url: #{__method__} -> #{method_url}"
	 	end
	 	if $debug
	 		puts "Debug mode - This order will NOT be placed."
	 		puts "Pulling order response from file: '#{configatron.test_files.purchase_response}'"
		
			response = File.read(File.expand_path("../../" + configatron.test_files.purchase_response, __FILE__))
		else
			unless order_list.nil?
			  	begin

#              	!!!!!!!!!!!!!!!!!!
# 				
#				This section is disabled to prevent acutally purchasing loans while developing
#    			
#  				!!!!!!!!!!!!!!!!

				  	# response = RestClient.post(method_url, order_list.to_json,
				  	#  	"Authorization" => configatron.lending_club.authorization,
				  	#  	"Accept" => configatron.lending_club.content_type,
				  	#  	"Content-Type" => configatron.lending_club.content_type
				  	#  	)

					if $verbose
						puts "Order Response:  #{response}"
					end
				rescue
					@pb.add_line("Failure in: #{__method__}\nUnable to place order with method_url:\n#{method_url}")
					report_order_response(nil) # order failed; ensure reporting
					return
				end
			end
		end
		report_order_response(response)
	end

	def report_order_response(response)
		unless response.nil?
				response = JSON.parse(response)
			begin
				File.open(File.expand_path(configatron.logging.order_response_log), 'a') { |file| file.write("#{Time.now.strftime("%H:%M:%S %d/%m/%Y")}\n#{response}\n\n") }
				invested = response.values[1].select { |o| o["executionStatus"].include? 'ORDER_FULFILLED' }
				not_in_funding = response.values[1].select { |o| o["executionStatus"].include? 'NOT_AN_IN_FUNDING_LOAN' }
				@pb.set_subject("#{invested.size.to_i} of #{purchasable_loan_count}/#{[fundable_loan_count.to_i, filtered_loan_list_count].max}")
				@pb.add_line("Successfully Invested:  #{invested.inject(0) { |sum, o| sum + o["investedAmount"].to_f }}") # dollar amount invested
				if not_in_funding.any?
					@pb.add_line("No longer in funding:  #{not_in_funding.size}") # NOT_AN_IN_FUNDING_LOAN
				end
			rescue
				if $verbose
					puts "Order Response (from LendingClub):  #{response}"
				end
				@pb.add_line("Failure in: #{__method__}\nUnable to report on order response.")
			end
		else
			@pb.set_subject "0 of #{purchasable_loan_count}/#{[fundable_loan_count.to_i, filtered_loan_list_count].max}"
		end
	end

	# if unable to get default predictions report then terminate early to prevent purchasing undesirable loans
	def terminate_early
		@pb.set_subject "[!Early Termination!] 0"
		@pb.add_line "Failed to obtain default predictions."
	end

	def write_to_log(log_file, log_message)
		File.open(File.expand_path(log_file), 'a') { |file| file.write("#{Time.now.strftime("%H:%M:%S %d/%m/%Y")}\n#{log_message}\n\n")}
	end

end