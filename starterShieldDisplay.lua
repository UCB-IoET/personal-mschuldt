
require("storm")
require("cord")

--------------------------------------------------------------------------------
-- Display module
-- provides access to the 7-segment display
-- ported from:
-- https://github.com/Seeed-Studio/Starter_Shield/blob/master/libraries/TickTockShieldV2/TTSDisplay.cpp
--
-- USAGE:
-- d = require "starterShildDisplay"
-- d:init()
-- d:num(8888)    -- display a number
-- d:time(12, 34) -- display time
-- d:clear()      -- clear display
--------------------------------------------------------------------------------

local Display = {}

-- default pin values
local PINCLK = storm.io.D7 -- pin of clk
local PINDTA = storm.io.D8 -- pin of data

-- definitions for TM1636
local ADDR_AUTO  = 0x40
local ADDR_FIXED = 0x44
local STARTADDR  = 0xc0

-- definitions for brightness
local BRIGHT_DARKEST = 0
local BRIGHT_TYPICAL = 2
local BRIGHTEST      = 7

--Special characters index of tube table
local INDEX_NEGATIVE_SIGH = 16
local INDEX_BLANK         = 17

local setpin = storm.io.set
local getpin = storm.io.get
local pinmode = storm.io.set_mode
local INPUT = storm.io.INPUT
local OUTPUT = storm.io.OUTPUT
local HIGH = storm.io.HIGH
local LOW = storm.io.LOW

Display = {dtaDisplay = {0,0,0,0},
	   _PointFlag = 0,
	   tubeTab = {
	      0x3f,0x06,0x5b,0x4f,
	      0x66,0x6d,0x7d,0x07,
	      0x7f,0x6f,0x77,0x7c,
	      0x39,0x5e,0x79,0x71,
	      0x40,0x00}
	  }

function Display:init(pinclk, pindata)
   self.Clkpin = pinclk or PINCLK
   self.Datapin = pindata or PINDTA
   pinmode(OUTPUT, self.Clkpin)
   pinmode(OUTPUT, self.Datapin)
   self:set()
   --clear()
end

-- displays a num in certain location
-- parameter loca - location: 4-3-2-1
function Display:display(loca, dta)
   dta = dta + 1
   if loca > 4 or loca < 1 then
      return
   end

   self.dtaDisplay[loca] = dta
   loca = 4 - loca
   local segData = self:coding(dta)
   self:start()          --start signal sent to TM1637 from MCU
   self:writeByte(ADDR_FIXED)
   self:stop()

   self:start()
   self:writeByte(bit.bor(loca, 0xc0))
   self:writeByte(segData)
   self:stop()

   self:start()
   self:writeByte(self.Cmd_Dispdisplay)
   self:stop()
end

--  display a number in range 0 - 9999
function Display:num(dta)
   if not dta then
      self:clear()
      return true
   end

   if dta < 0 or dta > 9999 then
      return false
   end

   --clear()
   self:pointOff()
   if dta < 10 then
      self:display(1, dta)
      self:display(2, 0x7f)
      self:display(3, 0x7f)
      self:display(4, 0x7f)
   elseif dta < 100 then
      self:display(2, dta / 10)
      self:display(1, dta % 10)
      self:display(3, 0x7f)
      self:display(4, 0x7f)
   elseif dta < 1000 then
      self:display(3, dta / 100)
      self:display(2, (dta / 10) % 10)
      self:display(1, dta % 10)
      self:display(4, 0x7f)
   else
      self:display(4, dta / 1000)
      self:display(3, (dta / 100) % 10)
      self:display(2, (dta / 10) % 10)
      self:display(1, dta % 10)
   end
   return true
end

function Display:time(hour, min)
   if not hour or hour > 24 or hour < 0 then
      return false
   end
   if not min or min > 60 or min < 0  then
      return false
   end
   self:display(4, hour / 10)
   self:display(3, hour % 10)
   self:display(2, min / 10)
   self:display(1, min % 10)
   return true
end

function Display:clear()
   self:display(1, 0x7f)
   self:display(2, 0x7f)
   self:display(3, 0x7f)
   self:display(4, 0x7f)
   return true
end

--  write a byte to tm1636
function Display:writeByte(wr_data)
   local i, count1 = 0
   local dpin = self.Datapin
   local cpin = self.Clkpin
   for i=1,8 do     -- sent 8bit data
      setpin(LOW, cpin)
      if bit.band(wr_data, 0x01) == 1 then
         setpin(HIGH, dpin)  -- LSB first
      else
         setpin(LOW, dpin)
      end
      wr_data = bit.rshift(wr_data, 1)
      setpin(HIGH, cpin)
   end

   -- wait for the ACK
   setpin(LOW, cpin)
   setpin(HIGH, dpin)
   setpin(HIGH, cpin)
   pinmode(INPUT, dpin)

   while getpin(dpin) ~= 0 do
      count1 = count1 + 1
      if count1 == 200 then
         pinmode(OUTPUT, dpin)
         setpin(LOW, dpin)
         count1 = 0
      end
      pinmode(INPUT, dpin)
   end
   pinmode(OUTPUT, dpin)
end

--  send start signal to Display
function Display:start()
   setpin(HIGH, self.Clkpin)  --send start signal to TM1637
   setpin(HIGH, self.Datapin)
   setpin(LOW, self.Datapin)
   setpin(LOW, self.Clkpin)
end

 -- sends end signal
function Display:stop()
   setpin(LOW, self.Clkpin)
   setpin(LOW, self.Datapin)
   setpin(HIGH, self.Clkpin)
   setpin(HIGH, self.Datapin)
end

function Display:set(brightness, SetData, SetAddr)
   brightness = brightness or BRIGHT_TYPICAL
   self._brightness = brightness
   self.Cmd_SetData = SetData or 0x40
   self.Cmd_SetAddr = SetAddr or 0xc0
   self.Cmd_Dispdisplay = 0x88 + brightness
end

function Display:pointOn()
   self._PointFlag = 1
   local dtaDisplay = self.dtaDisplay
   for i=1,4 do
      self:display(i, dtaDisplay[i])
   end
end

function Display:pointOff()
   self._PointFlag = 0
   local dtaDisplay = self.dtaDisplay
   for i=1,4 do
      self:display(i, dtaDisplay[i])
   end
end

function Display:coding(DispData)
   if DispData <= 0 then
      DispData = 1
   end
   local PointData
   if self._PointFlag ~= 0 then
      PointData = 0x80
   else
      PointData = 0x00
   end
   if DispData > 18 then
      DispData = PointData
   else
      DispData = self.tubeTab[DispData] + PointData
   end
   return DispData
end

return Display
