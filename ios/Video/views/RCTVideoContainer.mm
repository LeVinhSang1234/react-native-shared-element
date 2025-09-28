//
//  RCTVideoContainer.m
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 27/9/25.
//

#import "RCTVideoContainer.h"
#import <AVFoundation/AVFoundation.h>
#import <React/RCTViewComponentView.h>

@implementation RCTVideoContainer

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    self.userInteractionEnabled = YES;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.clipsToBounds = YES;
  }
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  for (CALayer *layer in self.layer.sublayers) {
    if ([layer isKindOfClass:[AVPlayerLayer class]]) {
      layer.frame = self.bounds;
    }
  }
}
@end
