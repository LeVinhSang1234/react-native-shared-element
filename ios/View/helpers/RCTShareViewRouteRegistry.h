//
//  RCTShareViewRouteRegistry.h
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 1/10/25.
//

#import <Foundation/Foundation.h>

@class RCTShareView;

NS_ASSUME_NONNULL_BEGIN

@interface RCTShareViewRouteRegistry : NSObject

+ (void)registerView:(RCTShareView *)view tag:(NSString *)tag;
+ (void)unregisterView:(RCTShareView *)view tag:(NSString *)tag;
+ (nullable RCTShareView *)resolveViewForTag:(NSString *)tag exclude:(RCTShareView *)excludeView;

@end

NS_ASSUME_NONNULL_END
