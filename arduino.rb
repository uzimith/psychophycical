require 'serialport'

class Arduino

  def initialize(port_name, serial_bps)
    @serial_port = SerialPort.new(port_name, serial_bps)
  end

  def send(command)
    @serial_port.write(command)
  end

end
