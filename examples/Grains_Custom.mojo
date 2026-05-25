"""This example demonstrates how to create a custom grain type with a filter inside each grain.

GrainBPF embeds a GrainAll and sends its output through a bandpass filter.

Because the filter introduces some latency, the grain will still be active for a short time after the grain envelope has finished, until the output falls below a certain threshold.
"""

from mmm_audio import *

struct GrainBPF(Grainable2):
    """A custom grain with a BPF inside each grain.
    """
    var world: World 
    var grain: GrainAll
    var start_chan: Int
    var svf: SVF[2]
    var filter_freq: Float64
    var q: Float64
    var last_sample: MFloat[2]

    def __init__(out self, world: World):
        """

        Args:
            world: Pointer to the MMMWorld instance.
        """
        self.world = world  
        self.grain = GrainAll(world)
        self.start_chan = 0
        self.svf = SVF[2](world)
        self.filter_freq = 200.
        self.q = 1.0
        self.last_sample = MFloat[2](0.0)

    def check_active(mut self) -> Bool:
        if self.grain.check_active():
            return True
        elif abs(self.last_sample[0]) > 1e-06 or abs(self.last_sample[1]) > 1e-06:
            return True
        else:
            return False

    def set_trigger(mut self, trigger: Bool):
        self.grain.set_trigger(trigger)
        if trigger:
            self.svf.reset()
    
    def set_env_trigger(mut self, trigger: Bool):
        self.grain.set_env_trigger(trigger)

    def get_env_trigger(self) -> Bool:
        return self.grain.get_env_trigger()

    def set_user_defined_env(mut self, env_params: EnvParams):
        self.grain.set_user_defined_env(env_params)

    def set_vals(mut self, 
    rate: Float64 = 1.0, 
    start_frame: Int = 0, 
    duration: Float64 = 0.0,
    pan: Float64 = 0.0,
    gain: Float64 = 1.0,
    start_chan: Int = 0,
    filter_freq: Float64 = 200.,
    q: Float64 = 1.0
    ):
        self.grain.set_vals(rate, start_frame, duration, pan, gain)
        self.start_chan = start_chan
        self.filter_freq = filter_freq
        self.q = q

    def process_sample(mut self, sample: MFloat[2]) -> MFloat[2]:
            return self.svf.bpf(sample, self.filter_freq, self.q)

    @always_inline
    def next[num_buf_chans: Int, num_playback_chans: Int = 1, win_type: Int = WindowType.hann, custom_curve: Int = WindowType.hann, bWrap: Bool = False](mut self, buffer: SIMDBuffer[num_buf_chans]) -> MFloat[2]:
        
        # get all the channels from the grain
        var sample = self.grain.next[win_type=win_type, custom_curve=custom_curve, bWrap=bWrap](buffer)

        comptime if num_playback_chans == 1:
            panned = pan2(sample[self.start_chan], self.grain.pan)
            panned = self.svf.bpf(panned, self.filter_freq, self.q)
            self.last_sample = panned
            return panned
        else:
            panned = pan_stereo(MFloat[2](sample[self.start_chan], sample[(self.start_chan + 1) % buffer.get_num_chans()]), self.grain.pan) 
            panned = self.svf.bpf(panned, self.filter_freq, self.q)
            self.last_sample = panned
            return panned

struct Grains_Custom(Movable, Copyable):
    var world: World
    var buffer: SIMDBuffer[2]
    
    var tgrains: TGrains2[8, GrainBPF, WindowType.user_defined, WindowType.hann]
    var impulse: Phasor[1]  
    var start_frame: Float64
    var m: Messenger
    var max_trig_rate: Float64
    var env_params: EnvParams
     
    def __init__(out self, world: World):
        self.world = world  

        # buffer uses numpy to load a buffer into an N channel array
        self.buffer = SIMDBuffer[2].load("resources/Shiverer.wav")

        self.tgrains = TGrains2[8, GrainBPF, WindowType.user_defined, WindowType.hann](self.world)  
        self.impulse = Phasor[1](self.world)
        self.m = Messenger(world)
        self.max_trig_rate = 20.0
        self.env_params = EnvParams()
        self.env_params.times = [0.01, 0.9]
        self.env_params.values = [0., 1., 0.]
        self.tgrains.set_env_params(self.env_params)

        self.start_frame = 0.0 

    @always_inline
    def next(mut self) -> MFloat[2]:
        self.m.update("max_trig_rate", self.max_trig_rate)
        c1 = self.m.notify_update("times", self.env_params.times) 
        c2 = self.m.notify_update("values", self.env_params.values) 
        c3 = self.m.notify_update("curves", self.env_params.curves) 
        if c1 or c2 or c3:
            self.tgrains.set_env_params(self.env_params)

        imp_freq = linlin(self.world[].mouse_y, 0.0, 1.0, 1.0, self.max_trig_rate)
        var impulse = self.impulse.next_bool(imp_freq, 0, True)

        start_frame = Int(linlin(self.world[].mouse_x, 0.0, 1.0, 0.0, Float64(self.buffer.num_frames) - 1.0))

        grain_num = self.tgrains.trig(impulse)
        if grain_num >= 0:
            self.tgrains.grains[grain_num].set_vals(1, start_frame, 0.1, random_float64(-1.0, 1.0), 1.0, 0, exprand(200., 8000.), rrand(5.0, 10.0))
        out = self.tgrains.next[2](self.buffer, 1.0)

        return MFloat[2](out[0], out[1])