#!/usr/bin/ruby
require_relative 'configatron.rb'
require 'rubygems'
require 'bundler/setup'
require 'yinum'
require 'rest-client'
require 'json'
require 'pp'
require 'washbullet' #PushBullet

#require 'byebug'


#  TODO:
#  Add Setup Instructions
#  		Add instructons for using clock.rb with /etc/init.d/clockworker.sh
#  		Add instruction for using clockworkd and clockwork
# 		(recomend using foreman/upstart)
#  Implement Unit Tests
#  Improve order response messaging
# 		Currently only supports successful purchases, and no longer in funding
#  Add support to allow investing different amounts depending on account factors
#  		E.g. If available funds is larger than $300 and number of owned notes is > 500 invest $50 per note instead of $25


###############################
#  Install Instructions:
#   Update values in example_configatron.rb then rename file to configatron.rb
#  	Rotate logs using logrotate
#		brew install logrotate (OS X only)
#		mkdir /var/log/lending_club_autoinvestor/
# 			ensure executing process has write access to directory
#				sudo chown -R <user_name> /var/log/lending_club_autoinvestor/
#		add below to "/etc/logrotate.d/lending_club_autoinvestor" file:
#			/var/log/lending_club_autoinvestor/*.log {
#		        weekly
#		        missingok
#		        rotate 7
#		        compress
#		        notifempty
#				nocreate
#			}
#		modify configuration as needed (man logrotate)
###############################


###############################
#  	Notes:
# 	It's intended for this script to be scheduled to run about one minute prior to the time LendingClub releases new loans. 
# 	Currently LendingClub releases new loans at 7 AM, 11 AM, 3 PM and 7 PM (MST) each day.
#   This is ideally handled by the clock.rb/clockworkd/colckworker.sh setup 
###############################


###############################
#   Start & Stop
#   to start: $ bundle exec clockworkd start --log -c ~/projects/LendingClubAutoinvest/clock.rb
#   to stop: $ bundle exec clockworkd stop --log -c ~/projects/LendingClubAutoinvest/clock.rb
###############################

$debug = false 
$verbose = true
$pushbullet = true

