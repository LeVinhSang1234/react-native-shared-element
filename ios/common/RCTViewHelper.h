//
//  RCTViewHelper.h
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 2/10/25.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RCTViewHelper : NSObject
/// Lấy frame của chính view trong toạ độ RNSScreen (ổn định, không phụ thuộc animation)
+ (CGRect)frameInScreenStable:(UIView *)view;

/// Lấy window đang hiển thị (multi-scene an toàn)
+ (UIWindow * _Nullable)getTargetWindow;

+ (nullable UIViewController *)getRootViewController;

+ (UIInterfaceOrientation)currentInterfaceOrientation;

@end

NS_ASSUME_NONNULL_END
