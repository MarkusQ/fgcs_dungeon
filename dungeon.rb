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

def random_block
    case rand(100)
      when  0..30; Wall
      when 31..33; ('a'.ord+rand(26)).chr
      else Space
      end
  end

100.times { puts }
def draw(map)
    snap = map.map(&:to_a)
    puts ["black".black,"red".red,"green".green,"brown".brown,"navy".navy,"magenta".magenta,"cyan".cyan,
      "gray".gray,"dark gray".dark_gray,"salmon".salmon,"lime".lime,"yellow".yellow,"blue".blue,"pink".pink,"lcyan".light_cyan,
      "lgray".light_gray].join('  ')
    print "\e[;H"
    snap.each_with_index { |line,y|
        line.each_with_index { |block,x|
            if block.is_a? Numeric
                print ("%02i" % block).bg_blue
              elsif block == Wall or block == Space
                print (block+block).light_gray.bg_black
              else
                print (" "+block.cyan).bg_black
              end
          }
        puts
      }
  end

server = ARGV.length == 0

map = if server
    map = (0...height).map { |y| (0...width).map { |x| random_block }}
    map.each { |row| row.extend DRbUndumped }
    p local_ip
    DRb.start_service("druby://#{local_ip}:9001", map)
    map
  else
    p ARGV.first
    DRb.start_service
    DRbObject.new(nil, "druby://#{ARGV.first}:9001")
  end
  
player = { x: rand(width), y: rand(height), dead: false, health: 100, inventory: [], number: server ? 1 : 2 }

map[player[:y]][player[:x]] = player[:number]

message = ""
while not player[:dead]
    while (ch = get_char).nil?
        sleep 0.1
        draw map
        puts "Health: #{player[:health]}  Inventory: #{player[:inventory].join(',')}   #{message}"
        puts "IP: #{local_ip}" if server
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
          when "f"
            item_name = 'food pellet'
            item_verb = 'ate'
            player[:health] += item_count*100
          end
        if item_count > 0
            message << "You #{item_verb} #{item_count} #{item_name}s.  "
          else
            message << "You don't have any #{item_name}s!  "
          end
      when "W"; y = (y-1) % height
      when "S"; y = (y+1) % height
      when "A"; x = (x-1) % width
      when "D"; x = (x+1) % width
      when "Q"; player[:dead] = true
      end
    if y != player[:y] || x != player[:x]
        map[player[:y]][player[:x]] = Space
        case map[y][x]
          when Wall
            player[:health] -= 1
            message << "Ouch!  "
          when Numeric
            message << "Excuse me.   "
          when Space
            player[:x],player[:y] = x,y
          else
            player[:inventory] << map[y][x]
            map[y][x] = Space
            player[:x],player[:y] = x,y
          end
        map[player[:y]][player[:x]] = player[:number]
      end
  end

DRb.thread.join if server  # Don't exit until everyone else is off
