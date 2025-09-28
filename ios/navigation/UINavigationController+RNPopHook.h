//
//  UINavigationController+RNPopHook.h
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 28/9/25.
//

#import <UIKit/UIKit.h>

@interface UINavigationController (RNPopHook)
// Gọi 1 lần để bật hook (swizzle popViewControllerAnimated:)
+ (void)rn_enablePopHookOnce;
@end
