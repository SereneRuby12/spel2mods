To use any tilecode there you have to use ```require "<file_name>"``` (no need of including .lua at the end).

To use the zones tilecodes you must also use the req_zone function, you can use a table to require multiple zones.

You can use any number for the poison zone, and it will work.

I would recommend using the require on the main.lua (or maybe a make a custom_tilecodes.lua and require it on the main.lua if you want to have a different file for the requires).

### Example
```lua
require "bubble_block"
local zones = require "zones"
zones.req_zone({
    "death_zone",
    "cure_zone",
    "curse_zone",
    "poison_zone3",
    "poison_zone5",
    "poison_zone30",
    "poison_zone941345",
})
```

```lua
zones.req_zone("cure_zone")
zones.req_zone("death_zone")
--etc
```