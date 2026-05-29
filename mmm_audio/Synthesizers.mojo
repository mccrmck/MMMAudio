from mmm_audio import *

struct PAF[
    num_chans: Int = 1,
    interp: Int = Interp.linear,
    os_index: Int = 0,
    wrap_gaussian: Bool = False,
](Copyable, Movable):
    """Phase-Aligned Formant generator using a single phasor to synthesize multiple windows. From Miller Puckette's "Theory and Technique of Electronic Music," page 170.

    Parameters:
        num_chans: Number of channels.
        interp: Interpolation method. See [Interp](MMMWorld.md/#struct-interp) struct for options.
        os_index: [Oversampling](Oversampling.md) index (0 = no oversampling, 1 = 2x, 2 = 4x, etc.).
        wrap_gaussian: Whether to wrap indices that go out of bounds in the gaussian window. Puckette's design only uses half of the table, but enabling wrap_gaussian uses the entire table, resulting in a wider pallette of timbres.
    """

    var world: World

    var phasor: Phasor[Self.num_chans, Self.os_index]
    var cos1: Osc[Self.num_chans, Self.interp, Self.os_index]
    var cos2: Osc[Self.num_chans, Self.interp, Self.os_index]
    var lag: Lag[Self.num_chans]
    var env: Env[]
    var env_buffer: SIMDBuffer[1]
    var gauss_last_phase: MFloat[Self.num_chans]
    var sin_last_phase: MFloat[Self.num_chans]
    var sin: Windows
    var gaussian: Windows
    var cos1_last_phase: MFloat[Self.num_chans]

    var oversampling: Oversampling[Self.num_chans, 2**Self.os_index]

    def __init__(out self, world: World):
        """
        Args:
            world: Pointer to the MMMWorld instance.
        """
        self.world = world

        self.phasor = Phasor[Self.num_chans, Self.os_index](self.world)
        self.cos1 = Osc[Self.num_chans, Self.interp, Self.os_index](self.world)
        self.cos2 = Osc[Self.num_chans, Self.interp, Self.os_index](self.world)
        self.lag = Lag[Self.num_chans](self.world)
        self.env = Env[](self.world)
        self.env_buffer = Env.get_env_buffer[1, win_type=WindowType.gaussian](
            self.world, 2048
        )
        self.gauss_last_phase = 0.0
        self.sin_last_phase = 0.0
        self.sin = Windows()
        self.gaussian = Windows()
        self.cos1_last_phase = MFloat[self.num_chans](0.0)

        self.oversampling = Oversampling[Self.num_chans, 2**Self.os_index](
            self.world
        )

    @always_inline
    def next(
        mut self,
        fundamental: MFloat[Self.num_chans] = MFloat[Self.num_chans](100.0),
        center_freq: MFloat[Self.num_chans] = MFloat[Self.num_chans](440.0),
        bandwidth: MFloat[Self.num_chans] = MFloat[Self.num_chans](1.0),
    ) -> MFloat[Self.num_chans]:
        """Generate the next synthesized sample.

        Args:
            fundamental: Fundamental frequency of the phasor.
            center_freq: Center frequency of the formant.
            bandwidth: Bandwidth.

        Returns:
            The next sample of the synthesizer output.
        """
        fund = self.lag.next(fundamental)
        cos1 = MFloat[Self.num_chans](0.0)
        cos2 = MFloat[Self.num_chans](0.0)
        sin = MFloat[Self.num_chans](0.0)
        gaussian_phase = MFloat[Self.num_chans](0.0)
        gaussian = MFloat[Self.num_chans](0.0)
        mod = MFloat[Self.num_chans](0.0)
        out = MFloat[Self.num_chans](0.0)

        a = center_freq / fund
        b = wrap(a, 0.0, 1.0)

        comptime for _ in range(2**Self.os_index):
            phasor = self.phasor.next(fund)

            cos1_phase = phasor * (a - b)
            cos2_phase = cos1_phase + phasor
            for chan in range(Self.num_chans):
                cos1[chan] = self.cos1.next(
                    freq=0, phase_offset=cos1_phase[chan] + 0.25
                )[chan]

                cos2[chan] = self.cos2.next(
                    freq=0, phase_offset=cos2_phase[chan] + 0.25
                )[chan]

                sin[chan] = self.sin.at_phase[
                    window_type=WindowType.sine, interp=Self.interp
                ](self.world, phasor[chan], self.sin_last_phase[chan])

                gaussian_phase[chan] = (
                    sin[chan] * ((bandwidth[chan] / fund[chan]) * 0.25)
                ) + 0.5

                gaussian[chan] = self.gaussian.at_phase[
                    window_type=WindowType.gaussian, interp=Self.interp
                ](self.world, gaussian_phase[chan], self.gauss_last_phase[chan])

                mod[chan] = ((cos2[chan] - cos1[chan]) * b[chan]) + cos1[chan]
                out[chan] = mod[chan] * gaussian[chan]
                self.gauss_last_phase[chan] = gaussian_phase[chan]
                self.sin_last_phase[chan] = phasor[chan]
                self.cos1_last_phase[chan] = cos1_phase[chan]

            # add sample to oversampling buffer each iteration
            if self.os_index != 0:
                self.oversampling.add_sample(out)

        # retrive sample from oversampling buffer only if oversampling is enabled
        if self.os_index != 0:
            return self.oversampling.get_sample()
        else:
            return out
