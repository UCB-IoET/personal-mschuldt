require "cord"
sh = require "stormsh"
sh.start()

print("\nrelay demo\n")
 
storm.io.set_mode(storm.io.OUTPUT, storm.io.D4, storm.io.D5)

function start ()
   local delay

   function change (milliseconds)
      delay = storm.os.MILLISECOND*milliseconds
      print(storm.os.SECOND/delay, "times per second")
   end

   cord.new(function ()
	       while true do
		  storm.io.set(storm.io.HIGH, storm.io.D4)
		  cord.await(storm.os.invokeLater, delay)
		  storm.io.set(storm.io.LOW, storm.io.D4)
		  cord.await(storm.os.invokeLater, delay)
	       end
	    end)

   change(1000)
   return change
end

--usage:
-- x = start()
-- x(<new millisecond delay>)

cord.enter_loop()
