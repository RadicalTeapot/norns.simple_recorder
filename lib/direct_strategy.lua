---@type State
local state = include('lib/state_manager')

local Direct = {}
Direct.__index = Direct

function Direct.new(allow_state_change, state_change_callback)
    local self = {playing_state = state.new(false, allow_state_change, state_change_callback)}
    setmetatable(self, Direct)
    return self
end

function Direct:playing() return self.playing_state:get() end

function Direct:armed() return false end

function Direct:stop_playing() self.playing_state:set(false) end

function Direct:get() return self.playing_state:get() end

function Direct:set(state)
    self.playing_state:set(state)
end

function Direct:toggle()
    self.playing_state:toggle()
end

return Direct
