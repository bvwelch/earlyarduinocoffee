4-chan TC w/ mcp3424 and mcp9800
Author: William Welch Copyright (c) 2010, all rights reserved.
MIT license: http://opensource.org/licenses/mit-license.php

Circuit description: Originally developed on a JeeNode, later
moved to a RBBB. Both are Arduino clones.

Have dropped the LCD temporarily, to focus on getting data logger software
ready to test with Jim Gallt's version of the tc4 shield: http://code.google.com/p/tc4-shield/



--- early notes ---

The JeeNode has the idea of 'ports', which is just a convention, and
can be emulated on any Arduino, not just a JeeNode. We've tested this
code on both a JeeNode and a RBBB.

For the LCD in this example, we are using the JeeLabs LCD 'plug', which
has an I2C I/O expander to allow I2C control of a typical LCD.

For this example, we have the LCD on 'port 1', and we have the 
mcp3424 and mcp9800 devices sharing 'port 4'.  

Note: The LCD, mcp3424 nd mcp9800 also work fine if they are all sharing
the same 'port'. I just separated them to make it easy to unplug the LCD.

We also have an LED blinking on Arduino digital pin 13.

FIXME: add schematic/fritzing for the circuit.

