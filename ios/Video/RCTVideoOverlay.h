//
//  RCTVideoOverlay.h
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 28/9/25.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AVKit/AVKit.h"

@class RCTVideoView;

NS_ASSUME_NONNULL_BEGIN
@interface RCTVideoOverlay : UIView
@property (nonatomic, assign) double sharingAnimatedDuration;

- (void)applySharingAnimatedDuration:(double)sharingAnimatedDuration;

- (void)moveToOverlay:(CGRect)fromFrame
           tagetFrame:(CGRect)toFrame
          playerLayer:(AVPlayerLayer *)playerLayer
          fromBgColor:(UIColor *)fromBgColor
            toBgColor:(UIColor *)toBgColor
             willMove:(void (^)(void))willMove
             onTarget:(void (^)(void))onTarget
          onCompleted:(void (^)(void))onCompleted;

- (void)unmount;

@end
NS_ASSUME_NONNULL_END
