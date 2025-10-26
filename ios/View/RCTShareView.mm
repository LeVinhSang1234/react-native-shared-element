//
//  RCTShareView.m
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 1/10/25.
//

#import "RCTShareView.h"
#import "RCTViewHelper.h"
#import "RCTShareViewContainer.h"
#import "UIView+NavTitleCache.h"
#import "RCTShareViewOverlay.h"

#import <react/renderer/components/reactnativesharedelement/Props.h>
#import <react/renderer/components/reactnativesharedelement/ComponentDescriptors.h>

// Import support navigation
#import "UIView+NearestVC.h"
#import "UIViewController+RNBackLife.h"
#import "UINavigationController+RNPopHook.h"
#import "RNEarlyRegistry.h"
#import "RCTShareViewRouteRegistry.h"
#import "RCTVideoOverlay.h"

using namespace facebook::react;

@interface RCTShareView ()
@property (nonatomic, assign) BOOL frozen;
@property (nonatomic, strong) UIView *snapshotView;

@property (nonatomic, assign) BOOL isPrepareForRecycle;
@property (nonatomic, strong) RCTShareViewContainer *viewContainer;
@property (nonatomic, strong) NSPointerArray *pausedPlayers;

// support navigation
@property (nonatomic, weak) UINavigationController *nav;
@property (nonatomic, copy) RNBackBlock willPopBlock;
@property (nonatomic, copy) RNBackBlock didPopBlock;
@property (nonatomic, copy) RNLifecycleBlock willAppearBlock;
@property (nonatomic, copy) RNLifecycleBlock didAppearBlock;
@property (nonatomic, copy) RNLifecycleBlock willDisappearBlock;
@property (nonatomic, copy) RNLifecycleBlock didDisappearBlock;

// share element
@property (nonatomic, assign) BOOL isSharing;
@property (nonatomic, assign) BOOL isFocused;
@property (nonatomic, assign) BOOL backGestureActive;
@property (nonatomic, assign) BOOL hasGestureTarget;
@property (nonatomic, copy) NSString *shareTagElement;
@property (nonatomic, strong, nullable) RCTShareView *otherView;
@property (nonatomic, strong, nullable) RCTShareViewOverlay *shareViewOverlay;

@end

@implementation RCTShareView
#pragma mark - Fabric

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<ShareViewComponentDescriptor>();
}

#pragma mark - Commands

- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args {
  if ([commandName isEqualToString:@"initialize"]) {
    [self initialize];
  } else if ([commandName isEqualToString:@"prepareForRecycle"]) {
    [self backShareElement];
  } else if ([commandName isEqualToString:@"freeze"]) {
    [self freeze];
  } else if ([commandName isEqualToString:@"unfreeze"]) {
    [self unfreeze];
  }
}

- (instancetype)init {
  if(self = [super init]) {
    _shareViewOverlay = [[RCTShareViewOverlay alloc] init];
    
    _viewContainer = [[RCTShareViewContainer alloc] init];
    self.pausedPlayers = [NSPointerArray weakObjectsPointerArray];
    [self addSubview:_viewContainer];
    self.hidden = YES;
  }
  // Thêm lắng nghe sự kiện lắng nghe trên navigaiton
  [UIViewController rn_swizzleBackLifeIfNeeded];
  [UINavigationController rn_enablePopHookOnce];
  
  return self;
}

- (void)initialize {
  _isPrepareForRecycle = NO;
  if(!_shareTagElement) {
    self.hidden = NO;
  } else [self shareElement];
}

- (void)prepareForRecycle {
  [super prepareForRecycle];
  [self willUnmount];
  if(!_isSharing) {
    [self unmount];
  };
}

- (void)willUnmount {
  [self unregisterRouteIfNeeded];
  _shareTagElement = nil;
}

- (void)unmount {
  [self unsubscribeNavLifecycle];
  _nav = nil;
  _otherView = nil;
  _isFocused = NO;
  _isSharing = NO;
}

#pragma mark - Window Lifecycle

- (void)didMoveToWindow {
  [super didMoveToWindow];
  if (self.window) {
    [[RNEarlyRegistry shared] addView:self];
    UIViewController *vc = [self nearestViewController];
    if (!vc) return;
    [self subscribeNavLifecycle:vc];
    [self rn_updateCachedNavTitle];
  } else if (!_isFocused) {
    [[RNEarlyRegistry shared] removeView:self];
  }
}

- (void)freeze {
  if (self.frozen) return;
  self.frozen = YES;
  
  [self pausedVideoLayersIn:self];
  
  UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, [UIScreen mainScreen].scale);
  
  [self drawViewHierarchyInRect:self.bounds afterScreenUpdates:NO];
  UIImage *snapshotImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  UIImageView *snapshotView = [[UIImageView alloc] initWithImage:snapshotImage];
  snapshotView.frame = self.bounds;
  snapshotView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  
  _viewContainer.hidden = YES;
  self.layer.speed = 0.0;
  [self addSubview:snapshotView];
  self.snapshotView = snapshotView;
  [CATransaction flush];
}

