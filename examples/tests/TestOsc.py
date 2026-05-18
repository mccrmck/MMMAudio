from mmm_python import *

# instantiate and load the graph
m_s = []

MMMAudio.compile(graph_name="TestOsc", package_name="examples.tests")

for i in range(1):
    mmm_audio = MMMAudio(512, graph_name="TestOsc", package_name="examples.tests")
    mmm_audio.start_audio() 
    m_s.append(mmm_audio)

for i in range(1):
    m_s[i].stop_audio()  