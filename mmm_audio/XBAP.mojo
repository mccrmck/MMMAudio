"""
Adds X Based Amplitude Panning algorithms.
"""
from std.math import sqrt, floor, cos, pi, sin
from std.sys import simd_width_of
from std.algorithm import vectorize


# struct SpeakerArray2D[num_speakers: Int, speaker_positions: InlineArray[MFloat[2], num_speakers], weights: InlineArray[Float64, num_speakers]](Movable, Copyable):
#     """
#     Defines an array of speakers of arbitrary length and positions. Defined at compile-time (cannot be dynamically changed).

#     Parameters: 
#         num_speakers: Number of Speakers in the Array as an Int
#         speaker_positions: An InlineArray of MFloat[2] defining the (x, y) positions of the speakers in meters.
#         weights: An InlineArray of Float64s defining speaker weights for DBAP.
#     """


#     def __init__(out self):
#         """
#         Initialize SpeakerArray.
#         """
#         pass
        


# struct SpeakerArrayAZ[](Movable, Copyable):
#     """
#     Defines an array of speakers of abitrary length and positions. Positions are given as tuples of (az, height) in radians where 0 is directly in front of the listener.
#     """
#     var speaker_positions: List[Tuple[Float64, Float64]]

#     def __init__(out self, speaker_positions: List[Tuple[Float64, Float64]]):

#         self.speaker_positions = speaker_positions.copy()

#         pass
            


        

@always_inline
def dbap2D[simd_out_size: Int = 4, num_speakers: Int = 4, speaker_pos: InlineArray[MFloat[2], num_speakers] = [MFloat[2](0, 0)], weights: MFloat[simd_out_size] = 0](sample: Float64, pos: MFloat[2], blur: Float64 = 0.1, rolloff: Float64 = 6) -> MFloat[simd_out_size]:
    """
    Implements DBAP (Distance Based Amplitude Panning). Takes in a mono signal and produces a signal of arbitrary channel size.

    Parameters:
        simd_out_size: Number of output signals. Must be a power of two that is at least as large as num_speakers.
        num_speakers: The number of speakers as an integer. Must be <= simd_out_size.
        speaker_pos: The speaker positions as an InlineArray of MFloat[2] x/y pairs in meters.
        weights:  An InlineArray of Float64s defining speaker weights for DBAP.

    Args:
        sample: Mono input sample.
        pos: X/Y position of the source in meters as an MFloat[2].
        blur: Blur between speakers. Values > 0 spread the source to more speakers.
        rolloff: The dB Rolloff (defaults to 6db).
    
    Returns:
        MFloat[simd_out_size]: The panned output sample for each speaker.
    """

   
    blur_sq = pow(blur, 2)
    # Calculates the a coefficient given a 6 db rolloff
    a = rolloff/6.02059991328

   # Set dists to 1.0 by default to avoid divide by 0 when calculating k
    dists : MFloat[simd_out_size] = 1.0

 
    # Calculates the k coefficient and gets distances for every speaker from the source
    for i in range(num_speakers):
        speaker = speaker_pos[i]
        weight = weights[i]
        xy = pow(speaker - pos, 2)
        # y = pow(speaker[1] - pos[1], 2)
        dists[i] = sqrt(xy.reduce_add() + blur_sq)
        
    

    k = 1/((weights * weights) / pow(dists, 2 * a)).reduce_add()

    # k: Float64 = 1/sum

    
    amps = (k * weights) / pow(dists, a) 
    amps *= sample

    return amps
   




# def dbap2D_test(input: Float64) raises:
#     assert_equal(inc(1.0), input)