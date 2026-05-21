from mmm_python import *

mmm_audio = MMMAudio(
    in_device='default',
    out_device='default',
    blocksize=128, 
    graph_name="SubtractiveTemplate",
    package_name="workshop_templates"
    )

mmm_audio.start_audio()

mmm_audio.send_float("freq", 80)
mmm_audio.send_float("ffreq", 1500)
mmm_audio.send_float("res", 0.99)
mmm_audio.send_float("lfo_freq", 2)

mmm_audio.send_float("fold_amt", 0.3)

mmm_audio.stop_audio()