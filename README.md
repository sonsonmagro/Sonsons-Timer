# Sonson's Timer

A lightweight module for managing timed actions with cooldown periods. I have found this to be useful when you need the main loop to run on a short sleep and without being interrupted.

## Overview

Timer.lua helps you manage actions that need to run at specific intervals without using sleep functions, preventing action spam and optimizing performance. It supports both game tick-based and real-time cooldowns.

## Features

- Cooldown-based action execution
- Custom conditions for triggering actions
- Tick-based or real-time (clock-based) timing
- Debug logging capabilities

## Installation

Include the Timer.lua file in your project directory and require it:

```lua
local Timer = require("timer")
```

## Usage

### Schematic Example

```lua
local myTimer = Timer.new({
    name = "ExampleTimer", 
    cooldown = 1,              -- can be in ms or game ticks (depending on useTicks attribute)
    useTicks = true,           -- whether or not to use game ticks instead of real time
    action = function()
        -- your action code here
        return true            -- return true for successful execution: this is crucial
    end
})

-- check and execute if conditions are met
myTimer:execute()
```

**Parameters:**
- `config` (table):
  - `name` (string): Timer identifier
  - `cooldown` (number): Cooldown period in ms or ticks
  - `useTicks` (boolean): Use game ticks instead of real time
  - `condition` (function): Function that must return true for the action to trigger
  - `action` (function): The action to execute when triggered

### Basic Example With Conditions

```lua
local prayAtAltar = Timer.new(
    {
        name = "Pray at Altar of War",
        cooldown = 3000,      -- 3 seconds
        useTicks = false      -- use real time
        -- will only run if player is not moving and prayer < 95%
        condition = function() return not API.PlayerIsMovin2() and (API.GetPrayPrecent() < 95) end,  
        -- pray at altar of war 
        -- make sure there is a return to avoid spamming
        action = function() return API.DoAction_Object1(0x3d,API.OFF_ACT_GeneralObject_route0, { 114748 }, 50) end
    }
)

-- doensn't have to be used in main loop, you can use it wherever
while API.Read_LoopyLoop() do
    if prayAtAltar:canTrigger() then
        print("Conditionas and cooldowns are met!")
        print("Action will be triggered this cycle")
    else
        print("Conditions or cooldowns are not met.")
        print("Action will NOT be triggered this cycle")
        print("Main loop is unbothered")
    end

     -- will execute the action if conditions are met
    prayAtAltar:execute()
    print("Hello world!")
  
    API.RandomSleep2(100, 30, 50)
end
```

### More Advanced Example Wtih Passed Argumnent

```lua
-- importing my player_manager.lua library
local PlayerManager = require("player_manager")

-- initializing the player manager
local playerManager = PlayerManager.new(config)

local adrenRenewalTimer = Timer.new(
    {
        name = "Use adren renewal,
        cooldown = 2,   -- 2 game ticks (useTick default is true, no need to declare)
        -- player manager instance is passed as an argument
        -- uses methods from playerManager to check for buffs and debuffs
        condition = function(playerManager)
            return playerManager:getBuff(BUFFS.LIVING_DEATH.ID).found and
            not playerManager:getDebuff(DEBUFFS.ADRENALINE_PREVENTION).found
        end
        -- player manager instance is passed as an argument
        -- even if not used in action function it needs to be passed if passed in condition attribute
        -- in this case, another playerManager instance method is being used
        action = function(playerManager) return playerManager:drink(ITEMS.ADRENALINE_RENEWAL.ID) end
    }
)

while API.Read_LoopyLoop() do
    playerManager:update() -- update state info
    if playerManager.state.location == "Boss Room" then
        playerManager:manageHealth()             -- shameless plug
        playerManager:managePrayer()             -- shameless plug
        prayerFlicker:update()                   -- shameless plug
        fightBoss()
        adrenRenewalTimer:execute(playerManager) -- only runs when conditions are met
    end
end
```

### Advanced Example (Integration with [Sonson's Player Manager](https://github.com/sonsonmagro/Sonsons-Player-Manager))
**Bonus: Timer within Timer**

```lua
local Timer = require("Timer")
local PlayerManager = require("player_manager")

-- initializing a flexible timer that will be overriden
local flexTimer = Timer.new(
    {
        name = "Flex timer",
        condition = function() return true end,
        action = function() return true end
    }
)

-- initializing a timer for conjuring familiars
local summonConjures = Timer.new(
    {
        name = "Summon conjures",
        cooldown = 300,         -- 300 ms
        useTicks = false,       -- uses real time instead of game ticks
        condition = function() return true end,     -- controlled by playerManager:_handleStatuses()
        action = function(playerManager)
            --checks if conjures are summoned or animation matches summoning animation
            if playerManager.state.animation == 35502 or (playerManager:getBuff(34177).found and playerManager:getBuff(34178).found and playerManager:getBuff(34179).found) then 
                variables.conjuresSummoned = true
            end

            -- reset flexTimer in case it was used elswhere
            -- override flexTimer configuration
            if not (flexTimer.name == "Summoning conjures" or flexTimer.name == "Excalibur in off-hand -> Equipping lantern") then
                flexTimer.cooldown, flexTimer.useTicks = 200, false
                flexTimer:reset()
            end

            --equip lantern if excal is in off-hand
            if playerManager:_hasExcalibur() and playerManager:_hasExcalibur().location == "equipped" then
                flexTimer.action = function(playerManager) return Inventory:Equip("Augmented Soulbound lantern") end
                flexTimer.name = "Excalibur in off-hand -> Equipping lantern"
                flexTimer:execute(playerManager)
                return true -- exits out of sequence and activates summonConjure's timer
            end

            if flexTimer:canTrigger(playerManager) then
                if variables.conjureAttempts <= 5 then
                    --overrides flexTimer's name, cooldowns and actions
                    flexTimer.cooldown = 600
                    flexTimer.action = function() return Utils.useAbility("Conjure Undead Army") end
                    flexTimer.name = "Summoning conjures"
                    if flexTimer:execute() then
                        variables.conjureAttempts = variables.conjureAttempts + 1
                        return true
                    end
                else
                    Utils.terminate(
                        "Too many summoning conjures attempts failed.",
                        "Make sure you have enough runes in your nexus."
                    )
                end
            end
            return false
        end
    }
)

Config.playerManager = {
    locations = {
        {
            name   = "War's Retreat",
            coords = { x = 3295, y = 10137, range = 30 }
        }
    },
    health = {
        normal = {type = "percent", value = 50},
        critical = {type = "percent", value = 25},
        special = {type = "percent", value = 75}  -- excal threshold
    },
    prayer = {
        normal = {type = "current", value = 200},
        critical = {type = "percent", value = 10},
        special = {type = "current", value = 600}  -- elven shard threshold
    },
    statuses = {
        -- more statuses could be added and will be executed depending on conditions being met and priority
        {
            name = "Summoning conjures",
            condition = function(self) return self.state.location == "War's Retreat" and not variables.conjuresSummoned end,
            -- arguments are passed into execute and then into timer
            execute = function(self) summonConjures:execute(self) end,
            priority = 4
        }
    }
}

-- create a new instance of the player manager
local playerManager = PlayerManager.new(Config.playerManager)

-- main loop
while API.Read_LoopyLoop() do
    playerManager:update() -- will handle everything

    -- zzz
    API.RandomSleep2(60, 10, 10)
end
```


## Version

1.0.0
