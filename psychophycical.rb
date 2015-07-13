require "curses"
require 'thread'
require 'csv'
require './arduino'

# config
repeation = 10

# filename
subject = "subject"
experiment = 1
time = Time.now.strftime("%y-%m-%d_%H%M%S")
filename = "#{subject}#{experiment}_#{time}"

# arduino
arduino = Arduino.new("/dev/cu.usbmodem1411", 9600)

no_pattern = [
  [ false, false, false ],
  [ false, false, false ],
  [ false, false, false ]
]
patterns = [
  [
    [ true, true, true ],
    [ false, false, false ],
    [ false, false, false ]
  ],
  [
    [ false, false, false ],
    [ true, true, true ],
    [ false, false, false ]
  ],
  [
    [ false, false, false ],
    [ false, false, false ],
    [ true, true, true ]
  ],
  [
    [ true, false, false ],
    [ true, false, false ],
    [ true, false, false ]
  ],
  [
    [ false, true, false ],
    [ false, true, false ],
    [ false, true, false ]
  ],
  [
    [ false, false, true ],
    [ false, false, true ],
    [ false, false, true ]
  ],
  [
    [ true, false, false ],
    [ false, true, false ],
    [ false, false, true ]
  ],
  [
    [ false, false, true ],
    [ false, true, false ],
    [ true, false, false ]
  ],
  [
    [ true, false, true ],
    [ false, false, false ],
    [ true, false, true ]
  ],
  [
    [ false, true, false ],
    [ true, true, true ],
    [ false, true, false ]
  ]
]

def show_pattern(window, pattern)
    pattern.each_with_index do |line, num|
      window.setpos(num+2, 7)
      window.addstr(line.map { |bool| bool ? "o" : "_"}.join)
      window.refresh
    end
end

include Curses
init_screen
cbreak
noecho
curs_set(0)
pattern_window = stdscr.subwin(6,18, 4, 0)
pattern_window.box(?|, ?-, ?+)
pattern_window.setpos(1, 1)
pattern_window.addstr("Target Pattern")
debug_window = stdscr.subwin(6,18, 4, 20)
debug_window.box(?|, ?-, ?+)
debug_window.setpos(1, 1)
debug_window.addstr("Current Ptn")
result_window = stdscr.subwin(patterns.length + 4, 40, 12, 0)
result_window.box(?|, ?-, ?+)
result_window.setpos(1, 1)
result_window.addstr("Result")

correct = 0
CSV.open("data/#{filename}.csv", "wb") do |csv|
  (1..patterns.length).each do |target|
    # show current target
    show_pattern(pattern_window, patterns[target-1])

    pattern_correct = 0

    # wait start
    stdscr.timeout = 1000
    getch
    repeation.times do
      (1..patterns.size).to_a.shuffle.each do |pattern|
        # show current excited pattern
        show_pattern(debug_window, patterns[pattern-1])
        arduino.send(pattern)

        setpos(0, 0)
        addstr("target: %2d " % target + "pattern: %2d" % pattern)

        # wait key push within 1000 msec
        stdscr.timeout = 1000
        start_time = Time.now
        press_time = 1
        pressed = false
        begin working_time = Time.now - start_time
          ch = getch
          if ch && !pressed
            press_time = Time.now - start_time
            setpos(1, 0)
            addstr("#{press_time}s")
            pressed = true
            # display correct/mistake
            setpos(2, 0)
            if target == pattern
              pattern_correct += 1
              addstr("correct")
            else
              addstr("mistake")
            end
          end
          stdscr.timeout = 1 - working_time
        end while working_time < 1
        # deleteln
        csv << [target, pattern, press_time]
      end
    end

    correct += pattern_correct

    # display result
    result_window.setpos(target + 1, 1)
    result_window.addstr("Target #{target}: #{100.0 * pattern_correct / repeation }%")
    result_window.refresh
    show_pattern(debug_window, no_pattern)
    # wait
    stdscr.timeout = 1000
    getch
  end
end
result_window.setpos(patterns.length + 2, 1)
result_window.addstr("Result: #{100.0 * correct / (repeation * patterns.length) }%")
result_window.refresh
stdscr.timeout = -1
getch
