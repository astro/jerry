require 'readline'
require 'xmpp4r'
require 'xmpp4r/version'
require 'xmpp4r/muc'

class Color
  class Reset
    def self::to_s
      "\e[0m\e[37m"
    end
  end

  class Black < Color
    def num; 30; end
  end
  class Red < Color
    def num; 31; end
  end
  class Green < Color
    def num; 32; end
  end
  class Yellow < Color
    def num; 33; end
  end
  class Blue < Color
    def num; 34; end
  end
  class Magenta < Color
    def num; 35; end
  end
  class Cyan < Color
    def num; 36; end
  end
  class White < Color
    def num; 37; end
  end

  def self::to_s
    new.to_s
  end

  def to_s
    "\e[1m\e[#{num}m"
  end
end


$cl = nil
class << $cl
  def method_missing(m, *a)
    puts "#{Color::Red}Not connected.#{Color::Reset}"
  end
end

module Commands
  class << self
    def all
      constants.select { |c|
        c =~ /Command$/
      }.collect { |c|
        c.sub(/Command$/, '').downcase
      }
    end
    
    def complete(s)
      all.select { |c|
        c.start_with? s
      }
    end
    
    def get(s)
      constants.select { |c|
        c.downcase == "#{s}command"
      }.map { |c|
        const_get c.intern
      }.first
    end
    
    def invoke(command, s)
      if c = get(command)
        c.new.invoke(s)
      else
        puts "#{Color::Red}No such command: #{Color::Yellow}/#{command.upcase}#{Color::Reset}"
      end
    end
  end

  class QuitCommand
    def invoke(s)
      if s
        $cl.send Jabber::Presence.new(nil, s).set_type(:unavailable)
      end
      exit 0
    end

    def help
      "/QUIT [status]"
    end
  end

  class ConnectCommand
    def invoke(s)
      jid, password = s.split(' ', 2)

      $cl = Jabber::Client.new(jid)
      $cl.add_message_callback { |msg|
        puts "#{Color::Red}#{msg.from.to_s} #{Color::Magenta}#{msg.type} #{Color::Yellow}#{msg.body}#{Color::Reset}"
      }
      $cl.add_presence_callback { |pres|
        show = if pres.type == :unavailable
                   'unavailable'
                 elsif pres.show == nil
                   'available'
                 else
                   pres.show.to_s
               end
        puts "#{Color::Cyan}#{pres.from.to_s} #{Color::Magenta}#{show} #{Color::Green}#{pres.status}"
      }
      Jabber::Version::SimpleResponder.new($cl, 'Jerry', '0.0', `uname -srm`.strip)

      puts "#{Color::Yellow}Connecting...#{Color::Reset}"
      $cl.connect
      puts "#{Color::Yellow}Authenticating...#{Color::Reset}"
      $cl.auth password
      puts "#{Color::Green}Half online. #{Color::Blue}Use /presence or /join or /help#{Color::Reset}"
    end

    def help
      "/CONNECT <jid@domain/resource> <password>"
    end
  end

  class PresenceCommand
    def invoke(s)
      show, status = s.split(' ', 2)
      $pres = if show == 'unavailable'
                Jabber::Presence.new(nil, status).set_type(:unavailable)
              elsif show == 'available'
                Jabber::Presence.new(nil, status)
              else
                Jabber::Presence.new(show.intern, status)
              end
      $cl.send $pres
    end

    def help
      "/PRESENCE <unavailable | available | chat | dnd | away | xa> [status]"
    end
  end

  class MsgCommand
    def invoke(s)
      to, body = s.split(' ', 2)
      $mucs.each { |muc|
        if to.downcase == muc.jid.strip.to_s.downcase
          muc.say body
          return
        end
      }
      $cl.send Jabber::Message.new(to, body).set_type(:chat)
    end

    def help
      "/MSG <jid> <text>"
    end
  end

  class JoinCommand
    def invoke(s)
      room, password = s.split(' ', 2)

      muc = Jabber::MUC::SimpleMUCClient.new($cl)
      $mucs ||= []
      $mucs << muc
      rjid = room
      muc.on_message { |time,nick,text|
        puts "#{Color::Cyan}#{rjid} #{Color::Blue}#{nick} #{Color::Yellow}#{text}#{Color::Reset}"
      }
      muc.on_room_message { |time,text|
        puts "#{Color::Cyan}#{rjid} #{Color::Green}#{text}"
      }
      muc.on_private_message { |time,nick,text|
        puts "#{Color::Cyan}#{rjid} #{Color::Red}#{msg.from.to_s} #{Color::Yellow}#{msg.body}#{Color::Reset}"
      }
      muc.join(room, password)
      rjid = muc.jid.strip.to_s
    end

    def help
      "/JOIN <room@domain/MyNick> [password]"
    end
  end

  class HelpCommand
    def invoke(s)
      unless s
        puts "#{Color::Yellow}Commands: #{Color::Green}" +
          Commands::all.map { |c| "/#{c.upcase}" }.join(" ") +
          "#{Color::Reset}"
      else
        if c = Commands::get(s)
          puts "#{Color::Green}#{c.new.help}#{Color::Reset}"
        else
          puts "#{Color::Red}I know nothing about /#{s}#{Color::Reset}"
        end
      end
    end

    def help
      "/HELP [command]"
    end
  end
end

module Input
  class << self
    def complete(s)
      if s =~ /^\/(.+)/
        Commands.complete($1).collect { |s| "/#{s}" }
      else
        $mucs.collect { |muc|
          muc.jid.strip.to_s
        }.select { |rjid|
          rjid.start_with? s
        }
      end
    end
    
    def invoke(line)
      if line =~ /^\/(.+)/
        c, s = $1.split(' ', 2)
        Commands.invoke c, s
      end
    end
  end
end

quit = false
Readline::completion_proc = Input.method(:complete)
while not quit
  begin
    Input::invoke Readline::readline('> ', true)
  rescue SystemExit, Interrupt, SignalException
    $cl.close
    puts "#{Color::Blue}Good bye!#{Color::Reset}"
    quit = true
  rescue Exception => e
    puts "#{Color::Red}#{e.class}: #{e.to_s}#{Color::Reset}"
    puts "#{Color::Magenta}#{e.backtrace.join("\n")}"
  end
end
