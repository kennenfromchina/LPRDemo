#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "LicensePlateRecognitionWrapper.h"

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) UIButton *cameraButton;

- (void)startCameraPreview:(id)sender;
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@property (nonatomic, strong) LicensePlateRecognitionWrapper *wrapper;
@property (nonatomic, strong) UIImage* image;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // 初始化 AVCaptureSession
    self.captureSession = [[AVCaptureSession alloc] init];
    
    // 设置相机设备
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    
    if (videoInput) {
        [self.captureSession addInput:videoInput];
        
        // 设置视频输出
        self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        [self.videoDataOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
        NSDictionary *settings = @{ (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA) };
        [self.videoDataOutput setVideoSettings:settings];
        
        if ([self.captureSession canAddOutput:self.videoDataOutput]) {
            [self.captureSession addOutput:self.videoDataOutput];
            // Initialize AVCaptureVideoPreviewLayer and add it to the view
            dispatch_async(dispatch_get_main_queue(), ^{
                self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
                self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
                self.previewLayer.frame = self.view.bounds;
                [self.view.layer insertSublayer:self.previewLayer atIndex:0];
                
                
                // Disable the button to prevent starting multiple sessions
            });
        }
        
        
    } else {
        NSLog(@"Error setting up video input: %@", error.localizedDescription);
    }
    
    // Add a button to the view
    self.cameraButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.cameraButton setTitle:@"Start Camera" forState:UIControlStateNormal];
    [self.cameraButton addTarget:self action:@selector(startCameraPreview:) forControlEvents:UIControlEventTouchUpInside];
    self.cameraButton.frame = CGRectMake(0, 0, 120, 40);
    self.cameraButton.center = self.view.center;
    [self.view addSubview:self.cameraButton];
    NSString *modelFolderPath = [[NSBundle mainBundle] resourcePath];
    self.wrapper = [[LicensePlateRecognitionWrapper alloc] initWithModelPath:modelFolderPath];
}

- (void)startCameraPreview:(id)sender {
    // 启动相机
    [self.captureSession startRunning];
    self.cameraButton.enabled = NO;
}


- (BOOL)isCameraAccessGranted {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status == AVAuthorizationStatusAuthorized) {
        return YES;
    } else if (status == AVAuthorizationStatusDenied || status == AVAuthorizationStatusRestricted) {
        // Handle access denied or restricted
        return NO;
    } else {
        // Request camera access
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            if (!granted) {
                // Handle access not granted
            }
        }];
        return NO;
    }
}

- (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst);
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    UIImage *capturedImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    return capturedImage;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    UIImage *capturedImage = [self imageFromSampleBuffer:sampleBuffer];
    
    
    if (capturedImage) {
        [self.wrapper processImage:capturedImage completion:^(NSString * _Nonnull code, NSString * _Nonnull type, CGFloat text_confidence) {
            NSLog(@"%@ %@ %.6f", code, type, text_confidence);
            [self.captureSession stopRunning];
            self.cameraButton.enabled = YES;
        }];
    }
    
}



@end
