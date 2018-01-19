//
//  AudioEngineManager.h
//  iOSMusicGamingAudioEngine
//
//  Created by Thomas Hézard on 06/12/2017.
//  Copyright © 2017 THZ. All rights reserved.
//



#import <AVFoundation/AVFoundation.h>



@interface AudioEngineManager : NSObject

@property (nonatomic, strong, readonly)     AVAudioEngine * _Nonnull                audioEngine;
@property (nonatomic, strong, readonly)     AVAudioFormat * _Nullable               processingFormat;
@property (nonatomic, assign, readonly)     AVAudioFrameCount                       maxFramesPerSlice;

- (instancetype _Nullable) initWithProcessingSampleRate:(double)sampleRate
                                        sessionCategory:(NSString*_Nonnull)category
                                        categoryOptions:(AVAudioSessionCategoryOptions)options
                           andPreferredIOBufferDuration:(NSTimeInterval)ioBufferDuration;

- (void) attachNode:(AVAudioNode*_Nonnull)node;
- (void) connectNodeToMainMixer:(AVAudioNode*_Nonnull)node;

@property (nonatomic, assign, readonly)     BOOL        isRunning;
- (void) startAudioRenderingAndReturnError:(NSError* _Nullable *_Nullable)error;
- (void) stopAudioRendering;
- (void) resetAudioRendering;

@end
