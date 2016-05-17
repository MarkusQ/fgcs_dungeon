#
# Warning: I've added the features we discussed but I did so while in a meeting & checking messages on
# my phone & watching a cat video & stuff so the code in the last few commits bugs some may haves.  Use at
# your own risk, be sure to report aby bugs you find.  Enjoy.  :)
#

require 'drb'
require 'socket'

def local_ip
    orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true  # turn off reverse DNS resolution temporarily

    $local_ip ||= UDPSocket.open do |s|
        s.connect '64.233.187.99', 1
        s.addr.last
      end
  ensure
    Socket.do_not_reverse_lookup = orig
  end

class String
    def black;          "\e[30m#{self}\e[0m" end
    def red;            "\e[31m#{self}\e[0m" end
    def green;          "\e[32m#{self}\e[0m" end
    def brown;          "\e[33m#{self}\e[0m" end
    def navy;           "\e[34m#{self}\e[0m" end
    def magenta;        "\e[35m#{self}\e[0m" end
    def cyan;           "\e[36m#{self}\e[0m" end
    def gray;           "\e[37m#{self}\e[0m" end
    def dark_gray;      "\e[30;1m#{self}\e[0m" end
    def salmon;         "\e[31;1m#{self}\e[0m" end
    def lime;           "\e[32;1m#{self}\e[0m" end
    def yellow;         "\e[33;1m#{self}\e[0m" end
    def blue;           "\e[34;1m#{self}\e[0m" end
    def pink;           "\e[35;1m#{self}\e[0m" end
    def light_cyan;     "\e[36;1m#{self}\e[0m" end
    def light_gray;     "\e[37;1m#{self}\e[0m" end

    def bg_black;       "\e[40m#{self}\e[0m" end
    def bg_red;         "\e[41m#{self}\e[0m" end
    def bg_green;       "\e[42m#{self}\e[0m" end
    def bg_brown;       "\e[43m#{self}\e[0m" end
    def bg_blue;        "\e[44m#{self}\e[0m" end
    def bg_magenta;     "\e[45m#{self}\e[0m" end
    def bg_cyan;        "\e[46m#{self}\e[0m" end
    def bg_gray;        "\e[47m#{self}\e[0m" end

    def bold;           "\e[1m#{self}\e[22m" end
    def italic;         "\e[3m#{self}\e[23m" end
    def underline;      "\e[4m#{self}\e[24m" end
    def blink;          "\e[5m#{self}\e[25m" end
    def reverse_color;  "\e[7m#{self}\e[27m" end
  end

height = 30
width  = 40

#
# This routine gets a single character from the keyboard without echoing it
#
def get_char
    state = `stty -g`
    `stty raw -echo -icanon isig`
    (STDIN.read_nonblock(1) rescue nil)
  ensure
    `stty #{state}`
  end

Wall  = "#"
Space = " "
Cat   = "C"

def random_item
    ('a'.ord+rand(10)).chr
  end

def random_block
    case rand(100)
      when  0..30; Wall
      when 31..33; random_item
      else Space
      end
  end

100.times { puts }
def draw(map)
    snap = map.map(&:to_a)[0..-2]
    print "\e[;H\e[;J",snap.each_with_index.map { |line,y|
        line.each_with_index.map { |block,x|
            if block.is_a? Numeric
                ("%02i" % block).bg_blue
              elsif block == Wall or block == Space
                (block+block).light_gray.bg_black
              elsif block == Cat
                (rand(2)==0) ? "😸"  : " 😸"
              else
                (" "+block.cyan).bg_black
              end
          }.join+"\n"
      }.join
  end

def pick_up(player,map,x,y)
    player[:can_carry] -= 1
    player[:can_carry] = nil if player[:can_carry] == 0
    drop(player,map)
    player[:holding] = map[y][x]
    map[y][x] = Space
    player[:x],player[:y] = x,y
  end

def drop(player,map)
    if player[:holding]
        map[player[:y]][player[:x]] = player[:holding]
        player[:holding] = nil
      end
  end


server = ARGV.length == 0

map = $map = if server
    map = (0...height).map { |y| (0...width).map { |x| random_block }}
    map << []
    map.each { |row| row.extend DRbUndumped }
    p local_ip
    DRb.start_service("druby://#{local_ip}:9001", map)
  else
    p ARGV.first
    DRb.start_service
    DRbObject.new(nil, "druby://#{ARGV.first}:9001")
  end

