//
//  AudioEngineManager.m
//  iOSMusicGamingAudioEngine
//
//  Created by Thomas Hézard on 06/12/2017.
//  Copyright © 2017 THZ. All rights reserved.
//



#import <AVFoundation/AVFoundation.h>

#import "AudioEngineManager.h"


@interface AudioEngineManager()

@property (nonatomic, strong)       AVAudioSession *                audioSession;
@property (nonatomic, strong)       NSString *                      sessionCategory;
@property (nonatomic, assign)       AVAudioSessionCategoryOptions   sessionCategoryOptions;

@property (nonatomic, strong)       AVAudioFormat *                 processingFormat;
@property (nonatomic, assign)       AVAudioFrameCount               maxFramesPerSlice;
@property (nonatomic, assign)       NSTimeInterval                  preferredIOBufferDuration;

@property (nonatomic, strong)       AVAudioEngine *                 audioEngine;
@property (nonatomic, strong)       AVAudioMixerNode *              mainMixer;

@property (nonatomic, assign)       BOOL                            isSessionInterrupted;
@property (nonatomic, assign)       BOOL                            isEngineStarted;

@end



@implementation AudioEngineManager


- (instancetype _Nullable) initWithProcessingSampleRate:(double)sampleRate
                                        sessionCategory:(NSString*)category
                                        categoryOptions:(AVAudioSessionCategoryOptions)options
                           andPreferredIOBufferDuration:(NSTimeInterval)ioBufferDuration {
    
    self = [super init];
    if (self) {
        self.preferredIOBufferDuration = ioBufferDuration;
        self.sessionCategory = category;
        self.sessionCategoryOptions = options;
        
        self.processingFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:sampleRate channels:2 interleaved:NO];
        self.maxFramesPerSlice = 4096;
        
        self.audioSession = [AVAudioSession sharedInstance];
        [self setupAudioSession];
        
        self.audioEngine = [[AVAudioEngine alloc] init];
        self.mainMixer = self.audioEngine.mainMixerNode;
        [self setupAudioEngine];
        
        [self registerForNotifications];
    }
    
#ifdef DEBUG
    NSLog(@"Number of output channels = %ld", (long)self.audioSession.outputNumberOfChannels);
#endif
    return self;
}

- (void)registerForNotifications {
    
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self selector:@selector(handleInterruption:) name:AVAudioSessionInterruptionNotification object:self.audioSession];
    [notificationCenter addObserver:self selector:@selector(handleMediaServicesReset:) name:AVAudioSessionMediaServicesWereResetNotification object:self.audioSession];
    [notificationCenter addObserver:self selector:@selector(handleConfigurationChange:) name:AVAudioEngineConfigurationChangeNotification object:self.audioEngine];
}

- (void)unregisterNotifications {
    
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self name:AVAudioSessionInterruptionNotification object:self.audioSession];
    [notificationCenter removeObserver:self name:AVAudioSessionMediaServicesWereResetNotification object:self.audioSession];
    [notificationCenter removeObserver:self name:AVAudioEngineConfigurationChangeNotification object:self.audioEngine];
}


#pragma mark AVAudioSession

- (void) setupAudioSession {
    
    if (self.audioSession) {
        [self.audioSession setCategory:self.sessionCategory withOptions:self.sessionCategoryOptions error:nil];
        [self.audioSession setPreferredSampleRate:self.processingFormat.sampleRate error:nil];
        [self.audioSession setPreferredIOBufferDuration:_preferredIOBufferDuration error:nil];
    }
}

- (void)handleInterruption:(NSNotification *)notification {
    
    UInt8 theInterruptionType = [[notification.userInfo valueForKey:AVAudioSessionInterruptionTypeKey] intValue];
    
#ifdef DEBUG
    NSLog(@"Session interrupted > --- %s ---\n", theInterruptionType == AVAudioSessionInterruptionTypeBegan ? "Begin Interruption" : "End Interruption");
#endif
    
    if (theInterruptionType == AVAudioSessionInterruptionTypeBegan) {
        [self.audioEngine stop];
        self.isSessionInterrupted = YES;
    }
    else if (theInterruptionType == AVAudioSessionInterruptionTypeEnded) {
        self.isSessionInterrupted = NO;
        // make sure to activate the session
        NSError *error;
        if (self.isEngineStarted) {
            [self internalStartAudioRenderingAndReturnError:&error];
            if (error) {
                NSLog(@"Restart rendering failed with error: %@", [error localizedDescription]);
                return;
            }
        }
    }
}

- (void)handleMediaServicesReset:(NSNotification *)notification {
    // if we've received this notification, the media server has been reset
    // re-wire all the connections and start the engine
#ifdef DEBUG
    NSLog(@"Media services have been reset!");
    NSLog(@"Re-wiring connections and starting once again");
#endif
    
    BOOL wasRendering = self.audioEngine.running;
    [self.audioEngine stop];
    [self resetAudioRendering];
    [self unregisterNotifications];
    [self registerForNotifications];
    if (wasRendering) {
        [self internalStartAudioRenderingAndReturnError:nil];
    }
}


#pragma mark AVAudioEngine

- (void) setupAudioEngine {
    
    AudioUnitSetProperty(self.audioEngine.outputNode.audioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &_maxFramesPerSlice, sizeof(_maxFramesPerSlice));
}


- (void) attachNode:(AVAudioNode*_Nonnull)node {
    
    [self.audioEngine attachNode:node];
}


- (void) connectNodeToMainMixer:(AVAudioNode*_Nonnull)node {
    
    [self.audioEngine connect:node to:self.mainMixer format:self.processingFormat];
}


- (BOOL)isRunning {
    
    return self.audioEngine ? self.audioEngine.isRunning : NO;
}


- (void) startAudioRenderingAndReturnError:(NSError**)error {
    
    if (self.audioEngine) {
        self.isEngineStarted = YES;
        if (!self.isSessionInterrupted) {
            [self internalStartAudioRenderingAndReturnError:error];
        }
    }
}


- (void) internalStartAudioRenderingAndReturnError:(NSError**)error {

    bool success = [self.audioSession setActive:YES error:error];
    if (!success) {
        return;
    }
    [self.audioEngine prepare];
    [self.audioEngine startAndReturnError:error];
}


- (void) stopAudioRendering {
    
    if (self.audioEngine) {
        [self.audioEngine stop];
        [self.audioEngine reset];
        self.isEngineStarted = NO;
    }
}


- (void) resetAudioRendering {
    
    if (self.audioEngine) {
        BOOL wasRendering = self.audioEngine.running;
        [self.audioEngine stop];
        [self setupAudioSession];
        [self setupAudioEngine];
        [self.audioEngine reset];
        if (wasRendering) {
            [self internalStartAudioRenderingAndReturnError:nil];
        }
    }
}


- (void) handleConfigurationChange:(NSNotification *)notification {
// we do nothing, the default outputNode deals automatically with channel layout conversion if output is mono
#ifdef DEBUG
    NSLog(@"Received a configuration notification. Sample Rate = %f ", self.audioSession.sampleRate);
    NSLog(@"Inputs : %ld - %@ ", (long)self.audioSession.inputNumberOfChannels, self.audioSession.currentRoute.inputs);
    NSLog(@"Outputs : %ld - %@ ", (long)self.audioSession.outputNumberOfChannels, self.audioSession.currentRoute.outputs);
#endif
    if (!self.isSessionInterrupted && self.isEngineStarted) {
        [self internalStartAudioRenderingAndReturnError:nil];
    }
}


@end
