//
//  ViewController.m
//  KinFu-ios
//
//  Created by  沈江洋 on 2019/1/11.
//  Copyright © 2019  沈江洋. All rights reserved.
//

#import "ViewController.h"

#import "MetalContext.h"
#import "MetalView.h"
#import "TextureRenderer.h"
#import "MathUtilities.hpp"
#import "FusionProcessor.h"

#import "VideoRenderer.h"
#import "DepthRenderer.h"
#import "FrontCamera.h"


@interface ViewController () <FrontCameraDelegate, MetalViewDelegate, NSStreamDelegate>
{
    BOOL m_isStreaming;
    uint32_t m_streamFrameIndex;
    
    BOOL m_isFusionComplete;
    int m_fusionFrameIndex;
}

@property (nonatomic, strong) MetalContext *metalContext;
@property (nonatomic, strong) MetalView *mainMetalView0;
@property (nonatomic, strong) MetalView *mainMetalView1;
@property (nonatomic, strong) MetalView *mainMetalView2;
@property (nonatomic, strong) VideoRenderer *videoRenderer;
@property (nonatomic, strong) DepthRenderer *depthRenderer;

@property (nonatomic, strong) FrontCamera *trueDepthCamera;

@property (nonatomic, strong) NSString *documentDirectory;
@property (nonatomic, strong) NSOutputStream *videoOutputStream;
@property (nonatomic, strong) NSString *videoOutputPath;
@property (nonatomic, strong) NSOutputStream *depthOutputStream;
@property (nonatomic, strong) NSString *depthOutputPath;

@property (nonatomic, strong) TextureRenderer *scanningRenderer;
@property (nonatomic, strong) FusionProcessor *fusionProcessor;
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) NSString *streamPath;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
//    [self addObserver];
    
    CGRect frameRect = self.view.frame;
    CGRect frameRect0 = CGRectMake(0, 0, frameRect.size.width / 2, frameRect.size.height / 2);
    self.mainMetalView0 = [[MetalView alloc] initWithFrame: frameRect0];
    [self.view addSubview: self.mainMetalView0];
    self.mainMetalView0.delegate = self;
    CGRect frameRect1 = CGRectMake(frameRect.size.width / 2, 0, frameRect.size.width / 2, frameRect.size.height / 2);
    self.mainMetalView1 = [[MetalView alloc] initWithFrame: frameRect1];
    [self.view addSubview: self.mainMetalView1];
    self.mainMetalView1.delegate = self;
    
    //For viewing the scanned image
//    CGRect frameRect2 = CGRectMake(frameRect.size.width, 0, frameRect.size.width, frameRect.size.height);
//    self.mainMetalView2 = [[MetalView alloc] initWithFrame: frameRect2];
//    [self.view addSubview: self.mainMetalView2];
//    self.mainMetalView2.delegate = self;
    
    self.mainMetalView2=[[MetalView alloc] init];
    self.mainMetalView2.frame=CGRectMake(0, 0, 375, 500);
    [self.view addSubview:self.mainMetalView2];
    
    self.metalContext = [MetalContext shareMetalContext];
    
    self.videoRenderer = [[VideoRenderer alloc] initWithLayer: _mainMetalView0.metalLayer andContext: _metalContext];
    self.depthRenderer = [[DepthRenderer alloc] initWithLayer: _mainMetalView1.metalLayer andContext: _metalContext];
    
    self.scanningRenderer=[[TextureRenderer alloc] initWithLayer: _mainMetalView2.metalLayer andContext: _metalContext];
    
    self.trueDepthCamera=[[FrontCamera alloc] initWithDepthTag: YES];
    self.trueDepthCamera.delegate=self;
    
    self.fusionProcessor = [FusionProcessor shareFusionProcessorWithContext: _metalContext];
    [self.fusionProcessor setRenderBackColor: {24.0 / 255, 31.0 / 255, 50.0 / 255, 1}];
    simd::float4 cube = {-107.080887, -96.241348, -566.015991, 223.474106};
    [self.fusionProcessor setupTsdfParameterWithCube: cube];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    self.documentDirectory = [paths objectAtIndex:0];
    self.videoOutputPath=[self.documentDirectory stringByAppendingPathComponent:@"bgra.bin"];
    self.depthOutputPath=[self.documentDirectory stringByAppendingPathComponent:@"depth.bin"];
    [self.stopStreamButton setEnabled: NO];
    
    
    NSString * filePath = [[NSBundle mainBundle] pathForResource:@"depth"
                                                          ofType:@"bin"];
    NSLog(@"\n\nthe string %@",filePath);
    self.streamPath = filePath;
    
//    NSString *resourcepath = [[NSBundle mainBundle] resourcePath];
//    self.streamPath = [resourcepath stringByAppendingString:@"/depth5.bin"];
}

- (void)addObserver
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)willResignActive
{
    [self.trueDepthCamera stopCapture];
}

- (void)didBecomeActive
{
    [self.trueDepthCamera startCapture];
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear: animated];
    
    m_fusionFrameIndex = 0;
    m_isFusionComplete = NO;
    
    
    [self.trueDepthCamera startCapture];
//    [self setUpStreamForFile: self.streamPath];
}

//FrontCameraDelegate
- (void) didOutputVideoBuffer:(CVPixelBufferRef)videoPixelBuffer andDepthBuffer:(CVPixelBufferRef)depthPixelBuffer
{
    if(videoPixelBuffer)
    {
        [_videoRenderer render: videoPixelBuffer];
    }
    if(depthPixelBuffer)
    {
        [_depthRenderer render: depthPixelBuffer];
    }
    if(m_isStreaming)
    {
        [self streamDepthforSavingInput:depthPixelBuffer andVideo:videoPixelBuffer];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onStartStream:(id)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.startStreamButton setEnabled: NO];
        [self.stopStreamButton setEnabled: YES];
    });
    
    NSLog(@"onStartStream");
