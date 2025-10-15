//
//  VideoThumbnail.m
//  ReactNativeSharedElement
//
//  Created by Sang Le vinh on 10/15/25.
//

#import "VideoThumbnail.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@implementation VideoThumbnail

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:(const facebook::react::ObjCTurboModule::InitParams &)params {
  return std::make_shared<facebook::react::NativeVideoThumbnailSpecJSI>(params);
}

- (void)getThumbnail:(NSString *)url
              timeMs:(double)timeMs
             resolve:(RCTPromiseResolveBlock)resolve
              reject:(RCTPromiseRejectBlock)reject {
  @try {
    NSURL *videoURL = [NSURL URLWithString:url];
    if (!videoURL) {
      reject(@"INVALID_URL", @"Invalid video URL", nil);
      return;
    }
    
    AVAsset *asset = [AVAsset assetWithURL:videoURL];
    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    generator.appliesPreferredTrackTransform = YES;
    generator.requestedTimeToleranceAfter = kCMTimeZero;
    generator.requestedTimeToleranceBefore = kCMTimeZero;
    generator.maximumSize = CGSizeMake(160, 0);
    
    CMTime time = CMTimeMakeWithSeconds(timeMs / 1000.0, 600);
    NSError *error = nil;
    CMTime actualTime;
    CGImageRef imageRef = [generator copyCGImageAtTime:time actualTime:&actualTime error:&error];
    
    if (error || imageRef == nil) {
      reject(@"THUMBNAIL_ERROR", @"Cannot extract frame", error);
      return;
    }
    
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    NSData *jpegData = UIImageJPEGRepresentation(image, 0.7);
    if (!jpegData) {
      reject(@"ENCODE_ERROR", @"Failed to encode thumbnail", nil);
      return;
    }
    
    NSString *base64 = [jpegData base64EncodedStringWithOptions:0];
    NSString *dataUri = [NSString stringWithFormat:@"data:image/jpeg;base64,%@", base64];
    resolve(dataUri);
  }
  @catch (NSException *exception) {
    reject(@"THUMBNAIL_EXCEPTION", exception.reason, nil);
  }
}

+ (NSString *)moduleName
{
  return @"VideoThumbnail";
}
@end

