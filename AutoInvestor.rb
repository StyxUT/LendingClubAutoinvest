#!/usr/bin/ruby

require_relative 'configatron.rb'
require 'rubygems'
require 'bundler/setup'
require 'yinum'
require 'rest-client'
require 'json'
require 'pp'
require 'washbullet' #PushBullet
require 'byebug'


#  TODO:
#  Add Setup Instructions
#  		Add instructons for using clock.rb with /etc/init.d/clockworker.sh
#  		Add instruction for using clockworkd and clockwork
# 		(recomend using foreman/upstart)
#  Implement Unit Tests
#  Improve order response messaging
# 		Currently only supports successful purchases, and no longer in funding
#  Add support to allow investing different amounts depending on account factors
#  		E.g. If available funds is larger than $300  and numebr of owned notes is > 500 invest $50 per note instead of $25


###############################
#  Install Instructions:
#  	Rotate logs using logrotate
#		brew install logrotate (OS X only)
#		mkdir /var/log/lending_club_autoinvestor/
# 			ensure executing process has write access to directory
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

# to start: $ sudo bundle exec clockworkd start --log -c ~/projects/LendingClubAutoinvest/clock.rb
# to stop: $ sudo bundle exec clockworkd stop --log -c ~/projects/LendingClubAutoinvest/clock.rb

$debug = false 
$verbose = true

