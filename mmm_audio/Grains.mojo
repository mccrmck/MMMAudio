from mmm_audio import *

trait Grainable2(PolyObject):
    """Trait for objects that can be used as grains in the TGrains struct for triggered granular synthesis."""

    def __init__(out self, world: World):
        ...

    def next[num_buf_chans: Int, num_playback_chans: Int = 2, win_type: Int = WindowType.hann, custom_curve: Int = WindowType.none, bWrap: Bool = False](mut self, buffer: SIMDBuffer[num_buf_chans]) -> MFloat[2]:
        return 0.0

    def set_env_trigger(mut self, trigger: Bool):
        pass

    def get_env_trigger(mut self) -> Bool:
        return False

    def set_user_defined_env(mut self, env_params: EnvParams):
        pass

trait GrainableAz(PolyObject):
    """Trait for objects that can be used as grains in the TGrains struct for triggered granular synthesis."""

    def __init__(out self, world: World):
        ...

    def next[num_buf_chans: Int, num_out_chans: Int, win_type: Int = WindowType.hann, custom_curve: Int = WindowType.none, bWrap: Bool = False](mut self, buffer: SIMDBuffer[num_buf_chans], buffer_chan: Int = 0, num_speakers: Int = 2, width: Float64 = 2.0, orientation: Float64 = 0.5) -> MFloat[num_out_chans]:
        return 0.0

    def set_env_trigger(mut self, trigger: Bool):
        pass

    def get_env_trigger(mut self) -> Bool:
        return False

    def set_user_defined_env(mut self, env_params: EnvParams):
        pass

trait GrainableAll(PolyObject):
    """Trait for objects that can be used as grains in the TGrains struct for triggered granular synthesis."""

    def __init__(out self, world: World):
        ...

    def next[num_chans: Int, win_type: Int = WindowType.hann, custom_curve: Int = WindowType.none, bWrap: Bool = False](mut self, buffer: SIMDBuffer[num_chans]) -> MFloat[num_chans]:
        return 0.0

    def set_env_trigger(mut self, trigger: Bool):
        pass

    def get_env_trigger(mut self) -> Bool:
        return False

    def set_user_defined_env(mut self, env_params: EnvParams):
        pass

struct GrainAll(GrainableAll):
    """A single grain for granular synthesis. Returns all channels of a SIMDBuffer and does no panning.

    Used as part of the TGrains and the PitchShift structs for triggered granular synthesis.
    """
    var world: World  # Pointer to the MMMWorld instance

    var start_frame: Float64
    var buf_ratio: Float64  
    var rate: Float64  
    var pan: Float64  
    var gain: Float64 
    var rising_bool_detector: RisingBoolDetector[1]
    var play_buf: Play
    var line: Line[]
    var active: Bool
    var dur: Float64
    var trigger: Bool
    var user_defined_env: Env
    var env_trigger: Bool

    def __init__(out self, world: World):
        """

        Args:
            world: Pointer to the MMMWorld instance.
        """
        self.world = world  
        self.start_frame = 0
        self.buf_ratio = 1.0
        self.rate = 1.0
        self.pan = 0.5 
        self.gain = 1.0
        self.rising_bool_detector = RisingBoolDetector() 
        self.play_buf = Play(world)
        self.line = Line[](world)
        self.line.phase = 1.0
        self.active = False
        self.dur = 1.0
        self.trigger = False
        self.user_defined_env = Env(world)
        self.env_trigger = False

    # These are the functions that need to be implemented for the PolyObject trait:
    def check_active(mut self) -> Bool:
        return self.active

    def set_trigger(mut self, trigger: Bool):
        self.trigger = trigger
        if trigger:
            self.active = True
    # ------------------------------------------------

    def set_env_trigger(mut self, trigger: Bool):
        self.env_trigger = trigger

    def get_env_trigger(self) -> Bool:
        return self.env_trigger
    
    def set_user_defined_env(mut self, env_params: EnvParams):
        self.user_defined_env.params = env_params.copy()
        self.user_defined_env._reset_vals()  

    def set_vals(mut self, 
    rate: Float64 = 1.0, 
    start_frame: Int = 0, 
    duration: Float64 = 0.0,
    pan: Float64 = 0.0,
    gain: Float64 = 1.0):
        """Set the Grain's variables.

        Args:
            rate: Playback rate of the grain (1.0 = normal speed).
            start_frame: Starting frame position in the buffer.
            duration: Duration of the grain in seconds.
            pan: Panning position from -1.0 (left) to 1.0 (right). As this function is used by the panning functions, the pan value is saved to self.pan in this function when a trigger is received, but there is no direct use of it here.
            gain: Amplitude scaling factor for the grain.
        """
        self.rate = rate
        self.start_frame = Float64(start_frame)
        self.buf_ratio = duration * rate
        self.dur = duration
        self.gain = gain
        self.pan = pan

    def next[num_chans: Int, win_type: Int = WindowType.hann, custom_curve: Int = WindowType.none, bWrap: Bool = False](mut self, buffer: SIMDBuffer[num_chans]) -> MFloat[num_chans]:

        phase = self.line.next(0.0, 1.0, self.dur, self.trigger)
        
        buf_phase = (phase * self.buf_ratio)/buffer.duration + (self.start_frame / Float64(buffer.num_frames))
        sample = buf_read[interp=Interp.linear, bWrap=bWrap](self.world, buffer, buf_phase)

        comptime if win_type == WindowType.user_defined:
            win = self.user_defined_env.next(self.env_trigger, phase)
        else:
            win = win_read[win_type, Interp.linear](self.world, phase)

        if phase >= 1.0:
            self.active = False

        # this only works with 1 or 2 channels, if you try to do more, it will just return 2 channels
        sample = sample * win * self.gain  # Apply the window to the sample
        
        return sample

