//
//  ViewController.m
//  VideoDemo
//
//  Created by 印度阿三 on 2018/7/23.
//  Copyright © 2018年 印度阿三. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>
/** 必须进行强引用*/
@property (nonatomic ,strong)  AVCaptureSession *session;
@property (nonatomic ,weak)  AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic ,weak) UIImageView *imageView;
@end

@implementation ViewController

- (UIImageView *)imageView{
    if (!_imageView) {
        UIImageView  *imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
        [self.view addSubview:imageView];
        _imageView = imageView;
    }
    
    return _imageView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    //1 创建回话
    AVCaptureSession *session = [self addCaptureSession];
    //2 获取音视频设备
    AVCaptureDevice *device   = [self addCaptureDevice:session];
    //3 输入设备
    [self addCaptureDeviceInput:device];
    //4 输出设备
    [self addCaptureDeviceOutput:device];
    //start
    [session startRunning];
    
}
- (AVCaptureSession *)addCaptureSession{
    
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    /**
     AVCaptureSessionPresetHigh :
     [默认值] 高分辨率，会根据当前设备进行自适应
     */
    session.sessionPreset = AVCaptureSessionPresetHigh;
    _session = session;
    
    return session;
}

- (AVCaptureDevice *)addCaptureDevice:(AVCaptureSession *)session{
    
    //2 创建Device
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    if ([device lockForConfiguration:nil]) {
        //自动闪光灯，
        if ([device isFlashModeSupported:AVCaptureFlashModeAuto]) {
            [device setFlashMode:AVCaptureFlashModeAuto];
        }
        
        // 帧率 1秒10帧
        device.activeVideoMinFrameDuration = CMTimeMake(1, 10);
        
        
        //自动白平衡,
        if ([device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
            [device setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
        }
        [device unlockForConfiguration];
    }
    
    return device;
}

- (void)addCaptureDeviceInput:(AVCaptureDevice *)device{
    
    //3 创建输入源并添加到回话中
    NSError *error;
    AVCaptureDeviceInput *input =  [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    
    if(input) {
        [_session addInput:input];
    } else {
        NSLog(@"%@", error);
        return;
    }
}


- (void)addCaptureDeviceOutput:(AVCaptureDevice *)device{
    
    //4 创建输出源并添加到回话中
    //output
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    [_session addOutput:output];
    
    //4.1 设置输出代理
    dispatch_queue_t queue = dispatch_queue_create("LinXunFengSerialQueue", DISPATCH_QUEUE_SERIAL);
    
    [output setSampleBufferDelegate:self queue:queue];
    
    //4.2 输出信息设置
    // kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange 输出格式和范围
    // kCVPixelBufferPixelFormatTypeKey 指定像素输出格式
    NSDictionary* setcapSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange], kCVPixelBufferPixelFormatTypeKey,
                                    nil];
    output.videoSettings = setcapSettings;
    //4.2 获取输入与输出之间的连接 设置
    [self setConnection:output];
    
}

-(void)setConnection:(AVCaptureVideoDataOutput *)output{
    // 桥接
    AVCaptureConnection *connection = [output connectionWithMediaType:AVMediaTypeVideo];
    connection.videoOrientation = AVCaptureVideoOrientationPortrait;
}


- (void)addPreviewLayer{
    
    // 预览layer
    AVCaptureVideoPreviewLayer *previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    [self.view.layer addSublayer:previewLayer];
    _previewLayer = previewLayer;
    
}

// 代理
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    // captureSession 会话如果没有强引用，这里不会得到执行
    
    // 获取图片帧数据
    // 为媒体数据设置一个CMSampleBuffer的Core Video图像缓存对象
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    UIImage *image;
    if (@available(iOS 9.0, *)) {
        
        CIImage *ciImage = [CIImage imageWithCVImageBuffer:imageBuffer];
        image = [UIImage imageWithCIImage:ciImage];
    } else {
        image = [self imageFromSampleBuffer:imageBuffer];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageView.image = image;
    });
}
// iOS9.0 图片处理
-(UIImage *)imageFromSampleBuffer:(CVImageBufferRef)imageBuffer{
    
    
    // 锁定pixel buffer的基地址
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    // 得到pixel buffer的基地址
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    // 得到pixel buffer的行字节数
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // 得到pixel buffer的宽和高
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    // 创建一个依赖于设备的RGB颜色空间
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    // 用抽样缓存的数据创建一个位图格式的图形上下文（graphics context）对象
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // 根据这个位图context中的像素数据创建一个Quartz image对象
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // 解锁pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    // 释放context和颜色空间
    CGContextRelease(context); CGColorSpaceRelease(colorSpace);
    // 用Quartz image创建一个UIImage对象image
    UIImage *image = [UIImage imageWithCGImage:quartzImage scale:1 orientation:UIImageOrientationUp];
    // 释放Quartz image对象
    CGImageRelease(quartzImage);
    return (image);
}


@end