class Loans
	TERMS = Enum.new(:TERMS, :months60 => 60, :months36 => 36)
	PURPOSES = Enum.new(:PURPOSES, :credit_card_refinancing => 'credit_card_refinance', :consolidate => 'debt_consolidation', :other => 'other', :credit_card => 'credit_card', :home_improvement => 'home_improvement', :small_business => 'small_business')

	def purchase_loans
		if check_for_release
			filter_loans
			remove_owned_loans(owned_loans)
			place_order(build_order_list)
		end
		PB.send_message # send PushBullet message
	end

	# LendingClub server time and local server time may not always be synced or loans may be release a bit early or late.  
	# Check for the release of new loans "max_checks" times and attempt to purchase loans when/if loans are released.
	def check_for_release
	 	check_count = 0
	 	max_checks = configatron.lending_club.max_checks
	 	starting_loan_list_size = loan_list.values[1].size
	 	puts "starting_loan_list_size: #{starting_loan_list_size}"
				
	 	while check_count < max_checks
	 		check_count = check_count + 1
	 		puts "check_for_release #{check_count}"
	 		current_loan_list_size = loan_list.values[1].size
	 		puts "current_loan_list_size: #{current_loan_list_size}"
	 		if current_loan_list_size > starting_loan_list_size 
	 			puts "Loans have been released. Preparing to purchasing loans."
	 			PB.add_line("Pre-Filtered Loan Count:  #{current_loan_list_size}")
	 			return true
	 		end
	 		puts "Pre-Filtered Loan Count:  #{current_loan_list_size}"
	 		sleep(2) # wait before checking again
	 	end
	 	PB.add_line("After #{check_count} checks the number of available loans remained at or below #{starting_loan_list_size}.")
	 	return false
	 end
 
	def loan_list
		@loan_list = get_available_loans
		if $verbose
			puts "@loan_list loan count: #{@loan_list.values[1].size}"
		end
		@loan_list # this seems to be necessary, not sure why
	end

	def get_available_loans
		method_url = "#{configatron.lending_club.base_url}/#{configatron.lending_club.api_version}/loans/listing" #only show loans released in the most recent release (add "?showAll=true" to see all loans)
		if $debug
			puts "Pulling available loans from file: '#{configatron.testing_files.available_loans}'"
			response = File.read(File.expand_path("../" + configatron.testing_files.available_loans, __FILE__))
			JSON.parse(response)
			result = JSON.parse(response)
			puts "Pre-Filtered Loan Count (from file):  #{result.values[1].size}"
		else
			begin
				puts "Pulling fresh Loans data."
			 	puts "method_url: #{__method__} -> #{method_url}"
				response = RestClient.get( method_url, 
				 		"Authorization" => configatron.lending_club.authorization,
				 		"Accept" => configatron.lending_club.content_type,
				 		"Content-Type" => configatron.lending_club.content_type
					)
				result = JSON.parse(response)
			rescue
				PB.add_line("Failure in: #{__method__}\nUnable to get a list of available loans.")
			end
		end
		return result 
	end	 

	def filter_loans
		if $verbose
			puts "Filtering loan list."
			# puts "filter_loans.Pre-Filtered Loan Count (before filter):  #{loan_list.values[1].size}"
		end
		unless @loan_list.nil?
			@filtered_loan_list = @loan_list.values[1].select do |o|
				o["term"].to_i == TERMS.months36 && 
				o["annualInc"].to_f / 12 > 3000 &&
				o["empLength"].to_i > 23 && #
				o["inqLast6Mths"].to_i <= 1 &&
				o["pubRec"].to_i == 0 &&
				o["intRate"].to_f < 27.0 &&
				o["intRate"].to_f > 16.0 &&
				o["dti"].to_f <= 20.00 &&
				o["delinq2Yrs"].to_i < 4 &&
				( 	# exclude loans where the monthly instalment amount is more than 10% of the borrower's monthly income
					o["installment"].to_f / (o["annualInc"].to_f / 12) < 0.1 
				) &&
				(
					o["purpose"].to_s == PURPOSES.credit_card || 
					o["purpose"].to_s == PURPOSES.credit_card_refinancing ||
					o["purpose"].to_s == PURPOSES.consolidate
				)
			end
			if $verbose
				puts "filter_loans.@filtered_loan_list.size (after filter): #{@filtered_loan_list.size}"
			end
			# sort the loans with the highest interst rate to the front  
			# --this is so hightst interest rate loans will be purchased first when there aren't enough funds to purchase all desireable loans
			@filtered_loan_list.sort! { |a,b| b["intRate"].to_f <=> a["intRate"].to_f }
		end
	end

	def remove_owned_loans(owned_loans)
		if $verbose
			puts "Removing already owned loans."
			puts "remove_owned_loans.@filtered_loan_list.size (before removal) #{@filtered_loan_list.size}"
		end
		unless loan_list.nil?
			# extract loanId's from a hash of already owned loans and remove those loans from the list of filtered loans
			a = []
			owned_loans.values[0].map {|o| a << o["loanId"]}
			a.each { |i| @filtered_loan_list.delete_if {|key, value| key["id"] == i} }
		end
		if $verbose
			puts "remove_owned_loans.@filtered_loan_list.size: #{@filtered_loan_list.size}"
		end
	end
	
	def owned_loans
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

			result = JSON.parse(response)
		rescue
			PB.add_line("Failure in: #{__method__}\nUnable to get the list of already owned loans.")
		end
		
		return result
	end
	
	def purchasable_loan_count
		@purchasable_loan_count ||= [fundable_loan_count, @filtered_loan_list.size].min
		if $verbose
			puts "@purchasable_loan_count: #{@purchasable_loan_count}"
		end
		@purchasable_loan_count
	end
	
	def build_order_list
		PB.add_line("Placing an order for #{purchasable_loan_count} loans.")

		if purchasable_loan_count > 0
			order_list = Hash["aid" => configatron.lending_club.account, "orders" => 
				@filtered_loan_list.first(purchasable_loan_count).map do |o|
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

	def fundable_loan_count
		@fundable_loan_count ||= A.available_cash.to_i / configatron.lending_club.investment_amount
		if $verbose
			puts "@fundable_loan_count: #{@fundable_loan_count}"
		end
		@fundable_loan_count
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
				PB.set_subject("#{invested.size.to_i} of #{purchasable_loan_count}/#{[fundable_loan_count.to_i, loan_list.size].max}")
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
			PB.set_subject "0 of #{purchasable_loan_count}/#{[fundable_loan_count.to_i, @loan_list.size].max}"
		end
	end

end


class Account

	def available_cash
		@available_cash ||= get_available_cash
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
# PB = PushBullet.new
# A = Account.new

# Loans.new.purchase_loans