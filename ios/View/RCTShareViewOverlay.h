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
           tagetFrame:(CGRect)toFrame
             willMove:(void (^)(void))willMove
             onTarget:(void (^)(void))onTarget
          onCompleted:(void (^)(void))onCompleted;

- (void)unmount;

@end
NS_ASSUME_NONNULL_END
