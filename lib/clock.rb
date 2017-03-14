require 'clockwork'
require_relative 'autoinvestor.rb'

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
Clockwork.every(1.days, './autoinvestor.rb', :at => ['6:59', '10:59', '14:59', '18:59']){
	# specialized code here
}
