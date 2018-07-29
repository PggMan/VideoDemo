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
@property (nonatomic ,weak)  AVCaptureDeviceInput *input;
@property (nonatomic ,weak)  AVCaptureOutput *output;
@property (nonatomic ,assign) AVCaptureDevicePosition curPosition;

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
#pragma mark - 采集初始信息
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
    _curPosition = AVCaptureDevicePositionFront;
    
    AVCaptureDevice *device = [self cameroWithPosition:_curPosition];
    
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
         _input = input;
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
    _output = output;
    
    [self setConnection:output];
    
}

-(void)setConnection:(AVCaptureVideoDataOutput *)output{
    // 桥接
    AVCaptureConnection *connection = [output connectionWithMediaType:AVMediaTypeVideo];
    connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    
    // 解决前置摄像头左右成像问题:(当前是前置摄像头 则启动镜子反射效果)
    if (_curPosition == AVCaptureDevicePositionUnspecified || _curPosition == AVCaptureDevicePositionFront) {
        connection.videoMirrored = YES;
    } else {
        connection.videoMirrored = NO;
    }

}


- (void)addPreviewLayer{
    
    // 预览layer
    AVCaptureVideoPreviewLayer *previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    [self.view.layer addSublayer:previewLayer];
    _previewLayer = previewLayer;
    
}

#pragma mark - 图片处理
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


#pragma mark - 摄像头切换
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    
    
    if (self.input) {
        //1 若当前是前置摄像头，则需新设后摄像头，反之，亦如此。
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            
            AVCaptureDevicePosition position  = (self.input.device.position == AVCaptureDevicePositionFront) ? AVCaptureDevicePositionBack :AVCaptureDevicePositionFront;
            _curPosition = position;
            
            // 获取摄像头设备(前置 或者 后置 依据传入的 AVCaptureDevicePosition 而定)
            AVCaptureDevice *device = [self cameroWithPosition:position];
            
  
            NSError *error;
            AVCaptureDeviceInput *newInput =  [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
            
            if(newInput) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    CATransition *rotaionAnim = [CATransition animation];
                    rotaionAnim.type = @"oglFlip";
                    rotaionAnim.subtype = @"fromLeft";
                    rotaionAnim.duration = 0.5;
                    [self.view.layer addAnimation:rotaionAnim forKey:nil];
                    
                    
                    [self.session beginConfiguration];
                    // 重设输入源
                    [self.session removeInput:self.input];
                    self.input = newInput;
                    [self.session addInput:newInput];
                    
                    // 重设输出源
                    [self.session removeOutput:self.output];
                    [self addCaptureDeviceOutput:device];
                    
                    [self.session commitConfiguration];
                });
                
            } else {
                NSLog(@"%@", error);
                return;
            }
        });
    }
    
    
}

- (AVCaptureDevice *)cameroWithPosition:(AVCaptureDevicePosition)position{
    
   
        if (@available(iOS 10.0, *)) {
            AVCaptureDeviceDiscoverySession *dissession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInDuoCamera,AVCaptureDeviceTypeBuiltInTelephotoCamera,AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:position];
            for (AVCaptureDevice *device in dissession.devices) {
                if ([device position] == position ) {
                    return device;
                }
            }
        } else {
            NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
            for (AVCaptureDevice *device in devices) {
                if ([device position] == position) {
                    return device;
                }
            }
        }
    return nil;
}



@end
