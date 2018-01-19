//
//  ViewController.m
//  TestOneToManyConnection
//
//  Created by Thomas Hézard on 17/01/2018.
//  Copyright © 2018 THZ. All rights reserved.
//


#import "ViewController.h"
#import "AudioEngineManager.h"
#import "AUGenericStereoGenerator.h"
#import "AUGenericStereoToStereoFX.h"

@import Accelerate;


typedef struct SinOscillator {
    
    float       sampleRate;
    float       frequency;
    float       amplitude;
    float       phase;
    
} SinOscillator;



void testGenerator(void* contextRef, float** buffer, uint32_t numberFrames, bool* outputIsSilent) {
    
    SinOscillator* oscillator = (SinOscillator*)contextRef;
    
    float * buffer0 = buffer[0];
    float * buffer1 = buffer[1];
    float phase = oscillator->phase;
    float amplitude = oscillator->amplitude;
    float pi2 = 2.0f*M_PI;
    
    float phaseStep = pi2 * oscillator->frequency / oscillator->sampleRate;
    
    uint32_t i = numberFrames+1;
    while (--i) {
        *buffer0 = amplitude * sin(phase);
        *buffer1 = 0;
        phase += phaseStep;
        if (phase >= pi2) {
            phase -= pi2;
        }
        ++buffer0;
        ++buffer1;
    }
    
    oscillator->phase = phase;
    
    *outputIsSilent = false;
}


void testFX(void* contextRef, float** ibuffer, float** obuffer, uint32_t numberFrames, bool* outputIsSilent) {

    float * ibuffer0 = ibuffer[0];
    
    float * obuffer0 = obuffer[0];
    float * obuffer1 = obuffer[1];
    
    uint32_t i = numberFrames+1;
    while (--i) {
        *obuffer0 = 0;
        *obuffer1 = *ibuffer0;
        ++obuffer1; ++obuffer0; ++ibuffer0;
    }
    
    *outputIsSilent = false;
}



@interface ViewController ()

@property (nonatomic, strong)   AudioEngineManager *            audioEngineMgr;
@property (nonatomic, assign)   AudioComponentDescription       genericGeneratorAUDescription;
@property (nonatomic, assign)   AudioComponentDescription       genericStereoFXAUDescription;

@property (nonatomic, strong)   AVAudioMixerNode *              generalMixer;
@property (nonatomic, strong)   AVAudioMixerNode *              fxMixer;

@property (nonatomic, strong)   AVAudioNode *                   oscillator1;
@property (nonatomic, strong)   AUGenericStereoGenerator *      oscillator1AudioUnit;
@property (nonatomic, assign)   SinOscillator                   oscillator1Struct;
@property (nonatomic, strong)   AVAudioNode *                   oscillator2;
@property (nonatomic, strong)   AUGenericStereoGenerator *      oscillator2AudioUnit;
@property (nonatomic, assign)   SinOscillator                   oscillator2Struct;

@property (nonatomic, strong)   AVAudioNode *                   fxNode;
@property (nonatomic, strong)   AUGenericStereoToStereoFX *     fxAudioUnit;


@property (weak, nonatomic) IBOutlet UISwitch *fxSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *osc1MainSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *osc2MainSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *osc1FXSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *osc2FXSwitch;


@end