struct Grain2(Grainable2):
    """A single grain for granular synthesis with 2 channel panning.

    Used as part of the TGrains and the PitchShift structs for triggered granular synthesis.
    """
    var world: World 
    var grain: GrainAll
    var start_chan: Int

    def __init__(out self, world: World):
        """

        Args:
            world: Pointer to the MMMWorld instance.
        """
        self.world = world  
        self.grain = GrainAll(world)
        self.start_chan = 0

    def check_active(mut self) -> Bool:
        return self.grain.check_active()

    def set_trigger(mut self, trigger: Bool):
        self.grain.set_trigger(trigger)
    
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
    start_chan: Int = 0):
        """Set the Grain's variables.

        Args:
            rate: Playback rate of the grain (1.0 = normal speed).
            start_frame: Starting frame position in the buffer.
            duration: Duration of the grain in seconds.
            pan: Panning position from -1.0 (left) to 1.0 (right). As this function is used by the panning functions, the pan value is saved to self.pan in this function when a trigger is received, but there is no direct use of it here.
            gain: Amplitude scaling factor for the grain.
            start_chan: The first buffer channel to read from for the grain (default: 0). If num_playback_chans is 2, the grain will read from start_chan and start_chan+1 for the left and right channels, respectively.
        """
        self.grain.set_vals(rate, start_frame, duration, pan, gain)
        self.start_chan = start_chan

    @always_inline
    def next[num_buf_chans: Int, num_playback_chans: Int = 2, win_type: Int = WindowType.hann, custom_curve: Int = WindowType.none, bWrap: Bool = False](mut self, buffer: SIMDBuffer[num_buf_chans]) -> MFloat[2]:
        
        var sample = self.grain.next[win_type=win_type, bWrap=bWrap](buffer)

        comptime if num_playback_chans == 1:
            panned = pan2(sample[self.start_chan], self.grain.pan)
            return panned
        else:
            panned = pan_stereo(MFloat[2](sample[self.start_chan], sample[(self.start_chan + 1) % buffer.get_num_chans()]), self.grain.pan) 
            return panned

