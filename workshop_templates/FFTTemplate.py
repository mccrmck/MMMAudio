from mmm_python import *

mmm_audio = MMMAudio(
    in_device='default',
    out_device='default',
    blocksize=128, 
    graph_name="FFTTemplate",
    package_name="workshop_templates"
    )

mmm_audio.start_audio()

# send some parameters to Python here. For example:
# mmm_audio.send_float("my_parameter", 0.5)

mmm_audio.stop_audio()