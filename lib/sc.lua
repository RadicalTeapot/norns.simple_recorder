local sc = {}
sc.__index = sc

local function norm_to_sec(value, max)
    return util.linlin(0, 1, 0, max, value)
end

local function sec_to_norm(value, max)
    return util.linlin(0, max, 0, 1, value)
end

local function initialize(self)
    local set_loop_end_point = function(_, position)
        self.loop_end_point = position
        -- TODO this shows only the left channel, it may be better to show both left and right
        softcut.render_buffer(1, 0, self.loop_end_point, self.sample_count)
    end

    local query_play_position = function(_, position)
        self.current_play_position = sec_to_norm(position, self.loop_end_point)
        self.redraw_callback()
    end

    local query_waveform = function(_, _, _, samples)
        self.has_waveform = true
        self.waveform_samples = samples
        self.redraw_callback()
    end

    audio.level_adc_cut(1)
    for i=1,2 do
        softcut.enable(i, 1)
        softcut.buffer(i, i)
        softcut.pan(i, (i-1) * 2 - 1)
        softcut.level_input_cut(i,i,0.5)
        softcut.pre_level(i, 0)
        softcut.rec_level(i, 1)
        softcut.loop(i, 0)
        softcut.loop_start(i, 0)
        softcut.loop_end(i, self.record_buffer_length)
        softcut.position(i, 0)
        softcut.play(i, 1)
        softcut.rate(i, 1)
    end

    softcut.phase_quant(1, 0.1)
    softcut.event_phase(query_play_position)
    softcut.event_position(set_loop_end_point)
    softcut.event_render(query_waveform)
end

local function update_loop_points(self)
    for i=1,2 do
        softcut.loop_start(i, norm_to_sec(self.play_start, self.loop_end_point))
        softcut.loop_end(i, norm_to_sec(self.play_end, self.loop_end_point))
    end
end

function sc.new(sample_count, record_buffer_length, redraw_callback)
    local self = {
        sample_count=sample_count,
        record_buffer_length=record_buffer_length,
        current_play_position=0,
        has_waveform=false,
        waveform_samples = {},
        loop_end_point=record_buffer_length,
        is_playing=false,
        is_recording=false,
        play_start = 0,
        play_end = record_buffer_length,

        redraw_callback=redraw_callback,
    }
    setmetatable(self, sc)
    initialize(self)
    return self
end

function sc:update()
    local recording = self.is_recording and 1 or 0
    local playing = self.is_playing and 1 or 0

    for i=1,2 do
        softcut.play(i, math.max(recording, playing))
        softcut.level(i, playing)
        softcut.rec(i, recording)

        if playing == 1 then
            softcut.loop(i, 1)
            softcut.loop_start(i, norm_to_sec(self.play_start))
            softcut.loop_end(i, norm_to_sec(math.min(self.loop_end_point, self.play_end), self.loop_end_point))
            softcut.position(i, norm_to_sec(self.play_start, self.loop_end_point))
        elseif recording == 1 then
            softcut.loop(i, 0)
            softcut.loop_start(i, 0)
            softcut.loop_end(i, self.record_buffer_length)
            softcut.position(i, 0)
        end
    end
end

function sc:set_playing(state)
    self.is_playing = state

    if state then
        softcut.poll_start_phase()
    else
        softcut.poll_stop_phase()
    end

    self:update()
end

function sc:set_recording(state)
    self.is_recording = state

    if state then
        softcut.buffer_clear()
    else
        softcut.query_position(1)
    end

    self:update()
end

function sc:set_play_start(value)
    self.play_start = value
    if self.is_playing then
        update_loop_points(self)
    end
end

function sc:set_play_end(value)
    self.play_end = value
    if self.is_playing then
        update_loop_points(self)
    end
end


return sc
