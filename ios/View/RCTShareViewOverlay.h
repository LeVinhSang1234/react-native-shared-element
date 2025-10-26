//
//  RCTShareViewOverlay.h
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 2/10/25.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@interface RCTShareViewOverlay : UIView
@property (nonatomic, assign) double sharingAnimatedDuration;

- (void)applySharingAnimatedDuration:(double)sharingAnimatedDuration;

- (void)moveToOverlay:(CGRect)fromFrame
          targetFrame:(CGRect)toFrame
             fromView:(UIView *)fromView
               toView:(UIView *)toView
             willMove:(nonnull void (^)(void))willMove
             onTarget:(nonnull void (^)(void))onTarget
          onCompleted:(nonnull void (^)(void))onCompleted;

- (void)unmount;

@end
NS_ASSUME_NONNULL_END
