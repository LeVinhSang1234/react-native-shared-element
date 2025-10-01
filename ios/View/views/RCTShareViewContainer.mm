//
//  RCTShareViewContainer.m
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 1/10/25.
//

#import "RCTShareViewContainer.h"
#import <React/RCTViewComponentView.h>

@implementation RCTShareViewContainer

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    self.userInteractionEnabled = YES;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.clipsToBounds = YES;
  }
  return self;
}
@end
