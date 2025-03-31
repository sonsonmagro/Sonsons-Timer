---@module 'Timer'
---@version 1.0.0
--[[
    File: timer.lua
    Description : Manages your actions and avoids spamming without having to use sleep
    Author: Sonson
]]

---@class Timer
---@field name string
---@field cooldown number
---@field useTicks boolean
---@field condition fun():boolean
---@field action function
---@field lastTriggered number
local Timer = {}
Timer.__index = Timer

local API = require("api")
local debug = false

---@class TimerConfig
---@field name string
---@field cooldown integer
---@field useTicks boolean?
---@field condition nil | fun(any): boolean
---@field action fun(param: any?): boolean
---@field args any?

-- if debug == true, prints messages in console
---@param message string
function Timer:_debugLog(message)
    if debug then
        print(
            "[TIMER]:",
            self.name .. " | " .. message
        )
    end
end

---initializes a new timer
---@param config TimerConfig
---@return Timer
function Timer.new(config)
    local self = setmetatable({}, Timer)

    if not config then
        print("[TIMER]: No config found when initializing.")
        print("[TIMER]: Terminating your session.")
        API.Write_LoopyLoop(false)
    end

    self.name = config.name or "Unnamed Timer"
    self.cooldown = config.cooldown or 0
    self.useTicks = config.useTicks or true
    self.condition = config.condition or function() return false end
    self.action = config.action
    self.lastTriggered = 0
    return self
end

---checks to see if timer can be triggered
---compares cooldown and timer condition
---@param ... unknown so far only tested with playerManager instance and nil
---@return boolean
function Timer:canTrigger(...)
    local currentTick = self.useTicks and API.Get_tick() or os.clock() * 1000
    local args = {...}

    -- Handle empty arguments safely
    if #args == 0 then
        return ((currentTick - self.lastTriggered) >= self.cooldown) and self.condition()
    end

    return ((currentTick - self.lastTriggered) >= self.cooldown) and self.condition(table.unpack(...))
end

---executes the action provided with the timer after checking if it can be triggered
---@param ... unknown so far only tested with playerManager instance and nil
---@return boolean if action has been executed (assumes action returns a boolean)
function Timer:execute(...)
    local args = {...}
    if self:canTrigger(args) then
        if self.action(table.unpack(args)) then
            self:_debugLog("Action successful.")
            if self.useTicks then
                self:_debugLog("Game tick: "..API.Get_tick())
            else
                self:_debugLog("Time: ".. os.clock() * 1000)
            end
            self.lastTriggered = self.useTicks and API.Get_tick() or os.clock() * 1000
            return true
        end
    end
    return false
end

---resets the timer's last triggered
function Timer:reset()
    self.lastTriggered = 0
end

return Timer