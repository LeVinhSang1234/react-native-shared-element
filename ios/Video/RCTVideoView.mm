//
//  RCTVideoView.m
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 27/9/25.
//

#import "RCTVideoView.h"
#import "RCTVideoContainer.h"
#import "RCTVideoManager.h"
#import "RCTVideoManager.h"
#import "RCTVideoPoster.h"
#import "RCTVideoHelper.h"
#import "UIView+NavTitleCache.h"

#import <react/renderer/components/shareelement/Props.h>
#import <react/renderer/components/shareelement/ComponentDescriptors.h>

// Import support navigation
#import "UIView+NearestVC.h"
#import "UIView+RNSScreenCheck.h"
#import "UIViewController+RNBackLife.h"
#import "UINavigationController+RNPopHook.h"
#import "RNEarlyRegistry.h"
#import "RCTVideoRouteRegistry.h"
#import "RCTVideoOverlay.h"

using namespace facebook::react;

@interface RCTVideoView ()
@property (nonatomic, assign) BOOL isFullscreen;
@property (nonatomic, assign) BOOL isPrepareForRecycle;

@property (nonatomic, strong) RCTVideoPoster *videoPoster;
@property (nonatomic, strong) RCTVideoManager *videoManager;
@property (nonatomic, strong) RCTVideoContainer *videoContainer;
@property (nonatomic, strong) RCTVideoContainer *videoPlayerPosterContainer;

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
@property (nonatomic, strong, nullable) RCTVideoView *otherView;
@property (nonatomic, strong) RCTVideoOverlay *videoOverlay;

@end

@implementation RCTVideoView

#pragma mark - Fabric

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<VideoComponentDescriptor>();
}

#pragma mark - Commands

- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args {
  if ([commandName isEqualToString:@"setSeekCommand"] && args.count) {
    [_videoManager seekToTime:[args[0] doubleValue]];
  } else if ([commandName isEqualToString:@"setPausedCommand"] && args.count) {
    [_videoManager applyPausedFromCommand:[args[0] boolValue]];
  } else if ([commandName isEqualToString:@"setVolumeCommand"] && args.count) {
    [_videoManager applyVolumeFromCommand:[args[0] doubleValue]];
  } else if ([commandName isEqualToString:@"presentFullscreenPlayer"]) {
    [_videoManager enterFullscreen];
  } else if ([commandName isEqualToString:@"dismissFullscreenPlayer"]) {
    [_videoManager exitFullscreen];
  }
}

#pragma mark - Init / Dealloc

- (instancetype)init {
  if (self = [super init]) {
    self.hidden = YES;
    self.backgroundColor = [UIColor blackColor];
    _videoManager = [[RCTVideoManager alloc] init];
    _videoOverlay = [[RCTVideoOverlay alloc] init];
    
    _videoPoster = [[RCTVideoPoster alloc] init];
    _videoContainer = [[RCTVideoContainer alloc] init];
    _videoPlayerPosterContainer = [[RCTVideoContainer alloc] init];
    [_videoPlayerPosterContainer addSubview:_videoPoster];
    
    _isPrepareForRecycle = YES;
    
    __weak __typeof__(self) wSelf = self;
    _videoManager.onPlayerReady = ^() {
      [wSelf applyFullscreen:wSelf.isFullscreen];
    };
    
    [self addSubview:_videoPlayerPosterContainer];
    [self addSubview:_videoContainer];
  }
  return self;
}

- (void)prepareForRecycle {
  [super prepareForRecycle];
  [_videoManager exitFullscreen];
  _isPrepareForRecycle = YES;
  if(!_isSharing && !_otherView.isPrepareForRecycle) {
    [self backShareElement];
  } else [self _returnPlayerToOtherIfNeeded];
  [self willUnmount];
  if(!_isSharing) [self unmount];
}

- (void)willUnmount {
  [self unregisterRouteIfNeeded];
  _shareTagElement = nil;
}

- (void)unmount {
  [_videoManager willUnmount];
  [_videoManager unmount];
  [_videoOverlay unmount];
  
  _nav = nil;
  _otherView = nil;
  _isFocused = NO;
  _isSharing = NO;
}

#pragma mark - Window Lifecycle

