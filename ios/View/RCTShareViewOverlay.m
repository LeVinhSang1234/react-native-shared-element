//
//  RCTShareViewOverlay.m
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 2/10/25.
//

static const double kDefaultSharingDuration   = 0.35;
static const double kDefaultCompletionDelay   = 0.15;

#import "RCTShareViewOverlay.h"
#import "RCTViewHelper.h"

@interface RCTShareViewOverlay ()

@property (nonatomic, strong, nullable) UIView *overlayContainer;
@property (nonatomic, strong, nullable) UIView *ghostView;
@property (nonatomic, weak,   nullable) UIView *originalView;

@property (nonatomic, strong) NSMapTable<UIView *, UIView *> *ghostCache;

@end

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
          targetFrame:(CGRect)toFrame
             fromView:(UIView *)fromView
               toView:(UIView *)toView
             willMove:(nonnull void (^)(void))willMove
             onTarget:(nonnull void (^)(void))onTarget
          onCompleted:(nonnull void (^)(void))onCompleted
{
  UIWindow *win = [RCTViewHelper getTargetWindow];
  if (!win || (!fromView.subviews.count || !toView.subviews.count)) {
    if (willMove) willMove();
    if (onTarget) onTarget();
    if (onCompleted) onCompleted();
    return;
  }
  
  self.originalView = fromView;
  
  self.overlayContainer = [[UIView alloc] initWithFrame:win.bounds];
  self.overlayContainer.backgroundColor = [UIColor clearColor];
  [win addSubview:self.overlayContainer];
  
  // Deep clone full tree
  UIView *ghost = [self _deepClone:fromView];
  ghost.frame = fromFrame;
  
  [self.overlayContainer addSubview:ghost];
  self.ghostView = ghost;
  
  if (willMove) willMove();
  [UIView animateWithDuration:_sharingAnimatedDuration
                        delay:0
                      options:UIViewAnimationOptionCurveEaseInOut
                   animations:^{
    // Animate root
    ghost.frame = toFrame;
    // Animate children recursively
    [self _animateSubviewsFrom:fromView to:toView ghost:ghost];
  } completion:^(BOOL finished) {
    if (onTarget) onTarget();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(kDefaultCompletionDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      [ghost removeFromSuperview];
      [self unmount];
      if (onCompleted) onCompleted();
    });
  }];
}

#pragma mark - Deep clone

- (UIView *)_deepClone:(UIView *)view {
  UIView *copy = nil;
  
  if ([view isKindOfClass:[UILabel class]]) {
    UILabel *orig = (UILabel *)view;
    UILabel *labelCopy = [[UILabel alloc] initWithFrame:orig.frame];
    labelCopy.text = orig.text;
    labelCopy.font = orig.font;
    labelCopy.textColor = orig.textColor;
    labelCopy.numberOfLines = orig.numberOfLines;
    labelCopy.textAlignment = orig.textAlignment;
    labelCopy.lineBreakMode = orig.lineBreakMode;
    copy = labelCopy;
  }
  else if ([view isKindOfClass:NSClassFromString(@"RCTParagraphTextView")]) {
    UIView *snap = [view snapshotViewAfterScreenUpdates:NO];
    snap.frame = view.frame;
    copy = snap;
  }
  else if ([view isKindOfClass:[UIImageView class]]) {
    UIImageView *orig = (UIImageView *)view;
    UIImageView *imageCopy = [[UIImageView alloc] initWithFrame:orig.frame];
    imageCopy.image = orig.image;
    imageCopy.contentMode = orig.contentMode;
    imageCopy.clipsToBounds = orig.clipsToBounds;
    copy = imageCopy;
  }
  else {
    UIView *containerCopy = [[UIView alloc] initWithFrame:view.frame];
    containerCopy.backgroundColor = view.backgroundColor;
    containerCopy.layer.cornerRadius = view.layer.cornerRadius;
    containerCopy.clipsToBounds = view.clipsToBounds;
    for (UIView *child in view.subviews) {
      UIView *childCopy = [self _deepClone:child];
      if (childCopy) [containerCopy addSubview:childCopy];
    }
    copy = containerCopy;
  }
  [self copyCommonPropsFrom:view to:copy];
  
  return copy;
}

- (void)copyCommonPropsFrom:(UIView *)view to:(UIView *)copy {
  copy.transform = view.transform;
  copy.layer.masksToBounds = view.layer.masksToBounds;
  copy.layer.cornerRadius = view.layer.cornerRadius;
  copy.layer.borderColor = view.layer.borderColor;
  copy.layer.borderWidth = view.layer.borderWidth;
  copy.backgroundColor = view.backgroundColor;
  
  copy.alpha = view.alpha;
  copy.hidden = view.hidden;
}

#pragma mark - Animate subviews

- (UIView *)_findMatchingChildFor:(UIView *)fromChild
                         inParent:(UIView *)toParent
                     usedChildren:(NSMutableSet<UIView *> *)used {
  for (UIView *c in toParent.subviews) {
    if (![used containsObject:c] && [c isKindOfClass:[fromChild class]]) {
      [used addObject:c];
      return c;
    }
  }
  return nil;
}

- (void)_animateSubviewsFrom:(UIView *)fromView
                          to:(UIView *)toView
                       ghost:(UIView *)ghostView
{
  NSMutableSet<UIView *> *used = [NSMutableSet set];
  NSInteger ghostCount = ghostView.subviews.count;
  
  for (NSInteger i = 0; i < fromView.subviews.count && i < ghostCount; i++) {
    UIView *fromChild  = fromView.subviews[i];
    UIView *ghostChild = ghostView.subviews[i];
    UIView *toChild    = [self _findMatchingChildFor:fromChild
                                            inParent:toView
                                        usedChildren:used];
    if (!toChild) continue;
    
    // Animate frame
    ghostChild.frame = fromChild.frame;
    CGRect endFrame  = toChild.frame;
    
    if ([ghostChild isKindOfClass:[UILabel class]]) {
      UILabel *ghostLabel = (UILabel *)ghostChild;
      UILabel *toLabel    = (UILabel *)toChild;
      [UIView animateWithDuration:_sharingAnimatedDuration
                       animations:^{
        ghostChild.frame = endFrame;
        ghostLabel.font = toLabel.font;
        ghostLabel.textColor = toLabel.textColor;
        ghostLabel.textAlignment = toLabel.textAlignment;
      }];
    }
    else if ([ghostChild isKindOfClass:[UIImageView class]]) {
      UIImageView *ghostImg = (UIImageView *)ghostChild;
      UIImageView *toImg    = (UIImageView *)toChild;
      [UIView animateWithDuration:_sharingAnimatedDuration
                       animations:^{
        ghostImg.frame = endFrame;
        ghostImg.layer.cornerRadius = toImg.layer.cornerRadius;
        ghostImg.contentMode = toImg.contentMode;
      }];
    }
    else {
      [UIView animateWithDuration:_sharingAnimatedDuration
                       animations:^{
        ghostChild.frame = endFrame;
      }];
    }
    
    if (fromChild.subviews.count &&
        toChild.subviews.count &&
        ghostChild.subviews.count) {
      [self _animateSubviewsFrom:fromChild to:toChild ghost:ghostChild];
    }
  }
}


- (void)unmount {
  [self.overlayContainer removeFromSuperview];
  self.overlayContainer = nil;
  self.ghostView = nil;
  self.originalView = nil;
}

@end
