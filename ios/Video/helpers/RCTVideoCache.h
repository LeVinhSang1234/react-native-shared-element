//
//  RCTVideoCache.h
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 27/9/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface RCTVideoCache : NSObject

+ (void)VC_StartProxy;
+ (void)VC_ConfigureCache:(NSUInteger)maxSizeMB;
+ (void)VC_PrefetchHead:(NSURL *) url seconds:(double) seconds bitratebps:(double) bitratebps;
+ (NSURL *)proxyURLWithOriginalURL:(NSURL *)url;

@end
NS_ASSUME_NONNULL_END
