//
//  AUGenericStereoGenerator.m
//  iOSMusicGamingAudioEngine
//
//  Created by Thomas Hézard on 08/12/2017.
//  Copyright © 2017 THZ. All rights reserved.
//



#import "AUGenericStereoGenerator.h"



@interface AUGenericStereoGenerator()

@property (nonatomic, strong)       AVAudioFormat *             processingFormat;
@property (nonatomic, strong)       AVAudioPCMBuffer *          internalAVBuffer;
@property (nonatomic, strong)       AUAudioUnitBus *            outputBus;
@property (nonatomic, strong)       AUAudioUnitBusArray *       outputBusArray;
@property (nonatomic, assign)       BOOL                        loading;

@end



@implementation AUGenericStereoGenerator {
    
    StereoGeneratorProcess      _processFunction;
    void *                      _contextRef;
    
    bool                        _rendering;
    float **                    _internalBuffer;
    float **                    _processingBuffer;
}


- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription
                                       error:(NSError * _Nullable __autoreleasing *)outError {
    
    return [self initWithComponentDescription:componentDescription options:0 error:outError];
}


- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription
                                     options:(AudioComponentInstantiationOptions)options
                                       error:(NSError * _Nullable __autoreleasing *)outError {
    
    self = [super initWithComponentDescription:componentDescription options:options error:outError];
    
    if (self) {
        
        // default format
        self.maximumFramesToRender = 4096;
        self.processingFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:48000 channels:2 interleaved:NO];
        
        self.outputBus = [[AUAudioUnitBus alloc] initWithFormat:self.processingFormat error:outError];
        self.outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self
                                                                     busType:AUAudioUnitBusTypeOutput
                                                                      busses:@[self.outputBus]];
        
        _processingBuffer = (float**)calloc(2, sizeof(float*));
    }
    
    return self;
}


- (void) dealloc {
    free(_processingBuffer);
}


- (AUAudioUnitBusArray *)outputBusses {
    return _outputBusArray;
}


- (BOOL) setOutputFormat:(AVAudioFormat*)format error:(NSError**)error {
    
    // works only with standard format for now
    if (format.commonFormat != AVAudioPCMFormatFloat32 || format.interleaved == YES || format.channelCount != 2) {
        return NO;
    }
    
    self.processingFormat = format;
    
    return YES;
}


- (BOOL)shouldChangeToFormat:(AVAudioFormat *)format forBus:(AUAudioUnitBus *)bus {
    
    if (self.renderResourcesAllocated || bus != _outputBus) {
        return NO;
    }
    
    NSError *error = nil;
    return [self setOutputFormat:format error:&error];
}


- (BOOL)allocateRenderResourcesAndReturnError:(NSError * _Nullable __autoreleasing *)outError {
    
    BOOL result = [super allocateRenderResourcesAndReturnError:outError];
    
    if (!result) {
        return NO;
    }
    
    self.internalAVBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:self.processingFormat frameCapacity:self.maximumFramesToRender];
    _internalBuffer = (float**)self.internalAVBuffer.floatChannelData;
    
    return YES;
}


- (void)deallocateRenderResources {
    [super deallocateRenderResources];
    _internalBuffer = NULL;
    self.internalAVBuffer = nil;
}


- (AUInternalRenderBlock)internalRenderBlock {
    
    return ^AUAudioUnitStatus(
                              AudioUnitRenderActionFlags *actionFlags,
                              const AudioTimeStamp       *timestamp,
                              AVAudioFrameCount           frameCount,
                              NSInteger                   outputBusNumber,
                              AudioBufferList            *outputData,
                              const AURenderEvent        *realtimeEventListHead,
                              AURenderPullInputBlock      pullInputBlock) {
        
        _rendering = true;
        
        // Check outputData buffer allocation
        UInt32 byteSize =  frameCount * sizeof(float);
        uint32_t numberFrames = (uint32_t)frameCount;
        bool wrapBuffer = false;
        for (uint32_t i = 0; i<2; ++i) {
            outputData->mBuffers[i].mNumberChannels = 1;
            outputData->mBuffers[i].mDataByteSize = byteSize;
            if (outputData->mBuffers[i].mData == NULL) {
                outputData->mBuffers[i].mData = _internalBuffer[0];
            } else {
                wrapBuffer = true;
            }
        }
        
        _processingBuffer[0] = wrapBuffer ? (float*)outputData->mBuffers[0].mData : _internalBuffer[0];
        _processingBuffer[1] = wrapBuffer ? (float*)outputData->mBuffers[1].mData : _internalBuffer[1];
        
        // Procesing internal function
        bool outputIsSilent = true;
        if (_processFunction) {
            _processFunction(_contextRef, _processingBuffer, numberFrames, &outputIsSilent);
        } else {
            memset(_processingBuffer[0], 0, frameCount*sizeof(float));
            memset(_processingBuffer[1], 0, frameCount*sizeof(float));
        }
        
        if (outputIsSilent) {
            *actionFlags |= kAudioUnitRenderAction_OutputIsSilence;
        }
        
        _rendering = false;
        
        return noErr;
    };
}


- (void) linkExternalProcess:(StereoGeneratorProcess)process withContext:(void *)context {
    if (process) {
        _processFunction = process;
        _contextRef = context;
    }
}


@end
