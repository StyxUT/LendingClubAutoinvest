# Some network addess translation (NAT) may be required if the default predictor web service is on a subnet different from the AutoInvestor 
# E.g. https://community.ubnt.com/t5/EdgeMAX/Having-trouble-allowing-WOL-fowarding/td-p/447457

class WOL #Wake On Lan

	def wake_default_predictor
		# wakeonlan is installed from an OS package manager (E.g apt-get install wakeonlan)
		cmd = "wakeonlan -i #{configatron.wol.host} #{configatron.wol.mac_address}"
		
		if $verbose
			puts "#{cmd}"
		end
		#use the system/OS to execute the command
		system (cmd)
		report_result($?)
	end

	def report_result(result)
		if result.to_i != 0
			puts "wakeonlan did not execute successfully.  Verify it has been instlled."
		end

		result.to_i
	end
end