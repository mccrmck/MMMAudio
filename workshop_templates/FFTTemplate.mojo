from mmm_audio import *

comptime windowsize: Int = 1024
comptime hopsize: Int = windowsize // 4

struct WorkshopFFTWindow(FFTProcessable):
    var world: World
    var m: Messenger

    def next_frame(mut self, mut magnitudes: List[Float64], mut phases: List[Float64]) -> None:
        # do something to the magnitudes and phases here (remove "pass")
        pass

    def __init__(out self, world: World):
        self.world = world
        self.m = Messenger(self.world)
    
    def get_messages(mut self) -> None:
        # get messages from Python here. For example:
        # self.m.update(self.my_parameter, "my_parameter")
        # (remove "pass")
        pass

struct FFTTemplate(Movable, Copyable):
    var world: World
    var buffer: Buffer
    var playBuf: Play
    var fft_process: FFTProcess[WorkshopFFTWindow]
    
    def __init__(out self, world: World):
        self.world = world
        self.buffer = Buffer.load("resources/Shiverer.wav")
        self.playBuf = Play(self.world) 
        self.fft_process = FFTProcess[WorkshopFFTWindow](
            world=self.world,
            process=WorkshopFFTWindow(self.world),
            window_size=windowsize,
            hop_size=hopsize
            )
        
    def next(mut self) -> SIMD[DType.float64,2]:
        input = self.playBuf.next(self.buffer)  # Read samples from the buffer
        out = self.fft_process.next(input)
        return out