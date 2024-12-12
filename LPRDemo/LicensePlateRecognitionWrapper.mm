//
//  LicensePlateRecognitionWrapper.m
//  LPRDemo
//
//  Created by kennen on 2024/1/4.
//

#import "LicensePlateRecognitionWrapper.h"

cv::Mat UIImageToMat(UIImage *image) {
    CGImageRef cgImage = [image CGImage];
    
    CGDataProviderRef dataProvider = CGImageGetDataProvider(cgImage);
    CFDataRef data = CGDataProviderCopyData(dataProvider);
    
    const UInt8 *buffer = CFDataGetBytePtr(data);
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    size_t bitsPerComponent = CGImageGetBitsPerComponent(cgImage);
    size_t bitsPerPixel = CGImageGetBitsPerPixel(cgImage);
    size_t bytesPerRow = CGImageGetBytesPerRow(cgImage);
    
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(cgImage);
    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(cgImage);
    
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    if (alphaInfo == kCGImageAlphaNone) {
        bitmapInfo |= kCGImageAlphaNone;
    } else if (alphaInfo == kCGImageAlphaPremultipliedFirst || alphaInfo == kCGImageAlphaPremultipliedLast) {
        bitmapInfo |= kCGImageAlphaPremultipliedFirst;
    } else if (alphaInfo == kCGImageAlphaFirst || alphaInfo == kCGImageAlphaLast) {
        bitmapInfo |= kCGImageAlphaFirst;
    }
    
    cv::Mat mat(height, width, CV_8UC4, (void*)buffer, bytesPerRow);
    cv::cvtColor(mat, mat, cv::COLOR_RGBA2BGR); // If your model expects BGR format
    
    CFRelease(data);
    
    return mat;
}


static const std::vector<std::string> TYPES = {"蓝牌", "黄牌单层", "白牌单层", "绿牌新能源", "黑牌港澳", "香港单层", "香港双层", "澳门单层", "澳门双层", "黄牌双层"};


@implementation LicensePlateRecognitionWrapper {
    P_HLPR_Context ctx;
}

- (instancetype)initWithModelPath:(NSString *)modelPath {
    self = [super init];
    if (self) {
        // Convert NSString to C string
        const char *modelPathC = [modelPath UTF8String];
        
        // Configure license plate recognition parameters
        HLPR_ContextConfiguration configuration = {0};
        configuration.models_path = (char *)modelPathC;
        configuration.max_num = 5;
        configuration.det_level = DETECT_LEVEL_LOW;
        configuration.use_half = false;
        configuration.nms_threshold = 0.5f;
        configuration.rec_confidence_threshold = 0.5f;
        configuration.box_conf_threshold = 0.30f;
        configuration.threads = 1;

        // 识别速度降低，提高识别精度 这样配置试试
        /*
        configuration.models_path = (char *) modelPathC;
        configuration.max_num = 1;
        configuration.det_level = DETECT_LEVEL_HIGH;
        configuration.use_half = false;
        configuration.nms_threshold = 0.85f;
        configuration.rec_confidence_threshold = 0.95f;
        configuration.box_conf_threshold = 0.50f;
        configuration.threads = 1;
        */
        
        // Instantiate the license plate recognition context
        ctx = HLPR_CreateContext(&configuration);
        
        // Query the instantiation status
        HREESULT ret = HLPR_ContextQueryStatus(ctx);
        if (ret != HResultCode::Ok) {
            NSLog(@"Error creating context.");
            return nil;
        }
    }
    return self;
}

- (void)processImage:(UIImage *)image
           completion:(void (^)(NSString *code, NSString *type, CGFloat text_confidence))completion {
    // Convert UIImage to cv::Mat
    cv::Mat cvImage = UIImageToMat(image);
    
    
    // Create ImageData
    HLPR_ImageData data = {0};
    data.data = cvImage.ptr<uint8_t>(0);
    data.width = cvImage.cols;
    data.height = cvImage.rows;
    data.format = STREAM_BGR;
    // TODO: 这个参数需要根据图片方向调整
    data.rotation = CAMERA_ROTATION_0;
    
    // Create DataBuffer
    P_HLPR_DataBuffer buffer = HLPR_CreateDataBuffer(&data);
    
    // Perform license plate recognition
    HLPR_PlateResultList results;
    HLPR_ContextUpdateStream(ctx, buffer, &results);
    
    for (int i = 0; i < results.plate_size; ++i) {
        // Parse and print the recognition results
        NSString *type;
        if (results.plates[i].type == HLPR_PlateType::PLATE_TYPE_UNKNOWN) {
            type = @"未知";
        } else {
            // Ensure the index is within bounds before accessing TYPES
            if (results.plates[i].type >= 0 && results.plates[i].type < TYPES.size()) {
                // Convert std::string to NSString
                type = [NSString stringWithUTF8String:TYPES[results.plates[i].type].c_str()];
            } else {
                type = @"未知";
            }
        }
        
        NSLog(@"<%d> %@, %s, %f", i + 1, type,
              results.plates[i].code, results.plates[i].text_confidence);
        if (results.plates[i].text_confidence > 0.95) {
                    // If confidence is greater than 0.9, execute the completion block
                    if (completion) {
                        completion([NSString stringWithUTF8String:results.plates[i].code],
                                   type,
                                   results.plates[i].text_confidence);
                    }
                }
    }
    
    // Release DataBuffer
    HLPR_ReleaseDataBuffer(buffer);
}

- (void)dealloc {
    // Release Context
    HLPR_ReleaseContext(ctx);
}

@end