struct GrainAz(GrainableAz):
    """A single grain for granular synthesis with 2 channel panning.

    Used as part of the TGrains and the PitchShift structs for triggered granular synthesis.
    """
    var world: World 
    var grain: GrainAll
    var start_chan: Int

    def __init__(out self, world: World):
        """

        Args:
            world: Pointer to the MMMWorld instance.
        """
        self.world = world  
        self.grain = GrainAll(world)
        self.start_chan = 0

    def check_active(mut self) -> Bool:
        return self.grain.check_active()

    def set_trigger(mut self, trigger: Bool):
        self.grain.set_trigger(trigger)
    
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
    start_chan: Int = 0):
        """Set the Grain's variables.

        Args:
            rate: Playback rate of the grain (1.0 = normal speed).
            start_frame: Starting frame position in the buffer.
            duration: Duration of the grain in seconds.
            pan: Panning position from -1.0 (left) to 1.0 (right). As this function is used by the panning functions, the pan value is saved to self.pan in this function when a trigger is received, but there is no direct use of it here.
            gain: Amplitude scaling factor for the grain.
            start_chan: The first buffer channel to read from for the grain (default: 0). If num_playback_chans is 2, the grain will read from start_chan and start_chan+1 for the left and right channels, respectively.
        """
        self.grain.set_vals(rate, start_frame, duration, pan, gain)
        self.start_chan = start_chan

    @always_inline
    def next[num_buf_chans: Int, num_out_chans: Int = 2, win_type: Int = WindowType.hann, custom_curve: Int = WindowType.none, bWrap: Bool = False](mut self, buffer: SIMDBuffer[num_buf_chans], buffer_chan: Int = 0, num_speakers: Int = 2, width: Float64 = 2.0, orientation: Float64 = 0.5) -> MFloat[num_out_chans]:
        
        var sample = self.grain.next[win_type=win_type, bWrap=bWrap](buffer)

        panned = pan_az[num_out_chans](sample[buffer_chan], self.grain.pan, num_speakers, width, orientation) 

        return panned

struct TGrains2[max_grains: Int = 1, T: Grainable2 = Grain2[], win_type: Int = WindowType.hann, custom_curve: Int = WindowType.none](Movable, Copyable):
    """
    Triggered granular synthesis. Each trigger starts a new grain.
    """
    var grains: List[Self.T] 
    var world: World
    var poly: PolyTriggerSig
    var env_params: EnvParams
    var grain_index: Int

    def __init__(out self, world: World):
        """

        Args:
            num_grains: Number of grains to initialize.
            max_grains: Maximum number of grains that can be allocated.
            world: Pointer to the MMMWorld instance.
        """
        self.world = world  
        self.grains = List[Self.T]() 
        for _ in range(Self.max_grains):
            self.grains.append(Self.T(world))
        self.poly = PolyTriggerSig(Self.max_grains, Self.max_grains)  
        self.env_params = EnvParams()  # Initialize with default parameters
        self.grain_index = -1

    def set_env_params(mut self, env_params: EnvParams):
        """Set a the EnvParams of a user-defined envelope for all grains. This allows you to use a custom envelope shape instead of the built-in window types. Will update each grain on its next trigger. (Setting the EnvParams directly will not work).
        
        Args:
            env_params: An EnvParams object that defines the envelope shape.
        """
        self.env_params = env_params.copy()
        # set all the grains to update their user_defined_env with the new env on the next trigger
        for ref grain in self.grains:
            grain.set_env_trigger(True)

    
    def trig(mut self, trig: Bool) -> Int:
        comptime if Self.win_type == WindowType.user_defined:            
            self.grain_index = self.poly.next(self.grains, trig)
            if self.grain_index >= 0:
                if self.grains[self.grain_index].get_env_trigger() and trig:
                    self.grains[self.grain_index].set_user_defined_env(self.env_params.copy())
                    self.grains[self.grain_index].set_env_trigger(False)
        else:
            self.grain_index = self.poly.next(self.grains, trig)
        return self.grain_index

    @always_inline
    def next[num_playback_chans: Int = 1, bWrap: Bool = False](mut self, buffer: SIMDBuffer, gain: Float64 = 1.0) -> MFloat[2]:
        """Generate the next set of grains. Depending on num_playback_chans, will either pan a mono signal out 2 channels or a stereo signal out 2 channels.
        
        Parameters:
            num_playback_chans: Either 1 or 2, depending on whether you want to pan 1 channel of a buffer out 2 channels or 2 channels of the buffer with equal power panning.
            bWrap: Whether to interpolate between the end and start of the buffer when reading (default: False). When False, reading beyond the end of the buffer will return 0. When True, the index into the buffer will wrap around to the beginning using a modulus.

        Args:
            buffer: Audio buffer containing the source sound.
            gain: Amplitude scaling factor for the output of the grains.

        Returns:
            Output samples for left and right channels as a SIMD vector.
        """

        out = MFloat[2](0.0)
        for i in range(len(self.grains)):
            if self.poly.active_list[i]: 
                out += self.grains[i].next[win_type=Self.win_type, custom_curve=Self.custom_curve, bWrap=bWrap](buffer)
        return out * gain

