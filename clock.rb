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

#LeningClub releases new loas at these times (MT) each day
Clockwork.every(1.days, 'AutoInvestor.rb', :at => ['7:00', '11:00', '15:00', '19:00']){
	
	PB = PushBullet.new
	A = Account.new

	Loans.new.purchase_loans
	sleep(3)
	Loans.new.purchase_loans
	sleep(5)
	Loans.new.purchase_loans

}
