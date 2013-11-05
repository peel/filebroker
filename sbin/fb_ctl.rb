#!/usr/bin/env ruby

#
# FileBroker - Controller
# (c) 2010-2012 Jakub Zubielik <jakub.zubielik@nordea.com>
#

require 'rubygems'
require 'rack'
require 'fileutils'
require 'webrick'
require 'webrick/https'
require 'openssl'
require 'sinatra/base'
require 'nokogiri'
require 'builder'
require 'digest/md5'
require 'thread'
require 'syslog'
require 'base64'
require 'net/sftp'
require 'net/ftp'
require 'net/ftp/list'
require 'time'
require 'open3'
require 'date'
require 'etc'
require 'pg'
include Rack;


ENV['LC_ALL'] = 'POSIX'

class FBController
	class SyntaxError < StandardError
	end
	
	def initialize
		begin
			Process.euid = File.stat(File.expand_path($0)).uid
		rescue Errno::EPERM
			STDERR.puts "#{File.basename(__FILE__)} has wrong file owner."
			exit 1
		end

		@rootdir = File.expand_path($0).split(/\//)
		@rootdir = @rootdir[0..@rootdir.length - 3].join('/')
    load "#{@rootdir}/lib/common.rb"
    load "#{@rootdir}/lib/filebroker.rb"
  end

	def help
		help = <<HELP

Help for FBController:

DESCRIPTION:

    start
        Starts FBService.
	
    stop
        Stops FBService.
	
    restart
        Restarts FBService.
	
    status
        Displays FBService status.
	
    set configuration <key>=<value>
        Allows to set following setting:
        port	    <1-65536>                tcp port number
        auth	    [none|wss]               authentication method
        ssl         [true|false]             ssl support
        debug       [true|false]             debug settings
        syslog      [true|false]             syslog settings

    set user <login> [password=<md5_digest>|acl="[list|status|transfer]"]
        Allows to set following setting:
        password    <md_digest>              password md5 digest
        acl         [list|status|transfer]   allowed methods

    get configuration [<key>|all]
        Displays configuration.

    get transfer list [running|failed <last_n>|range <time> <time>]
        Displays transfer list.
        running                              displays working transfers
        last        <last_n>                 displays last n transfers
        failed      <last_n>                 displays last n failed transfers
        range       <time> <time>            displays all transfers between two timestamps

    get transfer status <transfer_id>
        Displays detailed transfer status.

    get transfer log <transfer_id>
        Displays transfer log file

    create user <login> password=<md5_digest> acl="[list|status|transfer]"
        Creates user account.
        password    <md_digest>              password md5 digest
        acl         [list|status|transfer]   allowed methods

    remove user <login>
        Remove user account.
	
    get user <login>
        Displays user properties.

    get user list
        Displays user list.

    import key type=<algorithm> description="<string>" file="<string>"
        Imports symmetric encryption key.
        type        [des|des3]
        description <string>
        file        <string>

    get key list
        Displays imported keys.

    help
        Displays current screen.

EXAMPLES:
    #{File.basename(__FILE__)} set configuration auth=basic
    #{File.basename(__FILE__)} set user admin acl="transfer|status"

USAGE:
    #{File.basename(__FILE__)} start
    #{File.basename(__FILE__)} stop
	  #{File.basename(__FILE__)} restart
    #{File.basename(__FILE__)} status
    #{File.basename(__FILE__)} get configuration [<key>=<value>]
    #{File.basename(__FILE__)} get transfer [list [running|last <last_n>|failed <last_n>|range <time> <time>]|status <transfer_id>]
    #{File.basename(__FILE__)} get user [<login>|list]]
    #{File.basename(__FILE__)} set configuration <key>=<value>
    #{File.basename(__FILE__)} set user <login> [password=<md5_digest>|acl="[list|status|transfer]"]
    #{File.basename(__FILE__)} create user <login> password=<md5_digest> acl="[list|status|transfer]"
    #{File.basename(__FILE__)} remove user <login>
    #{File.basename(__FILE__)} import key type=<login> description="<string>" file="<string>"
    #{File.basename(__FILE__)} help

HELP
		puts help
	end
	
	def start
		if File.exist?("#{@rootdir}/tmp/filebroker.pid")
			pid = File.open("#{@rootdir}/tmp/filebroker.pid").readlines("\n")[0].to_i
			begin
				Process.getpgid(pid)
				STDERR.puts "Cannot start. PID file exist."
				exit 1
			rescue
				File.unlink("#{@rootdir}/tmp/filebroker.pid")
			end
		end

		pwd = Dir.pwd
		Dir.chdir(@rootdir)


		#
		# Clean queue and process directory
		#

		Dir.entries("#{@rootdir}/process").each { |dir|
			next if dir =~ /^\.{1,2}$/
      FileUtils.rm_rf("#{@rootdir}/process/#{dir}")
		}


    pid = fork do
			begin
				@fb_shutdown = false
				@db = Database.new
        @db.select_running_transfers.each { |x| @db.update_transfer_status(x['transfer_id'],  FBService::TRANSFER_COMPLETED_WITH_ERRORS, DateTime.now) }
        if @db.select_configuration('debug') == 'true'
					STDOUT.reopen("#{@rootdir}/log/debug.log", 'a+')
					STDERR.reopen("#{@rootdir}/log/debug.log", 'a+')
					STDOUT.sync = true
					STDERR.sync = true
				else
					STDOUT.reopen('/dev/null')
					STDERR.reopen('/dev/null')
				end

				do_quit = Proc.new {
					#@fb_shutdown = true
					Rack::Handler::WEBrick.shutdown
					File.delete("#{@rootdir}/tmp/filebroker.pid")
				}

				Signal.trap('SIGTERM', do_quit)
				Signal.trap('SIGQUIT', do_quit)
				Signal.trap('SIGINT',  do_quit)
				Signal.trap('SIGHUP', 'IGNORE')

				pidfile = File.new("#{@rootdir}/tmp/filebroker.pid", 'w')
				pidfile.puts Process.pid
				pidfile.close

				webrick_options = {
					:Port 				  => @db.select_configuration('port').to_i,
					:ServerSoftware => 'FBService'
				}

				if @db.select_configuration('ssl') == 'true'
					webrick_options = {
						:Port 				    => @db.select_configuration('port').to_i,
						:SSLEnable        => true,
						:SSLVerifyClient  => OpenSSL::SSL::VERIFY_NONE,
						:SSLCertName      => [ [ 'CN', WEBrick::Utils::getservername ] ],
						:SSLCertificate   => OpenSSL::X509::Certificate.new(  File.open(File.join("#{@rootdir}/etc/", 'server.crt')).read),
						:SSLPrivateKey    => OpenSSL::PKey::RSA.new(          File.open(File.join("#{@rootdir}/etc/", 'server.key')).read),
						:ServerSoftware  	=> 'FBService'
					}
				end

				$0 = 'FBService'
				Rack::Handler::WEBrick.run FBService, webrick_options
			rescue
				STDERR.puts $!.to_s
				File.delete("#{@rootdir}/tmp/filebroker.pid") if File.exist?("#{@rootdir}/tmp/filebroker.pid")
			end
		end

		Process.detach(pid)
		Dir.chdir(pwd)
	end
	
	def stop
		if File.exist?("#{@rootdir}/tmp/filebroker.pid")
			pid = File.open("#{@rootdir}/tmp/filebroker.pid", 'r').readlines.first.strip.to_i
			Process.kill 'TERM', pid
			loop {
				begin
				Process.getpgid(pid)
				sleep 0.5
				rescue
					break
				end
			}
		else
			STDERR.puts 'PID file does not exist.'
			exit 1
		end
	end
	
	def parse(cmd)
		begin
			if cmd[0] == 'initdb'
        @db = Database.new
        @db.initdb
			elsif cmd[0] == 'cleandb'
				@db = Database.new
        @db.cleandb
			elsif cmd[0] == "set"
				if cmd[1] == "configuration" and cmd[2] != nil
					key = cmd[2].split("=").first
					val = cmd[2].split("=").last
					raise SyntaxError, "unknown property" if !['port', 'auth', 'ssl', 'debug', 'syslog'].include?(key)
					raise SyntaxError, "bad value" if key == "auth"   and !['none', 'wss'].include?(val)
					raise SyntaxError, "bad value" if key == "ssl"    and !['true', 'false'].include?(val)
					raise SyntaxError, "bad value" if key == "debug"  and !['true', 'false'].include?(val)
					raise SyntaxError, "bad value" if key == "syslog" and !['true', 'false'].include?(val)
					raise SyntaxError, "bad value" if key == "port" and cmd[2].to_i < 1 and cmd[2].to_i > 65536

          @db = Database.new
					@db.update_configuration(cmd[2].split('=').first, cmd[2].split('=').last)
				elsif cmd[1] == 'user' and cmd[2] != nil
					if cmd[3].split("=").first == 'password' and cmd[3].split('=').length > 0
						client = {}
						client['login'] = cmd[2]
						client['password'] = cmd[3].split('=').last
            @db = Database.new
						@db.set_client_password(client)
						puts 'User updated.'
					elsif cmd[3].split('=').first == 'acl' and cmd[3].split('=').length > 0
						client = {}
						client['login'] = cmd[2]
            @db = Database.new
            client = @db.get_client(client)
						client['acl'] = cmd[3].split('=').last.gsub('"', '').split("|")
						@db.set_client_acl(client)
						puts 'ACL updated.'
					else
						raise SyntaxError, 'unknown command'
					end
				else
					raise SyntaxError, 'unknown command'
				end
			elsif cmd[0] == 'get'
				if cmd[1] == 'configuration' and cmd[2] != nil
          @db = Database.new
					if cmd[2] == 'all'
            @db.select_configuration(cmd[2]).each { |x| puts "#{x['key']} = #{x['value']}" }
          else
            puts @db.select_configuration(cmd[2])
          end
				elsif cmd[1] == 'key' and cmd[2] != nil
					if cmd[2] == 'list'
						puts
						puts 'KEYS:'
						80.times { print '-' }
						puts

						puts sprintf('%-8s | %-15s | %s', 'Key ID', 'Type', 'Description')
						80.times { print '-' }
						puts


						@db = Database.new
						@db.select_key_list.each { |x|
							puts sprintf('%-8s | %-15s | %s', '0x%06x' % x['key_id'], x['type'], x['description'])
						}
						puts
					end
				elsif cmd[1] == 'user' and cmd[2] != nil
					if cmd[2] == 'list'
						puts
						puts 'USERS:'
						80.times { print '-' }
						puts

            @db = Database.new
						@db.get_client_list.each { |x|
							puts x['login']
						}
						puts
					else
						puts
						puts 'USER DETAILS:'
						80.times { print '-' }
						puts

            @db = Database.new
            client = {}
						client['login'] = cmd[2]
						client = @db.get_client(client)
						client = @db.get_client_acl(client)

						puts sprintf("%-12s: #{client['login']}", 'Login')
						puts sprintf("%-12s: #{client['password']}", 'Password')
						puts sprintf("%-12s: #{client['acl'].sort.join(' ')}", 'ACL')
						puts
					end
				elsif cmd[1] == 'transfer' and cmd[2] != nil
					if cmd[2] == 'list' and cmd[3] != nil
						if cmd[3] == 'running'
              list = []
              @db = Database.new
							@db.select_running_transfers.each { |x| list << [ x['transfer_hash'], x['status_time'], "#{x['source_protocol']}://#{x['source_login']}@#{x['source_address']}:#{x['source_path']}", "#{x['target_protocol']}://#{x['target_login']}@#{x['target_address']}:#{x['target_path']}" ] }

              if list.length > 0
                src_max = 0
                tgt_max = 0

                list.each { |x|
                  src_len = x[2].length
                  tgt_len = x[3].length
                  src_max = src_len if src_len > src_max
                  tgt_max = tgt_len if tgt_len > tgt_max
                }

                puts
                puts 'RUNNING TRANSFERS [' + list.length.to_s + ']:'
                puts

                puts sprintf("%-32s | %-22s | %-#{src_max}s | %-#{tgt_max}s", 'Transfer ID', 'Time', 'Source', 'Target')
                (63 + src_max + tgt_max).times { print "-" }
                puts

                list.each { |x| puts sprintf("%-32s | %-22s | %-#{src_max}s | %-#{tgt_max}s", x[0], x[1], x[2], x[3]) }
                puts
              else
                puts 'No transfers to display.'
              end
						elsif cmd[3] == 'last' and cmd[4] != nil
              list = []
              @db = Database.new
              @db.select_last_transfers(cmd[4]).each { |x| list << [ x["transfer_hash"], x["status_time"], x["status_desc"], "#{x["source_protocol"]}://#{x["source_login"]}@#{x["source_address"]}:#{x["source_path"]}", "#{x["target_protocol"]}://#{x["target_login"]}@#{x["target_address"]}:#{x["target_path"]}" ] }

              if list.length > 0
                src_max = 0
                tgt_max = 0

                list.each { |x|
                  src_len = x[3].length
                  tgt_len = x[4].length
                  src_max = src_len if src_len > src_max
                  tgt_max = tgt_len if tgt_len > tgt_max
                }

                puts
                puts 'LAST TRANSFERS [' + list.length.to_s + ']:'
                puts

                puts sprintf("%-32s | %-22s | %-31s | %-#{src_max}s | %-#{tgt_max}s", "Transfer ID", "Time", "Status", "Source", "Target")
                (97 + src_max + tgt_max).times { print "-" }
                puts

                list.reverse.each { |x| puts sprintf("%-32s | %-22s | %-31s | %-#{src_max}s | %-#{tgt_max}s", x[0], x[1], x[2], x[3], x[4]) }
                puts
              else
                puts 'No transfers to display.'
              end
						elsif cmd[3] == 'failed' and cmd[4] != nil
              list = []
              @db = Database.new
              @db.select_failed_transfers(cmd[4]).each { |x| list << [ x["transfer_hash"], x["status_time"], x["status_desc"], "#{x["source_protocol"]}://#{x["source_login"]}@#{x["source_address"]}:#{x["source_path"]}", "#{x["target_protocol"]}://#{x["target_login"]}@#{x["target_address"]}:#{x["target_path"]}" ] }

              if list.length > 0
                src_max = 0
                tgt_max = 0

                list.each { |x|
                  src_len = x[3].length
                  tgt_len = x[4].length
                  src_max = src_len if src_len > src_max
                  tgt_max = tgt_len if tgt_len > tgt_max
                }

                puts
                puts 'FAILED TRANSFERS [' + list.length.to_s + ']:'
                puts


                puts sprintf("%-32s | %-22s | %-31s | %-#{src_max}s | %-#{tgt_max}s", "Transfer ID", "Time", "Status", "Source", "Target")
                (97 + src_max + tgt_max).times { print "-" }
                puts

                list.each { |x| puts sprintf("%-32s | %-22s | %-31s | %-#{src_max}s | %-#{tgt_max}s", x[0], x[1], x[2], x[3], x[4]) }
                puts
              else
                puts 'No transfers to display.'
              end
						elsif cmd[3] == "range" and cmd[4] != nil and cmd[5] != nil
              s_time = Time.parse(cmd[4])
              e_time = Time.parse(cmd[5])

              list = []
              @db = Database.new
              @db.select_transfer_between(s_time, e_time).each { |x| list << [ x["transfer_hash"], x["status_time"], x["status_desc"], "#{x["source_protocol"]}://#{x["source_login"]}@#{x["source_address"]}:#{x["source_path"]}", "#{x["target_protocol"]}://#{x["target_login"]}@#{x["target_address"]}:#{x["target_path"]}" ] }

              if list.length > 0
                src_max = 0
                tgt_max = 0

                list.each { |x|
                  src_len = x[3].length
                  tgt_len = x[4].length
                  src_max = src_len if src_len > src_max
                  tgt_max = tgt_len if tgt_len > tgt_max
                }

                puts
                puts "TRANSFERS BETWEEN #{s_time} AND #{e_time} [" + list.length.to_s + ']:'
                puts


                puts sprintf("%-32s | %-22s | %-31s | %-#{src_max}s | %-#{tgt_max}s", "Transfer ID", "Time", "Status", "Source", "Target")
                (97 + src_max + tgt_max).times { print "-" }
                puts

                list.each { |x| puts sprintf("%-32s | %-22s | %-31s | %-#{src_max}s | %-#{tgt_max}s", x[0], x[1], x[2], x[3], x[4]) }
                puts
              else
                puts 'No transfers to display.'
              end
            end
					elsif cmd[2] == 'status' and cmd[3] != nil
            list = []
            @db = Database.new
            status = @db.select_transfers_by_hash(cmd[3])
						raise StandardError, "no such transfer" if status.ntuples == 0

            status = status[0]
						puts
						puts 'TRANSFER DETAILS:'
						80.times { print '-' }
						puts

            puts sprintf("%-16s: #{status['transfer_hash']}",   'Transfer ID')
            puts sprintf("%-16s: #{status['status_desc']}",     'Transfer status')
            puts

            puts sprintf("%-16s: #{status['source_protocol']}", 'Source protocol')
            puts sprintf("%-16s: #{status['source_port']}",     'Source port')
            puts sprintf("%-16s: #{status['source_address']}",  'Source address')
            puts sprintf("%-16s: #{status['source_login']}",    'Source login')
						puts sprintf("%-16s: #{status['source_path']}",     'Source path')
						puts

            puts sprintf("%-16s: #{status['target_protocol']}", 'Target protocol')
            puts sprintf("%-16s: #{status['target_port']}",     'Target port')
            puts sprintf("%-16s: #{status['target_address']}",  'Target address')
            puts sprintf("%-16s: #{status['target_login']}",    'Target login')
            puts sprintf("%-16s: #{status['target_path']}",     'Target path')
            puts
            puts

            @db.select_transfer_files(status['transfer_id']).each { |x| list << [x['filename'], x['status_time'], x['status_type'], x['status_desc']] }

            fname_max = 0
            list.each { |x|
              fname_len = x[0].length
              fname_max = fname_len if fname_len > fname_max
            }

            puts sprintf("%-#{fname_max}s | %-22s | %-12s | %-27s", 'File', 'Time', 'Type', 'Status')
            (70 + fname_max).times { print "-" }
            puts

            list.each { |x|
              puts sprintf("%-#{fname_max}s | %-22s | %-12s | %-27s", x[0], x[1], x[2], x[3])
            }
						puts
					elsif cmd[2] == 'log' and cmd[3] != nil
						f = "#{File.dirname(__FILE__)}/../log/transfer/#{cmd[3]}.log"
            raise StandardError, 'no such transfer' if !File.exist?(f)

            puts
            puts 'TRANSFER LOG:'
            80.times { print '-' }
            puts

            puts File.open(f).readlines
            puts
					else
						raise SyntaxError, 'unknown command'
					end
				else
					raise SyntaxError, 'unknown command'
				end
			elsif cmd[0] == 'create'
				if cmd[1] == 'user'
					raise SyntaxError, 'unknown command' if cmd[3].split('=').first != 'password'
					raise SyntaxError, 'unknown command' if cmd[4].split('=').first != 'acl'
					
					begin
						client = {}
						client['login'] 	  = cmd[2]
						client['password']  = cmd[3].split('=').last
						client['acl']		    = cmd[4].split('=').last.gsub('"', '').split('|')
            @db = Database.new
						@db.insert_client(client)
						puts "User created."
					rescue
						raise StandardError, "cannot create user: #{$!.to_s}"
					end
				else
					raise SyntaxError, 'unknown command'
				end
			elsif cmd[0] == 'remove'
				if cmd[1] == 'user' and cmd[2] != ''
					begin
						client = {}
						client['login'] = cmd[2]
						@db = Database.new
						@db.remove_client(client)
						puts 'User removed.'
					rescue
						raise StandardError, "cannot remove user: #{$!.to_s}"
					end
				else
					raise SyntaxError, 'unknown command'
				end
			elsif cmd[0] == 'start'
				start
			elsif cmd[0] == 'stop'
				stop
			elsif cmd[0] == 'restart'
				stop if File.exist?("#{@rootdir}/tmp/filebroker.pid")

				5.times {
					break File.exist?("#{@rootdir}/tmp/filebroker.pid")
					sleep 1
				}

				start
			elsif cmd[0] == 'import'
				if cmd[1] == 'key' and cmd[2] != ''
					begin
						key = {}
						key['type'] = cmd[2].split('=').last
						key['description'] = cmd[3].split('=').last.gsub(/"/, '')
						key['file'] = cmd[4].split('=').last.gsub(/"/, '')
						@db = Database.new
						id = @db.import_key(key)
						puts "Key #{'0x%06x' % id} imported successfully."
					rescue
						raise StandardError, "cannot import key: #{$!.to_s}"
					end
				else
					raise SyntaxError, 'unknown command'
				end
			elsif cmd[0] == "start"
				start
			elsif cmd[0] == "stop"
				stop
			elsif cmd[0] == "restart"
				stop if File.exist?("#{@rootdir}/tmp/filebroker.pid")

				5.times {
					break File.exist?("#{@rootdir}/tmp/filebroker.pid")
					sleep 1
				}

				start
			elsif cmd[0] == "status"
				if File.exist?("#{@rootdir}/tmp/filebroker.pid")
					puts "FBService is started, pid: #{File.open("#{@rootdir}/tmp/filebroker.pid").readlines.first.strip}."
				else
					puts "FBService is stopped."
				end
			elsif cmd[0] == "help" or cmd[0] == "--help" or cmd[0] == "-?" or cmd[0] == "-h" or cmd[0] == nil
				help
			else
				raise SyntaxError, 'unknown command'
			end
		rescue
			puts "Exception raised: #{$!.to_s}"
			exit 1
		end
	end
end

fb_ctl = FBController.new
fb_ctl.parse(ARGV)
