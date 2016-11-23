require 'washbullet' #PushBullet

class PushBullet

	def initialize
		@pb_client = PushBullet.initialize_push_bullet_client
		add_line(Time.now.strftime("%H:%M:%S %m/%d/%Y"))
	end

	def self.initialize_push_bullet_client
		Washbullet::Client.new(configatron.push_bullet.api_key)
	end

	def message
		@message
	end

	def subject
		@subject
	end

	def add_line(line)
		@message = "#{message}\n#{line}"
	end
	
	def set_subject(purchase_count)
		@subject = "Lending Club AutoInvestor - #{purchase_count} purchased"
		if $debug
			@subject = "* DEBUG * " + subject
		end
	end

	def send_message
		add_line("Message sent at #{Time.now.strftime("%H:%M:%S %m/%d/%Y")}")
		success = false

		if $verbose
	 		puts "-- PushBullet Notification --"
	 		puts view_notification
	 	end

	 	begin 
			@pb_client.push_note(receiver: configatron.push_bullet.device_id, params: { title: subject, body: message } )
			success = true
		rescue
			puts "Failure in: #{__method__}\nUnable to send the following PushBullet note:\n"
			puts view_notification7
		ensure
			@message = nil
			@subject = nil
		end

		return success
	end

	def view_notification
		notification = "Subject:\n#{subject}\nMessage:  #{message}"
		puts notification
		return notification
	end

end