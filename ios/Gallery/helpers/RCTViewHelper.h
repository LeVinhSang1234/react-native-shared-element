//
//  RCTViewHelper.h
//  GalleryPicker
//
//  Created by Sang Le vinh on 10/30/25.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RCTViewHelper : NSObject

/// Lấy window đang hiển thị (multi-scene an toàn)
+ (UIWindow * _Nullable)getTargetWindow;

/// Lấy frame của chính view trong toạ độ RNSScreen (ổn định, không phụ thuộc animation)
+ (CGRect)frameInScreenStable:(UIView *)view;

@end

NS_ASSUME_NONNULL_END

