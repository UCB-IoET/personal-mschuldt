require("storm") -- libraries for interfacing with the board and kernel
require("cord") -- scheduler / fiber library
sh = require "stormsh"
sh.start()

print("\n\accelerator.lua")

ACC = require "acc"

cord.new(function() 
	    local a = ACC:new()
	    a:init()
	    local i = 0
	    while true do
	       i = i + 1
	       print(i, a:get())
	       --collectgarbage()
	    end
	 end)

cord.enter_loop() -- start event/sleep loop

