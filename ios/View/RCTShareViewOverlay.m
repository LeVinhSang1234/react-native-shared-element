//
//  RCTShareViewOverlay.m
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 2/10/25.
//

static const double kDefaultSharingDuration   = 0.35;   // seconds

#import "RCTShareViewOverlay.h"

@implementation RCTShareViewOverlay

- (instancetype)init {
  if(self = [super init]) {
  }
  return self;
}

- (void)applySharingAnimatedDuration:(double)durationMs {
  double duration = (durationMs <= 0) ? kDefaultSharingDuration : durationMs / 1000.0;
  if (duration != _sharingAnimatedDuration) {
    _sharingAnimatedDuration = duration;
  }
}
- (void)moveToOverlay:(CGRect)fromFrame
           tagetFrame:(CGRect)toFrame
             willMove:(nonnull void (^)(void))willMove
             onTarget:(nonnull void (^)(void))onTarget
          onCompleted:(nonnull void (^)(void))onCompleted {
}

- (void)unmount {
}

@end
