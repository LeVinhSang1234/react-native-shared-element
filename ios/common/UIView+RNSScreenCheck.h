//
//  UIView+RNSScreenCheck.h
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 28/9/25.
//

#import "UIKit/UIKit.h"

@interface UIView (RNSScreenCheck)
- (UIView *)rn_findRNSScreenAncestor;
- (BOOL)rn_isInSameRNSScreenWith:(UIView *)otherView;
@end