def players(n)
    map[-1][n]
  end
player = {
    x: rand(width), 
    y: rand(height), 
    dead: false, 
    health: 100, 
    inventory: [], 
    number: server ? 1 : map.flatten.select { |q| q.is_a? Numeric}.max+1
  }
player.extend DRbUndumped
map[-1][player[:number] = player
map[player[:y]][player[:x]] = player[:number]

message = ""
prior_x,prior_y = 0,0
while not player[:dead]
    if server
         (0...width).each { |x|
             (0...height) { |y|
                 n = map[y][x]
                 if n.is_a? Numeric
                      plr = players(n)
                      if plr[:x] != x || plr[:y] != y
                          map[y][x] = Space
                        end
                    end
               }
           }
       end
    if player[:health] < 0
        message << "  You have died."
        player[:dead] = true
      end
    being_carried = map[player[:y]][player[:x]] != player[:number]
    while (ch = get_char).nil?
        sleep 0.05
        draw map
        puts "Health: #{player[:health]}  Inventory: #{player[:inventory].join(',')}   #{message}"
        puts "IP: #{local_ip}" if server
        puts "Holding: #{player[:holding]}" if player[:holding]
        puts "Being carried!" if being_carried
      end
    message = ""
    x,y = player[:x],player[:y]
    case ch
      when "a".."z"   # Use items
        item_count = player[:inventory].count ch
        player[:inventory] -= [ch]
        item_name = "'#{ch}'"
        item_verb = 'used'
        case ch
          when "a" # Add two random inventory items
            item_count.times { player[:inventory] << random_item << random_item }
          when "b"
            item_name = 'bomb'
            item_verb = 'set off'
            if item_count > 0
                message << "Boom!  "
                (-item_count..item_count).each { |delta_x|
                    (-item_count..item_count).each { |delta_y|
                        by = (y+delta_y) % height
                        bx = (x+delta_x) % width
                        map[by][bx] = Space unless map[by][bx].is_a? Numeric
                      }
                  }
              end
          when "c" # Carry a wall or player
            player[:can_carry] ||= 0
            player[:can_carry] += item_count
          when "d" # Dagger / digger -- remove wall or hurt player
            if item_count > 0
                (-1..1).each { |dx|
                    (-1..1).each { |dy|
                        x_ = (x+dx) % width
                        y_ = (y+dy) % height
                        if map[y_][x_] == Wall && rand(10) < item_count
                            map[y_][x_] = Space
                            message << "You broke the wall.  I'm telling!!  "
                          elsif map[y_][x_].is_a? Numeric
                            player[:health] -= item_count
                          end
                      }
                  }
              end
            player[:inventory] += ['d']*item_count
          when "e" # ??
          when "f"
            item_name = 'food pellet'
            item_verb = 'ate'
            player[:health] += item_count*100
          when "g" # Gold
          when "t" # Teleport
          end
        if item_count > 0
            message << "You #{item_verb} #{item_count} #{item_name}s.  "
          else
            message << "You don't have any #{item_name}s!  "
          end
      when "W"; y = (y-1) % height unless being_carried
      when "S"; y = (y+1) % height unless being_carried
      when "A"; x = (x-1) % width  unless being_carried
      when "D"; x = (x+1) % width  unless being_carried
      when "Q"; player[:dead] = true
      when "T" # Trade
      when " "
        drop(player,map)
        player[:x],player[:y] = prior_x,prior_y
      end
    if y != player[:y] || x != player[:x]
        prior_x,prior_y = player[:x],player[:y]
        map[player[:y]][player[:x]] = Space
        thing_here = map[y][x] 
        case thing_here
          when Wall
            if player[:can_carry]
                pick_up(player,map,x,y)
                message << "You picked up a wall.  "
              else
                player[:health] -= 1
                message << "Ouch!  "
              end
          when Numeric
            if player[:can_carry]
                pick_up(player,map,x,y)
                message << "You picked up player ##{thing_here}.  "
              else
                message << "Excuse me.   "
              end
          when Space
            player[:x],player[:y] = x,y
          else
            player[:inventory] << thing_here
            map[y][x] = Space
            player[:x],player[:y] = x,y
            x = rand(width)
            y = rand(height)
            while map[y][x] == Space
                 x = rand(width)
                 y = rand(height)
              end
            map[y][x] = random_item
          end
        map[player[:y]][player[:x]] = player[:number]
      end
  end

DRb.thread.join if server  # Don't exit until everyone else is off
