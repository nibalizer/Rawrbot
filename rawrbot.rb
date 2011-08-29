#!/usr/bin/env ruby
# (c) Craig Meinschein 2011
# Licensed under the GPLv3 or any later version.
# File:			pfafflebot.rb
# Description:
# 	pfafflebot. An irc bot implemented
#		in Ruby, using the Cinch framework from:
#	 	http://www.rubyinside.com/cinch-a-ruby-irc-bot-
#	 	building-framework-3223.html
#		A work in progress.


require 'cinch'

# Plugin: Karma
# Description:
# 	Tracks positive and negative karma for a given item. Increments
# 	karma when someone adds a ++ after a word (or a series of words 
# 	encapsulated by parentheses) and decrements karma when someone
# 	adds -- to the same.
#
# Requirements:
# 	The Ruby gem 'gdbm' must be installed.
class Karma
	include Cinch::Plugin
	
	require 'gdbm'

	match(/\S+\+\+/, method: :increment, :use_prefix => false)
	match(/\S+--/, method: :decrement, :use_prefix => false)
	match(/karma (.+)/, method: :display)
	match(/help karma/i, method: :karma_help)
	match("help", method: :help)

	# Function: increment
	#
	# Description: Increments karma by one point for each object
	# that has a ++ after it.
	#
	# Converts to a Fixnum (int), adds 1, then converts back to
	# a String, because GDBM doesn't seem to like to store
	# anything but Strings. If an element reaches neutral (0) karma,
	# it deletes it from the DB so the DB doesn't grow any larger
	# than it has to.
	def increment(m)
		karma_db = GDBM.new("karma.db", mode = 0600)
		matches = m.message.scan(/\([^)]+\)\+\+|\S+\+\+/)
	
		matches.each do |element|
			if element =~ /\((.+)\)\+\+/
				if karma_db.has_key? $1
					if karma_db[$1] == "-1"
						karma_db.delete $1	
					else
						karma_db[$1] = (karma_db[$1].to_i + 1).to_s
					end
				else
					karma_db[$1] = "1"
				end
			elsif element =~ /(\S+)\+\+/
				if karma_db.has_key? $1
					if karma_db[$1] == "-1"
						karma_db.delete $1
					else
						karma_db[$1] = (karma_db[$1].to_i + 1).to_s
					end
				else
					karma_db[$1] = "1"
				end
			end
		end

		karma_db.close
	end # End of increment function
	
	# Function: decrement
	#
	# Description: Decrements karma by one point for each object
	# that has a -- after it.
	#
  # Converts to a Fixnum (int), subtracts 1, then converts back to
	# a String, because GDBM doesn't seem to like to store
	# anything but Strings. If an element reaches neutral (0) karma,
	# it deletes it from the DB so the DB doesn't grow any larger
	# than it has to.
	def decrement(m)
		karma_db = GDBM.new("karma.db", mode = 0600)
		matches = m.message.scan(/\([^)]+\)--|\S+--/)
		
		matches.each do |element|
			if element =~ /\((.+)\)--/
				if karma_db.has_key? $1
					if karma_db[$1] == "1"
						karma_db.delete $1	
					else
						karma_db[$1] = (karma_db[$1].to_i - 1).to_s
					end
				else
					karma_db[$1] = "-1"
				end
			elsif element =~ /(\S+)--/
				if karma_db.has_key? $1
					if karma_db[$1] == "1"
						karma_db.delete $1	
					else
						karma_db[$1] = (karma_db[$1].to_i - 1).to_s
					end
				else
					karma_db[$1] = "-1"
				end
			end
		end

		karma_db.close
	end # End of decrement function
	
	# Function: display
	#
	# Description: Displays the current karma level of the requested element.
	#   If the element does not exist in the DB, it has neutral (0) karma.
	def display(m,arg)
		karma_db = GDBM.new("karma.db", mode = 0600)
		if karma_db.has_key?("#{arg}")
			m.reply "#{arg} has karma of #{karma_db[arg]}."
		else
			m.reply "#{arg} has neutral karma."
		end
		karma_db.close
	end # End of display function

	# Function: karma_help
	#
	# Description: Displays help information for how to use the Karma plugin.
	def karma_help(m)
		m.reply "Karma tracker"
		m.reply "==========="
		m.reply "Description: Tracks karma for things. Higher karma = liked more, lower karma = disliked more."
		m.reply "Usage: !karma foo (to see karma level of 'foo')"
		m.reply "foo++ (foo bar)++ increments karma for 'foo' and 'foo bar'"
		m.reply "foo-- (foo bar)-- decrements karma for 'foo' and 'foo bar'"
	end
	
	# Function: help
	#
	# Description: Adds onto the generic help function for other plugins. Prompts
	#   people to use a more specific command to get more details about the
	#   functionality of the Karma module specifically.
	def help(m)
		m.reply "See: !help karma"
	end