@implementation ViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        self.audioEngineMgr = [[AudioEngineManager alloc] initWithProcessingSampleRate:48000 sessionCategory:AVAudioSessionCategorySoloAmbient categoryOptions:0 andPreferredIOBufferDuration:0.05f];
        [self prepareAUDescriptions];
    });
    
    self.generalMixer = [[AVAudioMixerNode alloc] init];
    [self.audioEngineMgr attachNode:self.generalMixer];
    [self.audioEngineMgr connectNodeToMainMixer:self.generalMixer];
    
    self.fxMixer = [[AVAudioMixerNode alloc] init];
    [self.audioEngineMgr attachNode:self.fxMixer];
    
    _oscillator1Struct.amplitude    = 0.4f;
    _oscillator1Struct.sampleRate   = 48000.0f;
    _oscillator1Struct.frequency    = 440.0f;
    _oscillator1Struct.phase        = 0.0f;
    
    _oscillator2Struct.amplitude    = 0.2f;
    _oscillator2Struct.sampleRate   = 48000.0f;
    _oscillator2Struct.frequency    = 660.0f;
    _oscillator2Struct.phase        = 0.0f;
    
    
    [AVAudioUnit instantiateWithComponentDescription:self.genericStereoFXAUDescription options:0 completionHandler:^(__kindof AVAudioUnit * _Nullable fxNode, NSError * _Nullable error) {
        if (fxNode && error == nil) {
            self.fxNode = fxNode;
            self.fxAudioUnit = (AUGenericStereoToStereoFX*)fxNode.AUAudioUnit;
            self.fxAudioUnit.name = @"FX";
            self.fxAudioUnit.maximumFramesToRender = self.audioEngineMgr.maxFramesPerSlice;
            [self.fxAudioUnit linkExternalProcess:&testFX withContext:nil];
            [self.audioEngineMgr attachNode:fxNode];
            [self.audioEngineMgr.audioEngine connect:self.fxMixer to:fxNode fromBus:0 toBus:0 format:self.audioEngineMgr.processingFormat];
        }
    }];
    
    [AVAudioUnit instantiateWithComponentDescription:self.genericGeneratorAUDescription options:0 completionHandler:^(__kindof AVAudioUnit * _Nullable oscillatorNode, NSError * _Nullable error) {
        if (oscillatorNode && error == nil) {
            self.oscillator1 = oscillatorNode;
            self.oscillator1AudioUnit = (AUGenericStereoGenerator*)oscillatorNode.AUAudioUnit;
            self.oscillator1AudioUnit.name = @"Oscillator 1";
            self.oscillator1AudioUnit.maximumFramesToRender = self.audioEngineMgr.maxFramesPerSlice;
            [self.oscillator1AudioUnit linkExternalProcess:&testGenerator withContext:(void*)(&_oscillator1Struct)];
            [self.audioEngineMgr attachNode:oscillatorNode];
        }
    }];
    
    [AVAudioUnit instantiateWithComponentDescription:self.genericGeneratorAUDescription options:0 completionHandler:^(__kindof AVAudioUnit * _Nullable oscillatorNode, NSError * _Nullable error) {
        if (oscillatorNode && error == nil) {
            self.oscillator2 = oscillatorNode;
            self.oscillator2AudioUnit = (AUGenericStereoGenerator*)oscillatorNode.AUAudioUnit;
            self.oscillator2AudioUnit.name = @"Oscillator 2";
            self.oscillator2AudioUnit.maximumFramesToRender = self.audioEngineMgr.maxFramesPerSlice;
            [self.oscillator2AudioUnit linkExternalProcess:&testGenerator withContext:(void*)(&_oscillator2Struct)];
            [self.audioEngineMgr attachNode:oscillatorNode];
        }
    }];

    self.fxSwitch.on = NO;
    self.osc1MainSwitch.on = YES;
    self.osc2MainSwitch.on = YES;
    self.osc1FXSwitch.on = NO;
    self.osc2FXSwitch.on = NO;
    
    [self setFXActive:self.fxSwitch.on];
    [self connectNode:self.oscillator1 toGeneral:self.osc1MainSwitch.on andFX:self.osc1FXSwitch.on onBus:0];
    [self connectNode:self.oscillator2 toGeneral:self.osc2MainSwitch.on andFX:self.osc2FXSwitch.on onBus:1];
    
    [self.audioEngineMgr startAudioRenderingAndReturnError:nil];
    
}


