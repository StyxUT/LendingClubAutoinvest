require 'clockwork'
require_relative 'AutoInvestor.rb'

module Clockwork

	configure do |config|
		config[:sleep_timeout] = 1
		#config[:logger] = Logger.new(log_file_path)
		#config[:tz] = 'UTC'
		config[:max_threads] = 15
		config[:thread] = false
	end
end

#LeningClub releases new loans one minute after these times (MT) each day
Clockwork.every(1.days, 'AutoInvestor.rb', :at => ['6:59', '10:59', '14:59', '18:59']){
	
	PB = PushBullet.new
	A = Account.new
	Loans.new.purchase_loans
	PB = nil
	A = nil

	# run again to try to pick up loans that may have been "no longer in funding" but have become available again
	PB = PushBullet.new
	A = Account.new
	Loans.new.purchase_loans
	PB = nil
	A = nil
}
