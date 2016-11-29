require 'rest-client'

require_relative './configatron.rb'

class Account

	def initialize(push_bullet)
		@pb = push_bullet
	end

	def available_cash
		@available_cash ||= get_available_cash.to_i
		if $verbose
			puts "@available_cash: #{@available_cash}"
		end
		@available_cash
	end

	private
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
			@pb.add_line("Available Cash:  #{result}")
		 rescue
			@pb.add_line("Failure in: #{__method__}\nUnable to get current account balance.")
			result = "!Error"	
		end
	
		return result
	end

end