class Loans
	TERMS = Enum.new(:TERMS, :months60 => 60, :months36 => 36)
	PURPOSES = Enum.new(:PURPOSES, :credit_card_refinancing => 'credit_card_refinance', :consolidate => 'debt_consolidation', :other => 'other', :credit_card => 'credit_card', :home_improvement => 'home_improvement', :small_business => 'small_business')

	def purchase_loans
		# preload relatively static data in order to reduce processing time once loans have been released
		A.available_cash
		owned_loans_list

		if check_for_release
		 	apply_filtering_criteria
		 	place_order(build_order_list)
		end

		PB.send_message # send PushBullet message
	end

	def apply_filtering_criteria
		filtered_loan_list #needed in order to populate @filtered_loan_list
		filter_on_default_probability
		filter_on_additional_criteria
		filter_on_owned_loans
	end

	#forces refresh of @loan_list with each call
	def fresh_loan_list
		@loan_list = JSON.parse(get_available_loans)
		if $verbose
			puts "@loan_list.values[1].size: #{@loan_list.values[1].size}"
		end
		@loan_list # make @loan_list the return value
	end

	def loan_list
		@loan_list ||= fresh_loan_list
		if $verbose
			puts "@loan_list.values[1].size: #{@loan_list.values[1].size}"
		end
		@loan_list # make @loan_list the return value
	end

	def filtered_loan_list
		@filtered_loan_list ||= loan_list
		if $verbose
			#puts "@filtered_loan_list: #{@filtered_loan_list}"
		end
		@filtered_loan_list # make @filtered_loan_list the return value
	end

	def owned_loans_list
		@owned_loans_list ||= JSON.parse(get_owned_loans_list)
		if $verbose
			#puts "@owned_loans_list: #{@owned_loans_list}"
		end
		@owned_loans_list # make @owned_loans_list the return value
	end

	def fundable_loan_count
		@fundable_loan_count ||= A.available_cash / configatron.lending_club.investment_amount
		if $verbose
			puts "@fundable_loan_count: #{@fundable_loan_count}"
		end
		@fundable_loan_count
	end

	def purchasable_loan_count
		@purchasable_loan_count ||= [fundable_loan_count, owned_loans_list.size].min
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
	 			PB.add_line("Pre-Filtered Loan Count:  #{current_loan_list_size}")
	 			return true
	 		end
	 		puts "Pre-Filtered Loan Count:  #{current_loan_list_size}"
	 		sleep(1) # wait X seconds before checking again
	 	end
	 	PB.add_line("After #{check_count} checks the number of available loans remained at or below #{starting_loan_list_size}.")
	 	return false
	 end

	def get_available_loans
		method_url = "#{configatron.lending_club.base_url}/#{configatron.lending_club.api_version}/loans/listing" #only show loans released in the most recent release (add "?showAll=true" to see all loans)
		if $debug
			puts "Pulling available loans (from test file): '#{configatron.testing_files.available_loans}'"
			response = File.read(File.expand_path("../" + configatron.testing_files.available_loans, __FILE__))
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
				PB.add_line("Failure in: #{__method__}\nUnable to get a list of available loans.")
			end
		end
		return response
	end	 

	def filter_on_default_probability
		if $verbose
			puts "Filter on default probability." 
		end
		begin
			default_probabilities = JSON.parse(get_default_predictions)
			probabilities = JSON.parse(default_probabilities.values[0])
			puts "probabilities class: #{probabilities.class}"
			delete_list = []

			#add members to delete_list array where default probability is X.XX or more.  These will be filterd out.
			probabilities.select {|o| 
			 	o["defaultProb"] >= configatron.default_predictor.max_default_prob 
			 }.each {|k,v| delete_list << k["memberId"]}
			
			delete_list.each {|i| @filtered_loan_list.values[1].delete_if {|k,v| k["memberId"] == i.to_i}}
			puts "post filter_on_default_probability.filtered_loan_list.size #{filtered_loan_list.values[1].size}"
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
				response = RestClient.post( method_url, File.read(File.expand_path("../" + configatron.default_predictor.test_file, __FILE__)), 
			  	 		"Accept" => configatron.default_predictor.content_type,
			  	 		"Content-Type" => configatron.default_predictor.content_type
			  		)
			rescue
				PB.add_line("Failure in: #{__method__}\nUnable to get a default predictions.  The default predictor service at #{configatron.default_predictor.base_url} may not be running.")
			end
		else
			begin
				response = RestClient.post( method_url, get_available_loans, 
				  		"Accept" => configatron.default_predictor.content_type,
				  		"Content-Type" => configatron.default_predictor.content_type
				 	)
			rescue
				PB.add_line("Failure in: #{__method__}\nUnable to get a default predictions.  The default predictor service at #{configatron.default_predictor.base_url} may not be running.")
			end
		end
		#make a valid JSON document so the response can be parsed to a HASH
		json_doc = '{"predictions":' + response + '}'
	end

	def filter_on_additional_criteria
		if $verbose
			puts "Filtering on additional criteria."
			puts "filter_on_additional_criteria.Pre-Filtered Loan Count (before additional filter):  #{filtered_loan_list.values[1].size}" #filtered_loan_list is still a hash
		end
		unless loan_list.nil?
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
				# ( 	# exclude loans where the monthly instalment amount is more than 10% of the borrower's monthly income
				# 	o["installment"].to_f / (o["annualInc"].to_f / 12) < 0.1 
				# ) &&
				# (
				# 	o["purpose"].to_s == PURPOSES.credit_card || 
				# 	o["purpose"].to_s == PURPOSES.credit_card_refinancing ||
				# 	o["purpose"].to_s == PURPOSES.consolidate
				# )
			end
			if $verbose
				puts filtered_loan_list
				puts "filter_on_additional_criteria.filtered_loan_list.size (after additional filter): #{filtered_loan_list.size}"  #filtered_loan_list is now an array
			end
		end
	end

	def filter_on_owned_loans
		if $verbose
			puts "Filter on owned loans."
			puts "filter_on_owned_loans.filtered_loan_list.size (before removal) #{filtered_loan_list.size}"
		end
		unless loan_list.nil?
			# extract loanId's from a hash of already owned loans and remove those loans from the list of filtered loans
			owned_loans_list.values[0].map {|o| o["loanId"]}.each { |i| @filtered_loan_list.delete_if {|key, value| key["id"] == i} }
		end
		if $verbose
			puts "filter_on_owned_loans.filtered_loan_list.size: #{filtered_loan_list.size}"
		end
	end
	
	def get_owned_loans_list
		method_url = "#{configatron.lending_club.base_url}/#{configatron.lending_club.api_version}/accounts/#{configatron.lending_club.account}/notes"
		if $verbose
			puts "Pulling list of already owned loans."
			puts "method_url: #{__method__} -> #{method_url}"
		end
		begin 
			response = RestClient.get(method_url,
			 		"Authorization" => configatron.lending_club.authorization,
			 		"Accept" => configatron.lending_club.content_type,
			 		"Content-Type" => configatron.lending_club.content_type
				)
		rescue
			PB.add_line("Failure in: #{__method__}\nUnable to get the list of already owned loans.")
		end	
		return response
	end
	
	def build_order_list
		PB.add_line("Placing an order for #{purchasable_loan_count} loans.")

		if purchasable_loan_count > 0
			# sort the loans with the highest interst rate to the front  
			# 	--this is so hightst interest rate loans will be purchased first when there isn't enough available money to purchase all desireable loans
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
		end
		begin
			#log order
			File.open(File.expand_path(configatron.logging.order_list_log), 'a') { |file| file.write("#{Time.now.strftime("%H:%M:%S %d/%m/%Y")}\n#{order_list}\n\n") }
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
	 		puts "Pulling order response from file: '#{configatron.testing_files.purchase_response}'"
		
			response = File.read(File.expand_path("../" + configatron.testing_files.purchase_response, __FILE__))
		else
			unless order_list.nil?
			  	begin
				  	response = RestClient.post(method_url, order_list.to_json,
				  	 	"Authorization" => configatron.lending_club.authorization,
				  	 	"Accept" => configatron.lending_club.content_type,
				  	 	"Content-Type" => configatron.lending_club.content_type
				  	 	)
				rescue
					if $verbose
						puts "Order Response:  #{response}"
						puts "order_list: #{order_list}"
					end
					PB.add_line("Failure in: #{__method__}\nUnable to place order with method_url:\n#{method_url}")
					report_order_response(nil) # order failed; enusure reporting
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
				PB.set_subject("#{invested.size.to_i} of #{purchasable_loan_count}/#{[fundable_loan_count.to_i, loan_list.values[1].size].max}")
				PB.add_line("Successfully Invested:  #{invested.inject(0) { |sum, o| sum + o["investedAmount"].to_f }}") # dollar amount invested
				if not_in_funding.any?
					PB.add_line("No longer in funding:  #{not_in_funding.size}") # NOT_AN_IN_FUNDING_LOAN
				end
			rescue
				if $verbose
					puts "Order Response:  #{response}"
				end
				PB.add_line("Failure in: #{__method__}\nUnable to report on order response.")
			end
		else
			PB.set_subject "0 of #{purchasable_loan_count}/#{[fundable_loan_count.to_i, loan_list.values[1].size].max}"
		end
	end