//    [self.trueDepthCamera startCapture];
    self.videoOutputStream=[[NSOutputStream alloc] initToFileAtPath:self.videoOutputPath append:NO];
//    [self.videoOutputStream setDelegate:self];
    [self.videoOutputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.videoOutputStream open];
    
    
    self.depthOutputStream=[[NSOutputStream alloc] initToFileAtPath:self.depthOutputPath append:NO];
//    [self.depthOutputStream setDelegate:self];
    [self.depthOutputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.depthOutputStream open];
    
//    [self.trueDepthCamera startCapture];
    
    m_streamFrameIndex=0;
    m_isStreaming=YES;
}

- (IBAction)onStopStream:(id)sender {
    NSLog(@"onStopStream");
    NSLog(@"total Frame: %d", m_streamFrameIndex);
    m_isStreaming = NO;
    
//    [self.trueDepthCamera stopCapture];
    
    [self.videoOutputStream close];
    [self.depthOutputStream close];
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.startStreamButton setEnabled: YES];
        [self.stopStreamButton setEnabled: NO];
    });
}

-(void)streamDepthforSavingInput: (CVPixelBufferRef) depthPixelBuffer andVideo: (CVPixelBufferRef) videoPixelBuffer
        {

    if(!depthPixelBuffer||!videoPixelBuffer){
        return;
    }
            
            
    NSLog(@"streaming frameIndex: %d", m_streamFrameIndex);

    CVPixelBufferLockBaseAddress(videoPixelBuffer, 0);
    CVPixelBufferLockBaseAddress(depthPixelBuffer, 0);

    // mark nan depth as -1.0
    size_t width=CVPixelBufferGetWidth(videoPixelBuffer);
    size_t height=CVPixelBufferGetHeight(videoPixelBuffer);
    void *depthBaseAddress=CVPixelBufferGetBaseAddress(depthPixelBuffer);
    float16_t *depthFloat16Buffer = (float16_t *)(depthBaseAddress);
    for(int j=0;j<height;++j){
        for(int i=0;i<width;++i){
            float16_t disparity=depthFloat16Buffer[width*j+i];
            if(!disparity==disparity){
                depthFloat16Buffer[width*j+i]=-1.0;
            }
        }
    }
    //streaming
    void *videoBaseAddress=CVPixelBufferGetBaseAddress(videoPixelBuffer);
    uint8_t *videoInt8Buffer=(uint8_t *)(videoBaseAddress);
    [self.videoOutputStream write:videoInt8Buffer maxLength:4*width*height];

    uint8_t *depthInt8Buffer = (uint8_t *)(depthBaseAddress);
    [self.depthOutputStream write: depthInt8Buffer maxLength: 2 * width * height];

    m_streamFrameIndex++;
    NSLog(@"streaming frameIndex: %d", m_streamFrameIndex);
    CVPixelBufferUnlockBaseAddress(videoPixelBuffer, 0);
    CVPixelBufferUnlockBaseAddress(depthPixelBuffer, 0);

    if(m_streamFrameIndex > 255)
    {
        [self onStopStream: nil];
    }
}


- (void)setUpStreamForFile:(NSString *)path {
    // iStream is NSInputStream instance variable
    self.inputStream = [[NSInputStream alloc] initWithFileAtPath:path];
    [self.inputStream setDelegate:self];
    [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                forMode:NSDefaultRunLoopMode];
    [self.inputStream open];
}


- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode {
    switch(eventCode) {
        case NSStreamEventHasBytesAvailable:
        {
            //read every frame from depth.bin, which contains one single disparity frame of 640 x 480 x float16,
            //we can easily derive depth from disparity: depth = 1.0 / disparity;
            int frameLen = PORTRAIT_WIDTH * PORTRAIT_HEIGHT * 2;
            uint8_t* buf = new uint8_t[frameLen];
            unsigned int len = 0;
            len = [(NSInputStream *)stream read:buf maxLength:frameLen];
            if(len == frameLen)
            {
                BOOL isFusionOK = [self.fusionProcessor processDisparityData:buf withIndex:m_fusionFrameIndex withTsdfUpdate: YES];
                if(isFusionOK)
                {
                    id<MTLTexture> textureAfterFusion=[self.fusionProcessor getColorTexture];
                    [self.scanningRenderer render: textureAfterFusion];
                    m_fusionFrameIndex++;
                }
                else
                {
                    NSLog(@"Fusion Failed");
                }
            }
            delete buf;
            break;
        }
        default:
            if(m_fusionFrameIndex > 0)
            {
                m_isFusionComplete = YES;
            }
    }
}

- (IBAction)onResetScan:(id)sender {
//    [self.startStreamButton setEnabled: NO];
    [self setUpStreamForFile: self.depthOutputPath];
    NSLog(@"When pressed Reset Scan Button: %d", m_fusionFrameIndex);
    if(m_isFusionComplete)
    {
        m_fusionFrameIndex = 0;
        m_isFusionComplete = NO;
        simd::float4 cube = {-107.080887, -96.241348, -566.015991, 223.474106};
        [self.fusionProcessor setupTsdfParameterWithCube: cube];
        [self setUpStreamForFile: self.depthOutputPath];
    }
//    [self.startStreamButton setEnabled: YES];
}

@end
