//
//  RCTVideoRouteRegistry.h
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 28/9/25.
//

#import <Foundation/Foundation.h>

@class RCTVideoView;

NS_ASSUME_NONNULL_BEGIN

@interface RCTVideoRouteRegistry : NSObject

+ (void)registerView:(RCTVideoView *)view tag:(NSString *)tag;
+ (void)unregisterView:(RCTVideoView *)view tag:(NSString *)tag;
+ (nullable RCTVideoView *)resolveViewForTag:(NSString *)tag exclude:(RCTVideoView *)excludeView;

@end

NS_ASSUME_NONNULL_END