end


class Account

	def available_cash
		@available_cash ||= get_available_cash.to_i
		if $verbose
			puts "@available_cash: #{@available_cash}"
		end
		@available_cash
	end

	def get_available_cash
		method_url = "#{configatron.lending_club.base_url}/#{configatron.lending_club.api_version}/accounts/#{configatron.lending_club.account}/availablecash"
		if $verbose
			puts "Pulling available cash amount."
			puts "method_url: #{__method__} -> #{method_url}"
		end

		begin 
			response = RestClient.get(method_url,
			 		"Authorization" => configatron.lending_club.authorization,
			 		"Accept" => configatron.lending_club.content_type,		
			 		"Content-Type" => configatron.lending_club.content_type
				)
			result = JSON.parse(response)['availableCash']
			PB.add_line("Available Cash:  #{result}")
		rescue
			PB.add_line("Failure in: #{__method__}\nUnable to get current account balance.")
		end
		
		return result
	end

end


class PushBullet

	def initialize
		pb_client
	end

	def pb_client
		@pb_client ||= PushBullet.initialize_push_bullet_client
		add_line(Time.now.strftime("%H:%M:%S %m/%d/%Y"))
	end

	def self.initialize_push_bullet_client
		Washbullet::Client.new(configatron.push_bullet.api_key)
	end

	def add_line(line)
		@message = "#{@message}\n#{line}"
	end
	
	def set_subject(purchase_count)
		@subject = "Lending Club AutoInvestor - #{purchase_count} purchased"
		if $debug
			@subject = "* DEBUG * " + @subject
		end
	end

	def send_message
		if not $pushbullet 
			return
		end

		add_line("Message sent at #{Time.now.strftime("%H:%M:%S %m/%d/%Y")}")

		if $verbose
	 		puts "PushBullet Message:"
	 		puts view_message
	 	end

	 	begin 
			@pb_client.push_note(receiver: configatron.push_bullet.device_id, params: { title: @subject, body: @message } )
		rescue
			puts "Failure in: #{__method__}\nUnable to send the following PushBullet note:\n"
			puts view_message
		ensure
			#@pb_client = nil
			# setting @message and @subject to nil as setting @pb_client to nil does not appear to cause PushBullet.initialize_push_bullet_client to be called when next launched
			@message = nil
			@subject = nil
		end
	end

	def view_message
		puts "PushBullet Subject:  #{@subject}"
		puts "Message:  #{@message}"
	end

end

# For testing outside of clockwork.d/clock.rb
 PB = PushBullet.new
 A = Account.new

 Loans.new.purchase_loans