struct TGrains_Az[max_grains: Int = 1, T: GrainableAz = GrainAz[], win_type: Int = WindowType.hann, custom_curve: Int = WindowType.none](Movable, Copyable):
    """
    Triggered granular synthesis. Each trigger starts a new grain.
    """
    var grains: List[Self.T] 
    var world: World
    var poly: PolyTriggerSig
    var env_params: EnvParams
    var grain_index: Int

    def __init__(out self, world: World):
        """

        Args:
            num_grains: Number of grains to initialize.
            max_grains: Maximum number of grains that can be allocated.
            world: Pointer to the MMMWorld instance.
        """
        self.world = world  
        self.grains = List[Self.T]() 
        for _ in range(Self.max_grains):
            self.grains.append(Self.T(world))
        self.poly = PolyTriggerSig(Self.max_grains, Self.max_grains)  
        self.env_params = EnvParams()  # Initialize with default parameters
        self.grain_index = -1

    def set_env_params(mut self, env_params: EnvParams):
        """Set a the EnvParams of a user-defined envelope for all grains. This allows you to use a custom envelope shape instead of the built-in window types. Will update each grain on its next trigger. (Setting the EnvParams directly will not work).
        
        Args:
            env_params: An EnvParams object that defines the envelope shape.
        """
        self.env_params = env_params.copy()
        # set all the grains to update their user_defined_env with the new env on the next trigger
        for ref grain in self.grains:
            grain.set_env_trigger(True)

    
    def trig(mut self, trig: Bool) -> Int:
        comptime if Self.win_type == WindowType.user_defined:            
            self.grain_index = self.poly.next(self.grains, trig)
            if self.grain_index >= 0:
                if self.grains[self.grain_index].get_env_trigger() and trig:
                    self.grains[self.grain_index].set_user_defined_env(self.env_params.copy())
                    self.grains[self.grain_index].set_env_trigger(False)
        else:
            self.grain_index = self.poly.next(self.grains, trig)
        return self.grain_index

    @always_inline
    def next[num_out_chans: Int = 2, bWrap: Bool = False](mut self, buffer: SIMDBuffer, gain: Float64 = 1.0, num_speakers: Int = 2, width: Float64 = 2.0, orientation: Float64 = 0.5) -> MFloat[num_out_chans]:
        """Generate the next set of grains. Depending on num_out_chans, will either pan a mono signal out 2 channels or a stereo signal out 2 channels.
        
        Parameters:
            num_out_chans: A power of two num out channels that will determine the size of the SIMD output.
            bWrap: Whether to interpolate between the end and start of the buffer when reading (default: False). When False, reading beyond the end of the buffer will return 0. When True, the index into the buffer will wrap around to the beginning using a modulus.

        Args:
            buffer: Audio buffer containing the source sound.
            gain: Amplitude scaling factor for the output of the grains.
            num_speakers: The number of speakers in the audio system, which will affect the panning of the grains.
            width: The width of the panning for the azimuth panning. Higher values will make the panning more extreme, while lower values will make it more subtle (default: 2.0).
            orientation: The orientation of the panning for the azimuth panning.

        Returns:
            Output samples for left and right channels as a SIMD vector.
        """

        out = MFloat[num_out_chans](0.0)
        for i in range(len(self.grains)):
            if self.poly.active_list[i]: 
                out += self.grains[i].next[num_out_chans=num_out_chans, win_type=Self.win_type, custom_curve=Self.custom_curve, bWrap=bWrap](buffer, num_speakers=num_speakers, width=width, orientation=orientation)
        return out * gain
