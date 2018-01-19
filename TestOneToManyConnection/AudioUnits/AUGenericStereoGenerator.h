//
//  AUGenericStereoGenerator.h
//  iOSMusicGamingAudioEngine
//
//  Created by Thomas Hézard on 08/12/2017.
//  Copyright © 2017 THZ. All rights reserved.
//


#import <AVFoundation/AVFoundation.h>


/* AUGenericStereoGenerator
   ************************
 
 AUGenericStereoGenerator is designed to host any generative process (accessed with C-function) inside an AudioUnit.
 The generative process will be called to fill a float, stereo, non-interleaved buffer.
 SampleRate will depend on the connexion's format.
 
 How to use :
 - Instantiate an AUGenericStereoGenerator and plug it to your AUGraph / AVAudioEngine.
 - Link your existing process with the link function. The process function will be called at each execution of the unit's render block.
 - The void* context can be nil.
 
 Integration in AVAudioEngine :
 
 1. Declare the AudioUnit :
    AudioComponentDescription description;
    description = kAudioUnitType_Generator;
    description = 0x54485a20; // 'THZ '
    description = 0x47474155; // 'GGAU'
    description = 0;
    description = 0;
    [AUAudioUnit registerSubclass:AUGenericStereoGenerator.self asComponentDescription:description name:@"AUGenericStereoGenerator" version:1];
 
 2. Instantiate an AVAudioUnit wrapping an AUGenericStereoGenerator :
    [AVAudioUnit instantiateWithComponentDescription:description options:0 completionHandler:^(__kindof AVAudioUnit * _Nullable newNode, NSError * _Nullable error) {
    if (newNode && error == nil) {
        // save / plug the node etc.
    }
    }];
 
*/


typedef void (*StereoGeneratorProcess)(void* contextRef, float** buffer, uint32_t numberFrames, bool* outputIsSilent);


@interface AUGenericStereoGenerator : AUAudioUnit

@property (nonatomic, strong)   NSString *      name;       // | free for use if needed
@property (nonatomic, assign)   NSUInteger      identifier; // |

- (void) linkExternalProcess:(StereoGeneratorProcess)process withContext:(void*)context;

@end