- (void)didMoveToWindow {
  [super didMoveToWindow];
  if (self.window) {
    if(_isPrepareForRecycle) [self initialize];
    [[RNEarlyRegistry shared] addView:self];
    
    UIViewController *vc = [self nearestViewController];
    if (!vc) return;
    [self subscribeNavLifecycle:vc];
    [self rn_updateCachedNavTitle];
  } else if (!_isFocused) {
    [[RNEarlyRegistry shared] removeView:self];
    __weak __typeof__(self) wSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      [wSelf unsubscribeNavLifecycle];
    });
  }
}

- (void)initialize {
  [self createPlayerLayerIfNeeded];
  if(!_shareTagElement) {
    self.hidden = NO;
  } else [self shareElement];
}

#pragma mark - Layout
- (void)layoutSubviews {
  [super layoutSubviews];
}


#pragma mark - Mount / Unmount Children

- (void)mountChildComponentView:(UIView<RCTComponentViewProtocol> *)childView
                          index:(NSInteger)index {
  [_videoContainer insertSubview:childView atIndex:index];
}

- (void)unmountChildComponentView:(UIView<RCTComponentViewProtocol> *)childView
                            index:(NSInteger)index {
  [childView removeFromSuperview];
}

#pragma mark - React props / events

- (void)updateEventEmitter:(const facebook::react::EventEmitter::Shared &)eventEmitter {
  [super updateEventEmitter:eventEmitter];
  auto __eventEmitter = std::static_pointer_cast<const facebook::react::VideoEventEmitter>(eventEmitter);
  [_videoManager updateEventEmitter:__eventEmitter.get()];
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &p = *std::static_pointer_cast<VideoProps const>(props);
  [RCTVideoHelper applyMaxSizeCache:p.cacheMaxSize];
  
  NSString *newTag = p.shareTagElement.empty() ? nil : [NSString stringWithUTF8String:p.shareTagElement.c_str()];
  if (![newTag isEqualToString:_shareTagElement]) {
    [self unregisterRouteIfNeeded];
    _shareTagElement = newTag;
    [self tryRegisterRouteIfNeeded];
  }
  
  NSString *source = p.source.empty() ? @"" : [NSString stringWithUTF8String:p.source.c_str()];
  RCTVideoView *otherView = [RCTVideoRouteRegistry resolveViewForTag:_shareTagElement exclude:self];
  if(!otherView) [_videoManager applySource:source];
  [_videoManager applyPaused:p.paused];
  [_videoManager applyMuted:p.muted];
  [_videoManager applyVolume:p.volume];
  [_videoManager applySeek:p.seek];
  [_videoManager applyResizeMode:p.resizeMode.empty() ? @"" : [NSString stringWithUTF8String:p.resizeMode.c_str()]];
  [_videoManager applyProgressInterval:p.progressInterval];
  [_videoManager applyProgress:p.enableProgress];
  [_videoManager applyOnLoad:p.enableOnLoad];
  [_videoManager applyLoop:p.loop];
  
  NSString *poster = p.poster.empty() ? nil : [NSString stringWithUTF8String:p.poster.c_str()];
  [self applyPoster:poster];
  
  NSString *posterResizeMode = p.posterResizeMode.empty() ? nil : [NSString stringWithUTF8String:p.posterResizeMode.c_str()];
  [_videoPoster applyPosterResizeMode:posterResizeMode];
  
  [self applyFullscreen:p.fullscreen];
  
  [super updateProps:props oldProps:oldProps];
}

- (void)applyPoster:(NSString *)poster {
  [_videoPoster applyPoster:poster];
  [self showPosterNeeded];
}

- (void)showPosterNeeded {
  BOOL neverPlayed = (CMTimeGetSeconds(_videoManager.player.currentTime) <= 0.05);
  BOOL shouldShow = (_videoManager.paused && neverPlayed) || !_videoManager.player;
  
  _videoPoster.hidden = !shouldShow;
}

#pragma mark - Player layer

- (void)createPlayerLayerIfNeeded {
  if (CGRectIsEmpty(self.bounds)) return;
  if (_videoManager.playerLayer.superlayer != _videoPlayerPosterContainer.layer) {
    [_videoPlayerPosterContainer.layer addSublayer:_videoManager.playerLayer];
    [_videoPlayerPosterContainer bringSubviewToFront:_videoPoster];
    [_videoPlayerPosterContainer setNeedsLayout];
    [_videoPlayerPosterContainer layoutIfNeeded];
    [self showPosterNeeded];
  }
}

#pragma mark - FullScreen

- (void)applyFullscreen:(BOOL)fullscreen {
  if(_isFullscreen == fullscreen) return;
  _isFullscreen = fullscreen;
  if (fullscreen) {
    [_videoManager enterFullscreen];
  } else [_videoManager exitFullscreen];
}

