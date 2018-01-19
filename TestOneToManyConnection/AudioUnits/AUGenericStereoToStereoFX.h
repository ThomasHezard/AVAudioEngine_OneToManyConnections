//
//  AUGenericStereoToStereoFX.h
//  iOSMusicGamingAudioEngine
//
//  Created by Thomas Hézard on 11/12/2017.
//  Copyright © 2017 THZ. All rights reserved.
//


#import <AVFoundation/AVFoundation.h>


/* AUGenericStereoToStereoFX
   *************************
 
 AUGenericStereoToStereoFX is designed to host any processing module (accessed with C-function) inside an AudioUnit.
 The processing module will be called with float, stereo, non-interleaved buffers in both input an output.
 SampleRate will depend on the connexion's format.
 
 CAUTION : AUGenericStereoToStereoFX does not perform sample rate conversion, therefore, input and output connexion must have same sample rate.
           Plus, the processing sample rate should be set before connexion, to avoid the connexion to be rejected.
 
 How to use :
 - Instantiate an AUGenericStereoToStereoFX, set the processing sample rate, and plug it to your AUGraph / AVAudioEngine.
 - Link your existing process with the link function. The process function will be called at each execution of the unit's render block.
 - The void* context can be nil.
 
 Integration in AVAudioEngine :
 
 1. Declare the AudioUnit :
   AudioComponentDescription description;
   description = kAudioUnitType_Effect;
   description = 0x54485a20; // 'THZ '
   description = 0x47535346; // 'GSSF'
   description = 0;
   description = 0;
   [AUAudioUnit registerSubclass:AUGenericStereoToStereoFX.self asComponentDescription:description name:@"AUGenericStereoToStereoFX" version:1];
 
 2. Instantiate an AVAudioUnit wrapping an AUGenericStereoGenerator :
   [AVAudioUnit instantiateWithComponentDescription:description options:0 completionHandler:^(__kindof AVAudioUnit * _Nullable newNode, NSError * _Nullable error) {
     if (newNode && error == nil) {
       // save / plug the node etc.
     }
   }];
 
 */


typedef void (*StereoToStereoFXProcess)(void* contextRef, float** iBuffer, float **oBuffer, uint32_t numberFrames, bool* outputIsSilent);


@interface AUGenericStereoToStereoFX : AUAudioUnit

@property (nonatomic, strong)   NSString *      name;       // | free for use if needed
@property (nonatomic, assign)   NSUInteger      identifier; // | 

- (void) setProcessingSampleRate:(double)sampleRate;

- (void) linkExternalProcess:(StereoToStereoFXProcess)process withContext:(void*)context;

@end