- (void) prepareAUDescriptions {
    
    _genericGeneratorAUDescription.componentType = kAudioUnitType_Generator;
    _genericGeneratorAUDescription.componentManufacturer = 0x54485a20; // 'THZ '
    _genericGeneratorAUDescription.componentSubType = 0x47474155; // 'GGAU'
    _genericGeneratorAUDescription.componentFlags = 0;
    _genericGeneratorAUDescription.componentFlagsMask = 0;
    [AUAudioUnit registerSubclass:AUGenericStereoGenerator.self asComponentDescription:self.genericGeneratorAUDescription name:@"AUGenericStereoGenerator" version:1];
    
    _genericStereoFXAUDescription.componentType = kAudioUnitType_Effect;
    _genericStereoFXAUDescription.componentManufacturer = 0x54485a20; // 'THZ '
    _genericStereoFXAUDescription.componentSubType = 0x47535346; // 'GSSF'
    _genericStereoFXAUDescription.componentFlags = 0;
    _genericStereoFXAUDescription.componentFlagsMask = 0;
    [AUAudioUnit registerSubclass:AUGenericStereoToStereoFX.self asComponentDescription:self.genericStereoFXAUDescription name:@"AUGenericStereoToStereoFX" version:1];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void) setFXActive:(BOOL)active {
    
    if (active) {
        
        NSArray<AVAudioConnectionPoint*>* connectionPoints = [self.audioEngineMgr.audioEngine outputConnectionPointsForNode:self.fxNode outputBus:0];
        if (connectionPoints.count == 0) {
            [self.audioEngineMgr connectNodeToMainMixer:self.fxNode];
        } else if (connectionPoints.count == 1 && connectionPoints[0].node == self.audioEngineMgr.audioEngine.mainMixerNode) {
            return;
        } else {
            [self.audioEngineMgr.audioEngine disconnectNodeOutput:self.fxNode];
            [self.audioEngineMgr connectNodeToMainMixer:self.fxNode];
        }
        
    } else {
        [self.audioEngineMgr.audioEngine disconnectNodeOutput:self.fxNode];
    }
}

- (void) connectNode:(AVAudioNode*)node toGeneral:(BOOL)connectGeneral andFX:(BOOL)connectFX onBus:(AVAudioNodeBus)bus {
    
    if (!connectGeneral && !connectFX) {
        [self.audioEngineMgr.audioEngine disconnectNodeOutput:node];
        return;
    }
    
    AVAudioConnectionPoint *mainPoint = [[AVAudioConnectionPoint alloc] initWithNode:self.generalMixer bus:bus];
    AVAudioConnectionPoint *fxPoint = [[AVAudioConnectionPoint alloc] initWithNode:self.fxMixer bus:bus];
    NSArray<AVAudioConnectionPoint*> *array = nil;
    
    if (connectGeneral && connectFX) {
        array = [NSArray arrayWithObjects:mainPoint, fxPoint, nil];
    } else if (connectGeneral) {
        array = [NSArray arrayWithObjects:mainPoint, nil];
        if ([self.audioEngineMgr.audioEngine inputConnectionPointForNode:self.fxMixer inputBus:bus]) {
//            [self.audioEngineMgr.audioEngine disconnectNodeInput:self.fxMixer bus:bus];
            [self.audioEngineMgr.audioEngine disconnectNodeOutput:node];
        }
    } else {
        array = [NSArray arrayWithObjects:fxPoint, nil];
        if ([self.audioEngineMgr.audioEngine inputConnectionPointForNode:self.generalMixer inputBus:bus]) {
//            [self.audioEngineMgr.audioEngine disconnectNodeInput:self.generalMixer bus:bus];
            [self.audioEngineMgr.audioEngine disconnectNodeOutput:node];
        }
    }

    [self.audioEngineMgr.audioEngine connect:node toConnectionPoints:array fromBus:0 format:self.audioEngineMgr.processingFormat];
}


- (IBAction)onFXActiveChanged:(id)sender {
    UISwitch *senderSwitch = (UISwitch*)sender;
    [self setFXActive:senderSwitch.on];
}


- (IBAction)onOSCRoutingChanged:(id)sender {
    UISwitch *senderSwitch = (UISwitch*)sender;
    if (senderSwitch == self.osc1MainSwitch || senderSwitch == self.osc1FXSwitch) {
        [self connectNode:self.oscillator1 toGeneral:self.osc1MainSwitch.isOn andFX:self.osc1FXSwitch.isOn onBus:0];
    } else if (senderSwitch == self.osc2MainSwitch || senderSwitch == self.osc2FXSwitch) {
        [self connectNode:self.oscillator2 toGeneral:self.osc2MainSwitch.isOn andFX:self.osc2FXSwitch.isOn onBus:1];
    }
}




@end


