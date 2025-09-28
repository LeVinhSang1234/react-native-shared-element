//
//  RNEarlyRegistry.h
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 28/9/25.
//

#import <UIKit/UIKit.h>
@interface RNEarlyRegistry : NSObject
+ (instancetype)shared;
- (void)addView:(UIView *)v;
- (void)removeView:(UIView *)v;
- (void)notifyNav;
@end
