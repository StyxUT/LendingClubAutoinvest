require 'clockwork'
require_relative 'autoinvestor.rb'

module Clockwork

	configure do |config|
		config[:sleep_timeout] = 5
		#config[:logger] = Logger.new(log_file_path)
		#config[:tz] = 'UTC'
		config[:max_threads] = 15
		config[:thread] = true
	end
end

#LeningClub releases new loans one minute after these times (MT) each day
Clockwork.every(1.days, './autoinvestor.rb', :at => ['6:59', '10:59', '14:59', '18:59']){
	
	#attempt to purchase desireable notes
	push_bullet = PushBullet.new
	account = Account.new(push_bullet)
	loans = Loans.new(account, push_bullet)
	loans.purchase_loans

	#attempt post delinquent notes to folio
	folio = Folio.new(account, loans, push_bullet)
	folio.sell_delinquent_notes
}
