require 'minitest/autorun'

require_relative '../lib/autoinvestor/push_bullet.rb'
require_relative '../lib/autoinvestor/configatron.rb'

class AccountTest < Minitest::Test

	def setup
		@push_bullet = PushBullet.new
	end	  

	def test_view_notification
		@push_bullet.add_line "test_view_notification"

		notification = @push_bullet.view_notification
		assert notification.include? "test_view_notification" 
	end

	def test_initialization
		assert_kind_of(PushBullet, @push_bullet)
	end

	def test_add_line
	 	@push_bullet.add_line "test_add_line"
		assert @push_bullet.message.include? "test_add_line" 
	end
	
	def test_set_subject
		orig_debug_status = $debug
		$debug = false

	 	@push_bullet.set_subject "test_set_subject"
		assert @push_bullet.subject.include? "Lending Club AutoInvestor - test_set_subject purchased" 

		$debug = orig_debug_status
	end

	def test_debug_set_subject
		orig_debug_status = $debug
		$debug = true

	 	@push_bullet.set_subject "test_set_subject"
		assert @push_bullet.subject == "* DEBUG * Lending Club AutoInvestor - test_set_subject purchased"

		$debug = orig_debug_status
	end

	def test_send_message
	 	assert @push_bullet.send_message
	end

	def test_send_message_can_fail
		orig_device_id = configatron.push_bullet.device_id
		configatron.push_bullet.orig_device_id = 0000000
	
		skip @push_bullet.send_message, "@push_bullet.send_message succeeded but should have failed because the device_id was fake."
	
	 	configatron.push_bullet.device_id = orig_device_id
	end

end
