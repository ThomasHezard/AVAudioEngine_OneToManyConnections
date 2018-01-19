# Test One-To-Many Connections

This project has been built to test AVAudioEngine's one-to-many connections made dynamically between custom AUAudioUnits.


## Demonstration

Compile and run on iOS device.
Then play with the switches.
After a few switches, you should encounter audio bugs (weird click sounds) of even crash.


## Explanations

All functions of interests for the connections are directly inside ViewController.

The Graph is built with custom AUAudioUnit according to the scheme below.
To make the demonstration as simple and illustrative as possible, we implemented the following :
  - Oscillator 1 and 2 sends sine waves to channel 0 (left side), so General Mixer outputs only on the left side.
  - FX Process simply peformes a copy from channel 0 to channel 1 (with channel 0 mute), so FX Process outputs only on the right side.

The buttons on the interface lets you connect / disconnect the nodes as following :
  - FX ON => connection (5)
  - OSC1 to Main => connection (1)
  - OSC2 to Main => connection (2)
  - OSC1 to FX => connection (3)
  - OSC2 to FX => connection (4)


![image error](http://thz.fr/sd45zef543/TestOneToManyConnections_Graph.png "AVAudioNodes connections scheme")


## Other tests performed

- We tried to stop and restart the audio engine when changing a connection (stopping at the beginning and starting at the end of functions setFXActive: and connectNode:toGeneral:andFX:onBus:). It seems to avoid crashes and some errors, but audio bugs are still here.
- We tried to use the function disconnectNodeInput:bus: instead of disconnectNodeOutput: at lines 248 and 254, but it doesn't seem to work, as the new conneciton is refused in that case.


## Questions

- Are we supposed not to touch the connections after starting the engine? It doesn't seem so in the documentation.
- Is there an error in my implementation of my AUAudioUnits?
- What can I do to make it work?
