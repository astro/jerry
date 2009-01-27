#!/usr/bin/ruby

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

class Time
  def f
    strftime '%H:%M'
  end
end

MUC = 'c3d2@conference.jabber.ccc.de'

nick = nil
while nick.to_s == ''
  nick = Readline::readline('Your nick: ')
end
cl = Jabber::Client.new(Jabber::JID.new('collector', 'jabber.ccc.de', nick))
Jabber::Version::SimpleResponder.new(cl, 'Astro\'s LittleMUC', '0.0',
                                     "XMPP4R-#{Jabber::XMPP4R_VERSION} on Ruby-#{RUBY_VERSION}")
puts "#{Color::Yellow}Connecting...#{Color::Reset}"
cl.connect
puts "#{Color::Yellow}Authenticating...#{Color::Reset}"
cl.auth '***'
puts "#{Color::Green}Joining room #{Color::Yellow}#{MUC}#{Color::Reset}"
muc = Jabber::MUC::SimpleMUCClient.new(cl)
muc.on_message { |time,nick,text|
  print "#{Color::Blue}[#{time.f}]" if time
  puts "#{Color::Yellow}<#{nick}> #{Color::Reset}#{text}"
}
muc.on_room_message { |time,text|
  print "#{Color::Blue}[#{time.f}]" if time
  puts "#{Color::Green}#{text}"
}
muc.on_private_message { |time,nick,text|
  print "#{Color::Blue}[#{time.f}]" if time
  puts "#{Color::Red}<#{msg.from.to_s}> #{Color::Yellow}#{msg.body}#{Color::Reset}"
}
muc.on_join { |time,nick|
  print "#{Color::Blue}[#{time.f}]" if time
  puts "#{Color::Magenta}#{nick} has joined#{Color::Reset}"
}
muc.on_leave { |time,nick|
  print "#{Color::Blue}[#{time.f}]" if time
  puts "#{Color::Magenta}#{nick} has left#{Color::Reset}"
}
muc.on_self_leave { |time,nick|
  puts "#{Color::Blue}You have left the room#{Color::Reset}"
  exit
}
muc.join("#{MUC}/#{nick}")
puts "#{Color::Green}Welcome to #{Color::Yellow}#{MUC}#{Color::Reset}"


while line = Readline::readline("")
  begin
    muc.say line if line.size >= 1
  rescue Exception => e
    puts "#{Color::Red}#{e.class}: #{e.to_s}#{Color::Reset}"
    puts "#{Color::Magenta}#{e.backtrace.join("\n")}"
  end
end
