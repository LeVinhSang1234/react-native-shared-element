//
//  UIView+NearestVC.m
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 28/9/25.
//

#import "UIView+NearestVC.h"
@implementation UIView (NearestVC)
- (UIViewController *)nearestViewController {
  UIResponder *r = self;
  while (r) {
    if ([r isKindOfClass:[UIViewController class]]) return (UIViewController *)r;
    r = r.nextResponder;
  }
  return nil;
}
@end
