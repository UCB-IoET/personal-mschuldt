require "cord"
local REG = {}

-- Create a new I2C register binding
function REG:new(port, address)
   obj = {port=port, address=address}
   setmetatable(obj, self)
   self.__index = self
   return obj
end

-- Read a given register address
function REG:r(reg)
   local arr = storm.array.create(1, storm.array.UINT8)
   arr:set(1, reg)
   if cord.await(storm.i2c.write, 
		 self.port + self.address, 
		 storm.i2c.START, arr) ~= storm.i2c.OK then
      return nil
   end
   cord.await(storm.i2c.read, 
	      self.port + self.address, 
	      storm.i2c.RSTART + storm.i2c.STOP,
	      arr)
   return arr:get(1)
end

function REG:w(reg, value)
   local arr = storm.array.create(2, storm.array.UINT8)
   arr:set(1, reg) arr:set(2, value)
   cord.await(storm.i2c.write, 
	      self.port + self.address,
	      storm.i2c.START + storm.i2c.STOP, 
	      arr)
end

return REG
