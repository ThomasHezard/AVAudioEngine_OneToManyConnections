//
//  AUGenericStereoToStereoFX.m
//  iOSMusicGamingAudioEngine
//
//  Created by Thomas Hézard on 11/12/2017.
//  Copyright © 2017 THZ. All rights reserved.
//

#import "AUGenericStereoToStereoFX.h"



@interface AUGenericStereoToStereoFX()

@property (nonatomic, strong)       AVAudioFormat *             processingFormat;
@property (nonatomic, strong)       AVAudioPCMBuffer *          outputAVBuffer;
@property (nonatomic, strong)       AUAudioUnitBus *            outputBus;
@property (nonatomic, strong)       AUAudioUnitBusArray *       outputBusArray;
@property (nonatomic, strong)       AVAudioPCMBuffer *          inputAVBuffer;
@property (nonatomic, strong)       AUAudioUnitBus *            inputBus;
@property (nonatomic, strong)       AUAudioUnitBusArray *       inputBusArray;
@property (nonatomic, assign)       BOOL                        loading;


@end



@implementation AUGenericStereoToStereoFX {
    
    StereoToStereoFXProcess     _processFunction;
    void *                      _contextRef;
    
    bool                        _rendering;
    
    AudioBufferList *           _inputOriginalABL;
    AudioBufferList *           _inputMutableABL;
    
    AudioBufferList *           _outputOriginalABL;
    
    float **                    _processingInputBuffer;
    float **                    _processingOutputBuffer;
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
        
        self.inputBus = [[AUAudioUnitBus alloc] initWithFormat:self.processingFormat error:outError];
        self.inputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self
                                                                    busType:AUAudioUnitBusTypeInput
                                                                     busses:@[self.inputBus]];
        
        _processingInputBuffer = (float**)calloc(2, sizeof(float*));
        _processingOutputBuffer = (float**)calloc(2, sizeof(float*));
    }
    
    return self;
}


- (void) dealloc {
    
    if (_processingInputBuffer) free(_processingInputBuffer);
    if (_processingOutputBuffer) free(_processingOutputBuffer);
}


- (AUAudioUnitBusArray *)outputBusses {
    return _outputBusArray;
}


- (AUAudioUnitBusArray *)inputBusses {
    return _inputBusArray;
}


- (void)setProcessingSampleRate:(double)sampleRate {
    
    if (self.renderResourcesAllocated || self.processingFormat.sampleRate == sampleRate) {
        return;
    }
    
    self.processingFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:sampleRate channels:2 interleaved:NO];
    [self.outputBus setFormat:self.processingFormat error:nil];
    [self.inputBus setFormat:self.processingFormat error:nil];
}


- (BOOL) setOutputFormat:(AVAudioFormat*)format error:(NSError**)error {
    
    // works only with standard format for now
    if (format.commonFormat != AVAudioPCMFormatFloat32 || format.interleaved == YES || format.channelCount != 2 || format.sampleRate != self.processingFormat.sampleRate) {
        return NO;
    }
    
    return YES;
}


- (BOOL) setInputFormat:(AVAudioFormat*)format error:(NSError**)error {
    
    // works only with standard format for now
    if (format.commonFormat != AVAudioPCMFormatFloat32 || format.interleaved == YES || format.channelCount != 2 || format.sampleRate != self.processingFormat.sampleRate) {
        return NO;
    }
    
    return YES;
}


- (BOOL)shouldChangeToFormat:(AVAudioFormat *)format forBus:(AUAudioUnitBus *)bus {
    
    if (self.renderResourcesAllocated) {
        return NO;
    }
    
    if (bus == _outputBus) {
        NSError *error = nil;
        return [self setOutputFormat:format error:&error];
    }
    
    if (bus == _inputBus) {
        NSError *error = nil;
        return [self setOutputFormat:format error:&error];
    }
    
    return NO;
}


- (BOOL)allocateRenderResourcesAndReturnError:(NSError * _Nullable __autoreleasing *)outError {
    
    BOOL result = [super allocateRenderResourcesAndReturnError:outError];
    
    if (!result) {
        return NO;
    }
    
    self.inputAVBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:self.processingFormat frameCapacity:self.maximumFramesToRender];
    _inputOriginalABL = (AudioBufferList*)self.inputAVBuffer.audioBufferList;
    _inputMutableABL = self.inputAVBuffer.mutableAudioBufferList;
    
    self.outputAVBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:self.processingFormat frameCapacity:self.maximumFramesToRender];
    _outputOriginalABL = (AudioBufferList*)self.outputAVBuffer.audioBufferList;
    
    return YES;
}


- (void)deallocateRenderResources {
    
    self.outputAVBuffer = nil;
    _outputOriginalABL = nil;
    self.inputAVBuffer = nil;
    _inputOriginalABL = nil;
    _inputMutableABL = nil;
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
        
        // ********** Pulling Input **********
        
        // Prepare input ABL
        UInt32 byteSize =  frameCount * sizeof(float);
        for (uint32_t i = 0; i<2; ++i) {
            _inputMutableABL->mBuffers[i].mNumberChannels = 1;
            _inputMutableABL->mBuffers[i].mDataByteSize = byteSize;
            _inputMutableABL->mBuffers[i].mData = _inputOriginalABL->mBuffers[i].mData;
        }
        
        // Pulling input
        AUAudioUnitStatus inputStatus = pullInputBlock(actionFlags, timestamp, frameCount, 0, _inputMutableABL);
        if (inputStatus) {
            return inputStatus;
        }
        
        _processingInputBuffer[0] = _inputMutableABL->mBuffers[0].mData;
        _processingInputBuffer[1] = _inputMutableABL->mBuffers[1].mData;
        
        // ********** Processing **********
        
        // Check outputData buffer allocation
        byteSize =  frameCount * sizeof(float);
        uint32_t numberFrames = (uint32_t)frameCount;
        bool wrapBuffer = false;
        for (uint32_t i = 0; i<2; ++i) {
            outputData->mBuffers[i].mNumberChannels = 1;
            outputData->mBuffers[i].mDataByteSize = byteSize;
            if (outputData->mBuffers[i].mData == NULL) {
                outputData->mBuffers[i].mData = _outputOriginalABL->mBuffers[i].mData;
            } else {
                wrapBuffer = true;
            }
        }
        
        _processingOutputBuffer[0] = wrapBuffer ? (float*)outputData->mBuffers[0].mData : _outputOriginalABL->mBuffers[0].mData;
        _processingOutputBuffer[1] = wrapBuffer ? (float*)outputData->mBuffers[1].mData : _outputOriginalABL->mBuffers[1].mData;
        
        // Procesing internal function
        bool outputIsSilent = true;
        if (_processFunction) {
            _processFunction(_contextRef, _processingInputBuffer, _processingOutputBuffer, numberFrames, &outputIsSilent);
        } else {
            memset(_processingOutputBuffer[0], 0, frameCount*sizeof(float));
            memset(_processingOutputBuffer[1], 0, frameCount*sizeof(float));
        }
        
        if (outputIsSilent) {
            *actionFlags |= kAudioUnitRenderAction_OutputIsSilence;
        }
        
        _rendering = false;
        return noErr;
    };
}


- (void) linkExternalProcess:(StereoToStereoFXProcess)process withContext:(void*)context {
    if (process) {
        _processFunction = process;
        _contextRef = context;
    }
}


@end