- (void)unfreeze
{
  if (!self.frozen) return;
  
  if (self.snapshotView) {
    [self.snapshotView removeFromSuperview];
    self.snapshotView = nil;
  }
  _viewContainer.hidden = NO;
  self.layer.speed = 1.0;
  [self resumeVideoLayersIn];
  
  self.frozen = NO;
}

- (void)pausedVideoLayersIn:(UIView *)root {
  for (UIView *sub in root.subviews) {
    for (CALayer *layer in sub.layer.sublayers) {
      if ([layer isKindOfClass:[AVPlayerLayer class]]) {
        AVPlayer *player = ((AVPlayerLayer *)layer).player;
        if (player && player.rate > 0.01) {
          [player pause];
          [self.pausedPlayers addPointer:(__bridge void * _Nullable)(player)];
        }
      }
    }
    [self pausedVideoLayersIn:sub];
  }
}

- (void)resumeVideoLayersIn {
  for (NSUInteger i = 0; i < self.pausedPlayers.count; i++) {
    AVPlayer *player = (__bridge AVPlayer *)[self.pausedPlayers pointerAtIndex:i];
    
    if (player) {
      @try {
        [player play];
      } @catch (NSException *e) {
      }
    }
  }
  [self.pausedPlayers compact];
}

#pragma mark - React props / events

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &p = *std::static_pointer_cast<ShareViewProps const>(props);
  
  NSString *newTag = p.shareTagElement.empty() ? nil : [NSString stringWithUTF8String:p.shareTagElement.c_str()];
  if (![newTag isEqualToString:_shareTagElement]) {
    [self unregisterRouteIfNeeded];
    _shareTagElement = newTag;
    [self tryRegisterRouteIfNeeded];
  }
  [_shareViewOverlay applySharingAnimatedDuration:p.sharingAnimatedDuration];

  [super updateProps:props oldProps:oldProps];
}

#pragma mark - Mount / Unmount Children

- (void)mountChildComponentView:(UIView<RCTComponentViewProtocol> *)childView
                          index:(NSInteger)index {
  [_viewContainer insertSubview:childView atIndex:index];
}

- (void)unmountChildComponentView:(UIView<RCTComponentViewProtocol> *)childView
                            index:(NSInteger)index {
  [childView removeFromSuperview];
}


#pragma mark - Route registry
- (void)tryRegisterRouteIfNeeded {
  [RCTShareViewRouteRegistry registerView:self tag:_shareTagElement];
}

- (void)unregisterRouteIfNeeded {
  [RCTShareViewRouteRegistry unregisterView:self tag:_shareTagElement];
}

#pragma mark - Navigation attach/detach

- (void)subscribeNavLifecycle:(UIViewController *)vc {
  __weak __typeof__(self) wSelf = self;
  self.nav = vc.navigationController;
  
  [vc.rn_onWillPopBlocks addObject:^{ [wSelf handleWillPop]; }];
  [vc.rn_onDidPopBlocks addObject:^{ [wSelf handleDidPop]; }];
  
  [vc.rn_onWillAppearBlocks addObject:^(BOOL animated){ [wSelf handleWillAppear:animated]; }];
  [vc.rn_onDidAppearBlocks addObject:^(BOOL animated){ [wSelf handleDidAppear:animated]; }];
  
  [vc.rn_onWillDisappearBlocks addObject:^(BOOL animated){ [wSelf handleWillDisappear:animated]; }];
  [vc.rn_onDidDisappearBlocks addObject:^(BOOL animated){ [wSelf handleDidDisappear:animated]; }];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(_onWillPopNoti:)
                                               name:@"RNWillPopViewControllerNotification"
                                             object:_nav];
}

- (void)unsubscribeNavLifecycle {
  UIViewController *vc = [self nearestViewController];
  if (vc) {
    if (_willPopBlock) [vc.rn_onWillPopBlocks removeObject:_willPopBlock];
    if (_didPopBlock)  [vc.rn_onDidPopBlocks removeObject:_didPopBlock];
    if (_willAppearBlock) [vc.rn_onWillAppearBlocks removeObject:_willAppearBlock];
    if (_didAppearBlock)  [vc.rn_onDidAppearBlocks removeObject:_didAppearBlock];
    if (_willDisappearBlock) [vc.rn_onWillDisappearBlocks removeObject:_willDisappearBlock];
    if (_didDisappearBlock)  [vc.rn_onDidDisappearBlocks removeObject:_didDisappearBlock];
  }
  
  _willPopBlock = nil;
  _didPopBlock = nil;
  _willAppearBlock = nil;
  _didAppearBlock = nil;
  _willDisappearBlock = nil;
  _didDisappearBlock = nil;
  
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:@"RNWillPopViewControllerNotification"
                                                object:_nav];
}

