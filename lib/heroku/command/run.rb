require "readline"
require "heroku/command/base"

# run one-off commands (console, rake)
#
class Heroku::Command::Run < Heroku::Command::Base

  # run COMMAND
  #
  # run an attached process
  #
  def index
    command = args.join(" ")
    fail "Usage: heroku run COMMAND" if command.empty?
    opts = { :attach => true, :command => command, :ps_env => get_terminal_environment }
    ps = action("Running #{command} attached to terminal", :success => "up") do
      ps = heroku.ps_run(app, opts)
      status ps["process"]
      ps
    end
    rendezvous_session(ps["rendezvous_url"])
  end

  # run:detached COMMAND
  #
  # run a detached process, where output is sent to your logs
  #
  def detached
    command = args.join(" ")
    fail "Usage: heroku run COMMAND" if command.empty?
    opts = { :attach => false, :command => command }
    ps = action("Running #{command}", :success => "up") do
      ps = heroku.ps_run(app, opts)
      status ps["process"]
      ps
    end
    puts "Use `heroku logs -p #{ps["process"]}` to view the output."
  end

  # run:rake COMMAND
  #
  # remotely execute a rake command
  #
  def rake
    command = "rake " + args.join(" ")
    fail "Usage: heroku rake COMMAND" if (command == "rake ")
    opts = { :attach => true, :command => command, :ps_env => get_terminal_environment, :type => "rake" }
    ps = heroku.ps_run(app, opts)
    rendezvous_session(ps["rendezvous_url"]) { }
  end

  alias_command "rake", "run:rake"

  # run:console [COMMAND]
  #
  # open a remote console session
  #
  # if COMMAND is specified, run the command and exit
  #
  def console
    cmd = args.join(' ').strip
    if cmd.empty?
      console_session(app)
    else
      display heroku.console(app, cmd)
    end
  rescue RestClient::RequestTimeout
    error "Timed out. Long running requests are not supported on the console.\nPlease consider creating a rake task instead."
  rescue Heroku::Client::AppCrashed => e
    error e.message
  end

  alias_command "console", "run:console"

protected

  def rendezvous_session(rendezvous_url, &on_connect)
    begin
      set_buffer(false)
      $stdin.sync = $stdout.sync = true
      rendezvous = Heroku::Client::Rendezvous.new(
        :rendezvous_url => rendezvous_url,
        :connect_timeout => (ENV["HEROKU_CONNECT_TIMEOUT"] || 120).to_i,
        :activity_timeout => nil,
        :input => $stdin,
        :output => $stdout)
      rendezvous.on_connect(&on_connect)
      rendezvous.start
    rescue Timeout::Error
      error "\nTimeout awaiting process"
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET, OpenSSL::SSL::SSLError
      error "\nError connecting to process"
    rescue Interrupt
    ensure
      set_buffer(true)
    end
  end

  def console_history_dir
    FileUtils.mkdir_p(path = "#{home_directory}/.heroku/console_history")
    path
  end

  def console_session(app)
    heroku.console(app) do |console|
      console_history_read(app)

      display "Ruby console for #{app}.#{heroku.host}"
      while cmd = Readline.readline('>> ')
        unless cmd.nil? || cmd.strip.empty?
          console_history_add(app, cmd)
          break if cmd.downcase.strip == 'exit'
          display console.run(cmd)
        end
      end
    end
  end

  def console_history_file(app)
    "#{console_history_dir}/#{app}"
  end

  def console_history_read(app)
    history = File.read(console_history_file(app)).split("\n")
    if history.size > 50
      history = history[(history.size - 51),(history.size - 1)]
      File.open(console_history_file(app), "w") { |f| f.puts history.join("\n") }
    end
    history.each { |cmd| Readline::HISTORY.push(cmd) }
  rescue Errno::ENOENT
  rescue Exception => ex
    display "Error reading your console history: #{ex.message}"
    if confirm("Would you like to clear it? (y/N):")
      FileUtils.rm(console_history_file(app)) rescue nil
    end
  end

  def console_history_add(app, cmd)
    Readline::HISTORY.push(cmd)
    File.open(console_history_file(app), "a") { |f| f.puts cmd + "\n" }
  end
end
