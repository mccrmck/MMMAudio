from mmm_audio import *

# THE SYNTH

comptime num_speakers = 7
comptime num_simd_chans = next_power_of_two(num_speakers)

struct Grains(Movable, Copyable):
    var world: World
    var buffer: SIMDBuffer[2]
    
    var tgrains: TGrains[100] # set the number of simultaneous grains by setting the max_grains parameter here
    var impulse: Phasor[1]  
    var start_frame: Float64
    var m: Messenger
    var max_trig_rate: Float64
    var env_params: EnvParams
     
    def __init__(out self, world: World):
        self.world = world  

        # buffer uses numpy to load a buffer into an N channel array
        self.buffer = SIMDBuffer[2].load("resources/Shiverer.wav")

        self.tgrains = TGrains[100](self.world)  
        self.impulse = Phasor[1](self.world)
        self.m = Messenger(world)
        self.max_trig_rate = 20.0
        self.env_params = EnvParams()

        self.start_frame = 0.0 

    @always_inline
    def next(mut self) -> MFloat[num_simd_chans]:
        self.m.update("max_trig_rate", self.max_trig_rate)
        c1 = self.m.notify_update("times", self.env_params.times) 
        c2 = self.m.notify_update("values", self.env_params.values) 
        c3 = self.m.notify_update("curves", self.env_params.curves) 
        if c1 or c2 or c3:
            self.tgrains.set_env_params(self.env_params)

        imp_freq = linlin(self.world[].mouse_y, 0.0, 1.0, 1.0, self.max_trig_rate)
        var impulse = self.impulse.next_bool(imp_freq, 0, True)

        start_frame = Int(linlin(self.world[].mouse_x, 0.0, 1.0, 0.0, Float64(self.buffer.num_frames) - 1.0))

        comptime if num_speakers == 2:
            grain_num = self.tgrains.trig(impulse)
            if grain_num >= 0:
                self.tgrains.grains[grain_num].set_vals(1, start_frame, 0.4, random_float64(-1.0, 1.0), 1.0, 0)
            out = self.tgrains.next_2[2](self.buffer)

            return MFloat[num_simd_chans](out[0], out[1])
        else:
            grain_num = self.tgrains.trig(impulse)
            if grain_num >= 0:
                self.tgrains.grains[grain_num].set_vals(1, start_frame, 0.4, random_float64(-1.0, 1.0), 1.0, 0)
            out2 = self.tgrains.next_az[num_simd_chans](self.buffer, 1.0, num_speakers)

            return out2