end # End of Karma Class

# Plugin: Social
#
# Description:
# 	A friendly plugin, which makes the bot communicate with people who talk
# 	to it.
#
# Requirements:
# 	none
class Social
	include Cinch::Plugin

	match(/hello|hi|howdy|hey|greetings/, :use_prefix => false, method: :greet)
	def greet(m)
		me = m.bot.nick
		print "#{me}\n"
		if m.message.match(/hello|hi|howdy|hey|greetings #{me}/)
			#m.reply "Hello, #{m.user.nick}!"
			print "respond!\n"
		end
	end
end

# Plugin: Messenger
#
# Description:
# 	Sends a PM to a user.
#
# Requirements:
# 	none
class Messenger
	include Cinch::Plugin
	
	match /tell (.+?) (.+)/
	
	def execute(m, receiver, message)
		User(receiver).send(message)
	end
end

# Plugin: LDAPsearch
#
# Description:
# 	Searches LDAP for an account, and returns
# 	results about that account if found.
#
# Requirements:
#		- The Ruby gem NET-LDAP
#		- Authentication information for NET-LDAP in a file named 'ldap_auth.rb'.
#		- Rawrbot must be running on PSU's IP space (131.252.x.x).
class LDAPsearch
	include Cinch::Plugin
	
	require '~/bot/ldap_auth.rb'
	match(/help ldap/i, method: :ldap_help)
	match("help", method: :help)
	match(/ldap (.+)/)
	
	# Function: execute
	#
	# Description: Parses the search query and executes a search on LDAP to retrieve
	# account information. Automatically decides what field of LDAP to search based
	# on what the query looks like. It then prints the results to the IRC user who
	# made the request.
	def execute(m, query)
		
		# Error-checking to sanitize input. i.e. no illegal symbols.
		if query =~ /[^\w@._-]/
			m.reply "Invalid search query '#{query}'"
			return
		end	
		
		# Determine what field to search and proceed to execute it.
		if query =~ /@pdx.edu/
			type = 'email alias'
			attribute = 'mail'
		elsif query =~ /@/
			type = 'forwarding address'
			attribute = 'mailRoutingAddress'
		else
			type = 'username'
			attribute = 'uid'
		end
		m.reply "Performing LDAP search on #{type} #{query}."
		
		ldap_entry = ldap_search attribute,query
	
		#	Piece together the final results and print them out in user-friendly output.
		reply = String.new
		if ldap_entry['dn'].empty?
			reply = "Error: No results.\n"
		elsif ldap_entry['dn'].length > 1
			# Realistically this case should never happen because we filtered '*'
			# out of the search string earlier. If this comes up, something in LDAP
			# is really janky. The logic to account for this is here nonetheless,
			# just in case.
			reply = "Error: Too many results.\n"
		else
			#	Get name, username and dept of the user.
			ldap_entry['gecos'].each { |name| reply << "Name: #{name}\n" }
			ldap_entry['uid'].each { |uid| reply << "Username: #{uid}\n" }
			ldap_entry['ou'].each { |dept| reply << "Dept: #{dept}\n" }
			
			# Determine if the user has opted-in to Google Mail.
			ldap_entry['mailhost'].each do |mhost|
				if mhost =~ /gmx.pdx.edu/
					reply << "Google: yes\n"
				else
					reply << "Google: no\n"
				end
			end
			
			# Determine if this is a sponsored account, and if so, who the sponsor is.
			if ldap_entry['psusponsorpidm'].empty?
				reply << "Sponsored: no\n"
			else
				# Look up sponsor's information.
				reply << "Sponsored: yes\n"
				sponsor_uniqueid = ldap_entry['psusponsorpidm'][0]
				
				ldap_sponsor_entry = ldap_search "uniqueIdentifier",sponsor_uniqueid
				
				sponsor_name = ldap_sponsor_entry['gecos'][0]
				sponsor_uid = ldap_sponsor_entry['uid'][0]
				reply << "Sponsor: #{sponsor_name} (#{sponsor_uid})\n"
			end
			
			# Determine the account and password expiration dates. Also, estimate the date the
			# password was originally set by subtracting 6 months from the expiration date.
			ldap_entry['psuaccountexpiredate'].each do |acctexpiration|
				d = parse_date acctexpiration
				reply << "Account expires: #{d['month']} #{d['day']}, #{d['year']} at #{d['hour']}:#{d['min']}:#{d['sec']}\n"
			end
			ldap_entry['psupasswordexpiredate'].each do |pwdexpiration|
				d = parse_date pwdexpiration
				reply << "Password expires: #{d['month']} #{d['day']}, #{d['year']} at #{d['hour']}:#{d['min']}:#{d['sec']}\n"
				e = d.dup
				if e['month'] =~ /January/
				 	e['month'] = 'July'
				elsif e['month'] =~ /February/ 
					e['month'] = 'August'
				elsif e['month'] =~ /March/
					e['month'] = 'September'
				elsif e['month'] =~ /April/
					e['month'] = 'October'
				elsif e['month'] =~ /May/
					e['month'] = 'November'
				elsif e['month'] =~ /June/
					e['month'] = 'December'
				elsif e['month'] =~ /July/
					e['month'] = 'January'
				elsif e['month'] =~ /August/
					e['month'] = 'February'
				elsif e['month'] =~ /September/
					e['month'] = 'March'
				elsif e['month'] =~ /October/
					e['month'] = 'April'
				elsif e['month'] =~ /November/
					e['month'] = 'May'
				elsif e['month'] =~ /December/
					e['month'] = 'June'
				end
				reply << "Password was set: #{e['month']} #{e['day']}, #{e['year']} at #{e['hour']}:#{e['min']}:#{e['sec']}\n"
			end
			
			# Determine if email is being forwarded to an external address.
			ldap_entry['mailroutingaddress'].each do |forward|
				# If they are on Google, we cannot tell if they are forwarding.
				if ldap_entry['mailhost'][0] =~ /gmx.pdx.edu/
					reply << "Email forwarded to: Unable to determine with Gmail.\n"
				else
					reply << "Email forwarded to: #{forward}\n"
				end
			end

			# Print out any email aliases.
			ldap_entry['maillocaladdress'].each { |email_alias| reply << "Email alias: #{email_alias}\n" }

		end

		# Send results via PM so as to not spam the channel.
		User(m.user.nick).send(reply)

	end # End of execute function.
	
	# Function: parse_date
	#
	# Description: Parses a String containing a date in Zulu time, and returns
	# it as a Hash with each component under a separate key.
	#
	# Arguments:
	# - A String, containing a date/time in Zulu time:
	#   yyyymmddhhmmssZ
	#
	# Returns:
	# - A Hash, containing the parsed date in human-readable format.
	# 	'year' => '2011'
	# 	'month' => 'January'
	# 	'day' => '03'
	# 	also 'hour','min',sec'
	def parse_date date
		unless date =~ /(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})Z/
			return nil
		end
		
		return_date = {
			'year' => $1,
			'month' => $2,
			'day' => $3,
			'hour' => $4,
			'min' => $5,
			'sec' => $6
		}

		return_date['month'] = 'January' if return_date['month'] == '01'
		return_date['month'] = 'February' if return_date['month'] == '02'
		return_date['month'] = 'March' if return_date['month'] == '03'
		return_date['month'] = 'April' if return_date['month'] == '04'
		return_date['month'] = 'May' if return_date['month'] == '05'
		return_date['month'] = 'June' if return_date['month'] == '06'
		return_date['month'] = 'July' if return_date['month'] == '07'
		return_date['month'] = 'August' if return_date['month'] == '08'
		return_date['month'] = 'September' if return_date['month'] == '09'
		return_date['month'] = 'October' if return_date['month'] == '10'
		return_date['month'] = 'November' if return_date['month'] == '11'
		return_date['month'] = 'December' if return_date['month'] == '12'
		
		return return_date
		end # End of parse_date function.
	
	def ldap_help(m)
		m.reply "LDAP Search"
		m.reply "==========="
		m.reply "Description: Performs a search on LDAP for the given query, then returns information about the user's account."
		m.reply "Usage: !ldap [username|email alias|email forwarding address]"
	end # End of ldap_help function.
	
	def help(m)
		m.reply "See: !help ldap"
	end

end # End of LDAPsearch Class.


# Launch the bot
bot = Cinch::Bot.new do
	configure do |config|
		config.server	= "irc.cat.pdx.edu"
		config.port		= 6697
		config.channels = ["#testchan","#helpdesk helpdesk123","#10forward"]
		config.ssl.use	= true
		config.nick		= "rawrbot2"
		config.realname	= "rawrbot 2.0! Brought to you by Ruby."
		config.user		= "rawrbot2"
		config.plugins.plugins = [LDAPsearch,Social,Messenger,Karma]
	end
end

# [2011/08/06 12:10:15.783] >> :pfafflebot MODE pfafflebot:+iwz

bot.start
