//
//  RCTVideoHelper.h
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 27/9/25.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RCTVideoHelper : NSObject

/// Tạo URL phát video (tự bật proxy + prefetch nếu là http/https)
+ (void)createVideoURL:(NSString *)source completion:(void (^)(NSURL *finalURL))completion;

/// Tạo URL poster (cache file 1 ngày nếu là http/https)
+ (nullable NSURL *)createPosterURL:(NSString *)source;

+ (void)applyMaxSizeCache:(NSUInteger)maxSizeMB;
@end

NS_ASSUME_NONNULL_END
