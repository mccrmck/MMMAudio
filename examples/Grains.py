"""
Demonstrates granular synthesis using TGrains, using a mouse to control granular playback.

Left and right moves around in the buffer. Up and down controls rate of triggers.
"""

from mmm_python import *
mmm_audio = MMMAudio(128, num_output_channels = 8, graph_name="Grains", package_name="examples")
mmm_audio.start_audio() 

# for Wayland use the fake mouse
MMMAudio.fake_mouse()

# with a user defined env, the shape of the grain envelope can be customized
mmm_audio.send_floats("times", [0.01, 0.2])
mmm_audio.send_floats("values", [0.0, 1.0, 0.0])
mmm_audio.send_floats("curves", [8])

# this will increase the trig rate, but there won't be enough grains
# so increase the number of grains
mmm_audio.send_float("max_trig_rate", 80.0) 
mmm_audio.send_int("set_num_grains", 40)

mmm_audio.stop_audio()

# the below version is the same except it uses a custom grain with a BandPass filter embedded directly in the grain

from mmm_python import *
mmm_audio = MMMAudio(128, num_output_channels = 2, graph_name="Grains_Custom", package_name="examples")
mmm_audio.start_audio() 

mmm_audio.send_floats("times", [0.01, 0.9])

MMMAudio.get_audio_devices()

dbamp(-120)