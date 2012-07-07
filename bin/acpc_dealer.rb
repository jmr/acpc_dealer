#!/usr/bin/env ruby

require 'dmorrill10-utils/process_runner'

require 'fileutils'

require 'clive'

require File.expand_path('../../lib/acpc_dealer', __FILE__)

class AcpcDealerCli < Clive

  def self.print_usage(command_symbol)
    puts AcpcDealerCli.find_command(command_symbol).help
    exit
  end

  def self.game_def_from_components(number_of_players, betting_type)
    begin
      game_def = AcpcDealer::GAME_DEFINITION_FILE_PATHS[number_of_players][betting_type]
      raise unless game_def
    rescue
      puts "Unable to find game definition for #{number_of_players} players with betting type '#{betting_type}'"
      puts "Available game definitions:"
      AcpcDealer::GAME_DEFINITION_FILE_PATHS.each do |num_players, game_defs|
        game_defs.each do |type, path|
          puts "    #{num_players} #{type}"
        end
      end
      exit
    end

    game_def
  end

  command :compile, 'Compiles the ACPC Dealer program' do
    opt :c, :clean, 'Do a clean and full recompile' do
      print 'Cleaning...'
      FileUtils.cd AcpcDealer::DEALER_DIRECTORY do
        system "make clean"
      end
      puts 'Done'
    end

    action do
      print 'Compiling...'
      FileUtils.cd AcpcDealer::DEALER_DIRECTORY do
        system "make"
      end
      puts 'Done'
    end
  end

  command :dealer, 'Runs the ACPC Dealer' do
    desc 'The name of the match, defaults to <number_of_players>p.<betting_type>.h<hands>.r<random_seed>'
    opt :m, :name, arg: '<name>', as: String
    
    desc 'Parameters that determine which game definition to use'
    opt :g, :game_def, args: '<number_of_players> <betting_type>', as: [Integer, Symbol]
    
    opt :n, :hands, 'The number of hands to play', arg: '<hands>', as: Integer
    
    desc 'The random seed to determine how the cards are dealt, defaults to a random random seed'
    opt :r, :random_seed, arg: '<random_seed>', as: Integer
    
    desc 'The names of the players participating in the match, defaults to "p1", "p2", ...'
    opt :p, :player_names, args: '<p1_name>...', as: [String]

    bool :f, :fixed_button, 'Use fixed dealer button at table'
    
    opt :l, :log_directory, 'Directory where logs will be placed'

    opt :t_response, 'Maximum time per response', arg: '<t_response_milliseconds>', as: Integer
    
    opt :t_hand, 'Maximum player time per hand', arg: '<t_hand_milliseconds>', as: Integer
    
    opt :t_per_hand, 'Maximum average player time for match', arg: '<t_per_hand_milliseconds>', as: Integer 
    
    desc 'Maximum time to wait for players to connect, defaults to no timeout'
    opt :start_timeout, arg: '<start_timeout_milliseconds>', as: Integer

    action do
      AcpcDealerCli.print_usage(:dealer) unless get(:game_def)
      AcpcDealerCli.print_usage(:dealer) unless get(:hands)

      (number_of_players, betting_type) = get(:game_def)
      game_def = AcpcDealerCli.game_def_from_components(number_of_players, betting_type)

      random_seed = if get(:random_seed)
        get(:random_seed)
      else
        random_float = rand
        (random_float * 10**random_float.to_s.length).to_i
      end

      name = if get(:name)
        get(:name) 
      else 
        "#{number_of_players}p.#{betting_type}.h#{get(:hands)}.r#{random_seed}"
      end

      player_names = if get(:player_names) 
        get(:player_names)
      else
        []
      end
      
      while player_names.length < get(:game_def).first
          player_names << "p#{player_names.length+1}"
      end

      # Append to produce behavior of previous dealer version
      arguments = [game_def, get(:hands).to_s, random_seed.to_s] + player_names << '-a'

      arguments << '-f' if get(:f)
      arguments << "--t_response #{get(:t_response_milliseconds)}" if get(:t_response_milliseconds)
      arguments << "--t_hand #{get(:t_hand_milliseconds)}" if get(:t_hand_milliseconds)
      arguments << "--t_per_hand #{get(:t_per_hand_milliseconds)}" if get(:t_per_hand_milliseconds)
      arguments << "--start_timeout #{get(:start_timeout_milliseconds)}" if get(:start_timeout_milliseconds)

      log_directory = if get(:log_directory)
        get(:log_directory)
      else
        File.join(FileUtils.pwd, 'dealer_logs')
      end

      AcpcDealerCli.run(['compile']) unless File.exists? AcpcDealer::DEALER_PATH

      puts "Ports: #{DealerRunner.start(name, arguments, log_directory).gets}"
    end
  end

  command :example_player, 'Starts an example player' do
    desc 'Parameters that determine which type of player to use, same format as that for the dealer command'
    opt :g, :game_def, args: '<number_of_players> <betting_type>', as: [Integer, Symbol]

    desc 'The host name of the running dealer, defaults to "localhost"'
    opt :o, :host_name, arg: '<host_name>', as: String

    desc 'The port on which this player will try to connect to the dealer'
    opt :p, :port, arg: '<port>', as: String

    action do
      AcpcDealerCli.print_usage(:example_player) unless get(:game_def)
      AcpcDealerCli.print_usage(:example_player) unless get(:port)

      (number_of_players, betting_type) = get(:game_def)
      # Check that a game def for the specified parameters exists
      AcpcDealerCli.game_def_from_components(number_of_players, betting_type)

      host_name = if get(:host_name) then get(:host_name) else 'localhost' end

      player = AcpcDealer::EXAMPLE_PLAYERS[number_of_players][betting_type]
      players_directory = File.dirname(player)
      FileUtils.cd players_directory
      ProcessRunner.go [player, host_name, get(:port)]

      puts "Example player for #{number_of_players} player #{betting_type}, connected to dealer on #{host_name}:#{get(:port)}"
    end
  end
end

if $0 == __FILE__
  if ARGV.empty?
    puts AcpcDealerCli.help
  else  
    AcpcDealerCli.run
  end
end