#pragma mark - Route registry
- (void)tryRegisterRouteIfNeeded {
  [RCTVideoRouteRegistry registerView:self tag:_shareTagElement];
}

- (void)unregisterRouteIfNeeded {
  [RCTVideoRouteRegistry unregisterView:self tag:_shareTagElement];
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
  if(_isSharing) return;
  [self backShareElement];
}

- (void)_onWillPopNoti:(NSNotification *)note {
}

- (void)handleWillPop {
  if(_isSharing || _backGestureActive) return;
  [self backShareElement];
}

- (void)handleDidPop {
  [[RNEarlyRegistry shared] removeView:self];
  [self willUnmount];
  [self unmount];
}

- (void)handleWillAppear:(BOOL)animated {}

- (void)handleWillDisappear:(BOOL)animated {}

- (void)handleDidAppear:(BOOL)animated {
  if (_isFocused) return;
  _isFocused = YES;
  
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

#pragma mark - Back swipe
- (void)_returnPlayerToOtherIfNeeded {
  if (_otherView) {
    [_otherView.videoManager adoptPlayerFromManager:_videoManager];
    [_videoManager detachPlayer];
    
    _otherView.hidden = NO;
    [_otherView createPlayerLayerIfNeeded];
    [_otherView setNeedsLayout];
    [_otherView layoutIfNeeded];
    
    Float64 cur = CMTimeGetSeconds(_otherView.videoManager.player.currentTime);
    if (cur > 0.05) {
      _otherView.videoPoster.hidden = YES;
    }
    [self willUnmount];
    [self unmount];
  }
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
          BOOL popped = !ctx.isCancelled;
          if (popped) [self _returnPlayerToOtherIfNeeded];
        }];
        
        [tc animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> ctx) {
          if (!ctx.isInteractive) {
            BOOL popped = !ctx.isCancelled;
            if (popped) [self _returnPlayerToOtherIfNeeded];
          }
        }];
      }
      break;
    }
    default:
      break;
  }
}

#pragma mark - Share Element
- (void)shareElement {
  if(_otherView) return;
  _otherView = [RCTVideoRouteRegistry resolveViewForTag:_shareTagElement exclude:self];
  if(_otherView) {
    __weak __typeof__(self) wSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      [wSelf sharedTransitionFrom:wSelf.otherView to:wSelf isBack:NO];
    });
  } else self.hidden = NO;
}

- (void)backShareElement {
  if (!_otherView.isPrepareForRecycle) {
    [self unmount];
  } else [self sharedTransitionFrom:self to:_otherView isBack:YES];
}

- (void)sharedTransitionFrom:(RCTVideoView *)fromView
                          to:(RCTVideoView *)toView
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
  
  CGRect fromFrame = [RCTVideoHelper frameInScreenStable:fromView];
  if(isBack) {
    RCTLog(self, @"fromFrame, %@", NSStringFromCGRect(fromFrame));
  }
  CGRect toFrame   = [RCTVideoHelper frameInScreenStable:toView];
  
  if(!fromView.window) fromFrame.origin.y += headerHeightFrom;
  if(!toView.window) toFrame.origin.y += headerHeightTo;
  
  [toView.videoOverlay moveToOverlay:fromFrame
                          tagetFrame:toFrame
                              player:fromView.videoManager.player
                 aVLayerVideoGravity:fromView.videoManager.aVLayerVideoGravity
                         fromBgColor:fromView.backgroundColor
                           toBgColor:toView.backgroundColor
                            willMove:^ {
    fromView.hidden = YES;
    toView.hidden = YES;
  }
                            onTarget:^{
    [toView.videoManager adoptPlayerFromManager:fromView.videoManager];
    [fromView.videoManager detachPlayer];
    toView.hidden = NO;
  } onCompleted:^{
    [toView createPlayerLayerIfNeeded];
    
    fromView.isSharing = NO;
    toView.isSharing = NO;
    
    Float64 cur = CMTimeGetSeconds(toView.videoManager.player.currentTime);
    if (cur < 0.05 && toView.videoManager.paused) toView.videoPoster.hidden = NO;
    else toView.videoPoster.hidden = YES;
    
    if(!isBack) {
      fromView.hidden = NO;
      fromView.videoPoster.hidden = NO;
    } else [fromView unmount];
  }];
}

@end
