//
//  LicensePlateRecognitionWrapper.h
//  LPRDemo
//
//  Created by kennen on 2024/1/4.
//

#import <Foundation/Foundation.h>
#import <opencv2/opencv2.h>
#import <hyperlpr3/hyper_lpr_sdk.h>

NS_ASSUME_NONNULL_BEGIN

@interface LicensePlateRecognitionWrapper : NSObject

- (instancetype)initWithModelPath:(NSString *)modelPath;

- (void)processImage:(UIImage *)image
           completion:(void (^)(NSString *code, NSString *type, CGFloat text_confidence))completion;

@end

NS_ASSUME_NONNULL_END