#pragma mark - Navigation events

- (void)rn_onEarlyPopFromNav {
  if(_isSharing || _backGestureActive || _otherView.window == self.window) return;
  [self backShareElement];
}

- (void)_onWillPopNoti:(NSNotification *)note {
}

- (void)handleWillPop {
  if(_isSharing || _backGestureActive || _otherView.window == self.window) return;
  [self backShareElement];
}

- (void)handleDidPop {
  [[RNEarlyRegistry shared] removeView:self];
  [self willUnmount];
  if(!_isSharing) {
    [self unmount];
  }
}

- (void)handleWillAppear:(BOOL)animated {
  _isFocused = YES;
}

- (void)handleWillDisappear:(BOOL)animated {}

- (void)handleDidAppear:(BOOL)animated {  
  UIGestureRecognizer *g = self.nav.interactivePopGestureRecognizer;
  if (g && !self.hasGestureTarget) {
    [g addTarget:self action:@selector(_handlePopGesture:)];
    self.hasGestureTarget = YES;
  }
}

- (void)handleDidDisappear:(BOOL)animated {
  _isFocused = NO;
  if (_nav && _hasGestureTarget) {
    [_nav.interactivePopGestureRecognizer removeTarget:self action:@selector(_handlePopGesture:)];
    _hasGestureTarget = NO;
  }
  self.nav = nil;
}

- (void)_handlePopGesture:(UIGestureRecognizer *)gr {
  if (!_isFocused) return;
  
  switch (gr.state) {
    case UIGestureRecognizerStateBegan: {
      _backGestureActive = YES;
      break;
    }
    case UIGestureRecognizerStateChanged: {
      break;
    }
    case UIGestureRecognizerStateCancelled:
    case UIGestureRecognizerStateEnded: {
      _backGestureActive = NO;
      
      id<UIViewControllerTransitionCoordinator> tc =
      self.nav.topViewController.transitionCoordinator ?: self.nav.transitionCoordinator;
      
      if (tc) {
        [tc notifyWhenInteractionChangesUsingBlock:^(id<UIViewControllerTransitionCoordinatorContext> ctx) {
          // BOOL popped = !ctx.isCancelled;
          // if (popped) [self _returnPlayerToOtherIfNeeded];
        }];
        
        [tc animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> ctx) {
          if (!ctx.isInteractive) {
            // BOOL popped = !ctx.isCancelled;
            // if (popped) [self _returnPlayerToOtherIfNeeded];
          }
        }];
      }
      break;
    }
    default:
      break;
  }
}

#pragma mark - ShareElement

- (void)shareElement {
  _otherView = [RCTShareViewRouteRegistry resolveViewForTag:_shareTagElement exclude:self];
  
  if(_otherView) {
    __weak __typeof__(self) wSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      [wSelf sharedTransitionFrom:wSelf.otherView to:wSelf isBack:NO];
    });
  } else self.hidden = NO;
}


- (void)backShareElement {
  if (!_otherView || _otherView.otherView) {
    return;
  } else [self sharedTransitionFrom:self to:_otherView isBack:YES];
}


- (void)sharedTransitionFrom:(RCTShareView *)fromView
                          to:(RCTShareView *)toView
                      isBack:(Boolean) isBack {
  if (!fromView || !toView || fromView == toView) return;
  
  UIViewController *vcFrom = [fromView nearestViewController];
  CGFloat headerHeightFrom = CGRectGetMaxY(vcFrom.navigationController.navigationBar.frame);
  
  UIViewController *vc = [toView nearestViewController];
  CGFloat headerHeightTo = CGRectGetMaxY(vc.navigationController.navigationBar.frame);
  
  if(headerHeightTo < 0) headerHeightTo = 0;
  if(headerHeightFrom < 0) headerHeightFrom = 0;
  
  fromView.isSharing = YES;
  toView.isSharing = YES;
  
  CGRect fromFrame = [RCTViewHelper frameInScreenStable:fromView];
  CGRect toFrame   = [RCTViewHelper frameInScreenStable:toView];
  
  if(!fromView.window) fromFrame.origin.y += headerHeightFrom;
  if(!toView.window) toFrame.origin.y += headerHeightTo;
  
  Float64 dur = [vc rn_transitionDuration];
  if(dur > 0) [toView.shareViewOverlay applySharingAnimatedDuration:dur * 1000.0];
  
  [toView.shareViewOverlay moveToOverlay:fromFrame
                             targetFrame:toFrame
                                fromView:fromView
                                  toView:toView willMove:^ {
    fromView.hidden = YES;
    toView.hidden = YES;
  }
                                onTarget:^ {
    toView.hidden = NO;
  }
                             onCompleted:^{
    fromView.isSharing = NO;
    toView.isSharing = NO;
    
    if(isBack) [toView unmount];
    else fromView.hidden = NO;
  }];
}

@end

