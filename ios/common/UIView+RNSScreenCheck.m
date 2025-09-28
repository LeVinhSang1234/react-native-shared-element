//
//  UIView+RNSScreenCheck.m
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 28/9/25.
//

#import "UIView+RNSScreenCheck.h"

@implementation UIView (RNSScreenCheck)

- (UIView *)rn_findRNSScreenAncestor {
  UIView *p = self;
  while (p) {
    if ([p isKindOfClass:NSClassFromString(@"RNSScreenView")]) {
      return p;
    }
    p = p.superview;
  }
  return nil;
}

- (BOOL)rn_isInSameRNSScreenWith:(UIView *)otherView {
  UIView *s1 = [self rn_findRNSScreenAncestor];
  UIView *s2 = [otherView rn_findRNSScreenAncestor];
  return (s1 && s1 == s2);
}

@end
