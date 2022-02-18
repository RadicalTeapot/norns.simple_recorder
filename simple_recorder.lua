-- Simple recorder
--
-- Triggerable stereo recorder
-- and sample player
--

-- TODO
-- Zoom
--  Enc 1 + Key 1 -> Set zoom level
--  Key 1 -> Zoom in - Reset zoom
--  Zoom is centered on last edited loop point (first or last) and jumps/tracks to the currently edited one
-- Waveform
--  Maybe show two waveforms (1 for right channel, 1 for left)
-- Other
--  Add control for fade time

local midi_handler = include('lib/midi_handler')
local recorder_builder = include('lib/recording_handler')
local player_builder = include('lib/playing_handler')
local sc = include('lib/sc')

local MAX_BUFFER_SIZE = math.floor(softcut.BUFFER_SIZE)
local SAMPLE_COUNT = 128

local player
local recorder

local function toggle_use_midi(state)
    -- Set strategy
    recorder = recorder_builder.get_recorder(state == 0)
    player = player_builder.get_player(state == 0)
end

local function use_midi()
    return params:get("use_midi") == 1
end

local function set_params()
    params:add_binary("use_midi", "Use midi", "toggle", 0)
    params:set_action("use_midi", toggle_use_midi)
    params:add_option("midi_device", "midi out device", midi_handler.get_midi_device_list(), 1)
    params:set_action("midi_device", midi_handler.connect)

    local cs = controlspec.new(0, 1, "lin", 0.01, 0)
    params:add_control("play_start", "Play loop start", cs)
    params:set_action("play_start", function(value) sc:set_play_start(value) end)
    cs = cs:copy()
    cs.default = 1
    params:add_control("play_end", "Play loop end", cs)
    params:set_action("play_end", function(value) sc:set_play_end(value) end)
    params:add_number("scale", "Waveform scale", 1, 50, 10)
    params:add_trigger("arm_record", "(Arm) record")
    params:set_action("arm_record", function() recorder:toggle() end)
    params:add_trigger("arm_play", "(Arm) play")
    params:set_action("arm_play", function() player:toggle() end)

    params:default()
end

function redraw()
    local waveform_left = 10
    local waveform_right = 120
    local waveform_top = 10
    local waveform_bottom = 45

    screen.clear()

    if sc.has_waveform then
        screen.level(4)
        local x_pos = 0
        local scale = params:get("scale") * 50
        local center = math.floor((waveform_bottom + waveform_top) * 0.5)
        local max_half_height = center - waveform_top
        for i,s in ipairs(sc.waveform_samples) do
          local height = math.min(util.round(math.abs(s) * scale), max_half_height)
          screen.move(util.linlin(0,SAMPLE_COUNT,waveform_left,waveform_right,x_pos), center - height)
          screen.line_rel(0, 2 * height)
          x_pos = x_pos + 1
        end
        screen.stroke()

        local height = waveform_bottom - waveform_top
        screen.level(6)
        screen.move(util.linlin(0,1,waveform_left,waveform_right,params:get("play_start")),waveform_top)
        screen.line_rel(0, height)
        screen.move(util.linlin(0,1,waveform_left,waveform_right,params:get("play_end")),waveform_top)
        screen.line_rel(0, height)
        screen.stroke()

        screen.level(15)
        screen.move(util.linlin(0,1,waveform_left,waveform_right,sc.current_play_position),waveform_top)
        screen.line_rel(0, height)
        screen.stroke()
    end

    screen.level(1)
    screen.move(1, 5)
    screen.text("0.0 s")
    screen.move(110, 5)
    screen.text(util.round(sc.loop_end_point, 0.1).." s")
    -- screen.move(util.linlin(0,1,waveform_left,waveform_right,params:get("play_start")) - 10, 53)
    -- screen.text(util.round(norm_to_sec(params:get("play_start")), 0.1).." s")
    -- screen.move(util.linlin(0,1,waveform_left,waveform_right,params:get("play_end")) - 10, 53)
    -- screen.text(util.round(norm_to_sec(params:get("play_end")), 0.1).." s")

    screen.move(1, 63)
    if recorder:playing() then screen.level(15) else screen.level(1) end
    local armed = ""
    if recorder:armed() then armed = "." end
    screen.text("Record"..armed)

    screen.move(110, 63)
    if player:playing() then screen.level(15) else screen.level(1) end
    armed = ""
    if player:armed() then armed = "." end
    screen.text("Play"..armed)

    screen.update()
end

local function register_player_methods()
    local redraw_on_state_change = function() redraw() end
    local sc_update_on_state_change = function(state) sc:set_playing(state) end

    local handle_player_armed_state_changed = function(state)
        if state and recorder:armed() then
            recorder:set(false)
        end
    end

    local handle_playing_state_changed = function(state)
        if state and recorder:playing() then
            recorder:stop_playing()
        end
    end

    player_builder.register_armed_changed_callback(handle_player_armed_state_changed)
    player_builder.register_armed_changed_callback(redraw_on_state_change)

    player_builder.register_playing_changed_callback(handle_playing_state_changed)
    player_builder.register_playing_changed_callback(sc_update_on_state_change)
    player_builder.register_playing_changed_callback(redraw_on_state_change)

    player_builder.register_midi_callbacks(midi_handler.register_start_callback, midi_handler.register_stop_callback)
end

local function register_recorder_methods()
    local redraw_on_state_change = function() redraw() end
    local sc_update_on_state_change = function(state) sc:set_recording(state) end

    local handle_recorder_armed_state_changed = function(state)
        if state and player:armed() then
            player:set(false)
        end
    end

    local handle_recording_state_changed = function(state)
        if state then
            if player:playing() then
                player:stop_playing()
            end
            params:set("play_start", 0)
        end
    end

    recorder_builder.register_armed_changed_callback(handle_recorder_armed_state_changed)
    recorder_builder.register_armed_changed_callback(redraw_on_state_change)

    recorder_builder.register_recording_changed_callback(handle_recording_state_changed)
    recorder_builder.register_recording_changed_callback(sc_update_on_state_change)
    recorder_builder.register_recording_changed_callback(redraw_on_state_change)

    recorder_builder.register_midi_callbacks(midi_handler.register_start_callback, midi_handler.register_stop_callback)
end

function init()
    midi_handler.init(use_midi)
    register_player_methods()
    register_recorder_methods()

    player = player_builder.get_player(true)
    recorder = recorder_builder.get_recorder(true)

    set_params()
    sc = sc.new(SAMPLE_COUNT, MAX_BUFFER_SIZE, function() redraw() end)
end

function enc(index, delta)
    if index == 1 then
        params:delta("scale", delta)
    elseif index == 2 then
        params:delta("play_start", delta)
        if params:get("play_start") > params:get("play_end") then
            params:set("play_start", params:get("play_end"))
        end
        if player:playing() then
            sc.current_play_position = params:get("play_start")
        end
    elseif index == 3 then
        params:delta("play_end", delta)
        if params:get("play_end") < params:get("play_start") then
            params:set("play_end", params:get("play_start"))
        end
        if player:playing() then
            sc.current_play_position = params:get("play_start")
        end
    end

    redraw()
end

function key(index, state)
    if state == 1 then
        if index == 2 then
            recorder:toggle()
        elseif index == 3 then
            player:toggle()
        end
    end
end

function r()
    norns.script.load(norns.state.script)
end
