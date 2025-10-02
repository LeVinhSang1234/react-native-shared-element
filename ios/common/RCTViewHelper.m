//
//  RCTViewHelper.m
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 2/10/25.
//

#import "RCTViewHelper.h"
#import <UIKit/UIKit.h>

#pragma mark - Config (switch strategy at runtime if needed)

typedef NS_ENUM(NSUInteger, RCTFrameStrategy) {
  // Cách 1: convert trực tiếp sang UIWindow (khuyến nghị)
  RCTFrameStrategyDirectWindow = 1,
  // Cách 2: convert vào RNSScreen/RNSScreenStack rồi tự cộng header
  RCTFrameStrategyRNSPlusHeader = 2,
};

static RCTFrameStrategy g_frameStrategy = RCTFrameStrategyDirectWindow;

@implementation RCTViewHelper

+ (void)setFrameStrategyDirectWindow {
  g_frameStrategy = RCTFrameStrategyDirectWindow;
}
+ (void)setFrameStrategyRNSPlusHeader {
  g_frameStrategy = RCTFrameStrategyRNSPlusHeader;
}

#pragma mark - Helpers: Window / VC / RNS

+ (UIWindow * _Nullable)getTargetWindow {
  UIWindow *win = nil;
  if (@available(iOS 13.0, *)) {
    for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
      if (scene.activationState == UISceneActivationStateForegroundActive &&
          [scene isKindOfClass:UIWindowScene.class]) {
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
          if (w.isKeyWindow) { win = w; break; }
        }
        if (!win && ((UIWindowScene *)scene).windows.firstObject) {
          win = ((UIWindowScene *)scene).windows.firstObject;
        }
      }
    }
  } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    win = UIApplication.sharedApplication.keyWindow ?: UIApplication.sharedApplication.windows.firstObject;
#pragma clang diagnostic pop
  }
  return win;
}

+ (nullable UIViewController *)p_nearestViewControllerFrom:(UIView *)view {
  UIResponder *r = view;
  while (r) {
    if ([r isKindOfClass:UIViewController.class]) return (UIViewController *)r;
    r = r.nextResponder;
  }
  return nil;
}

+ (nullable UIView *)p_findAncestorOfClassNames:(NSArray<NSString *> *)classNames from:(UIView *)view {
  UIView *p = view;
  while (p) {
    for (NSString *name in classNames) {
      Class cls = NSClassFromString(name);
      if (cls && [p isKindOfClass:cls]) return p;
    }
    p = p.superview;
  }
  return nil;
}

+ (nullable UIView *)p_findRNSScreenViewFrom:(UIView *)view {
  Class ScreenCls = NSClassFromString(@"RNSScreenView");
  if (!ScreenCls) return nil;
  UIView *p = view;
  while (p) {
    if ([p isKindOfClass:ScreenCls]) return p;
    p = p.superview;
  }
  return nil;
}

+ (CGFloat)p_navHeaderHeightForVC:(UIViewController *)vc {
  if (!vc) return 0;

  UINavigationController *nav = vc.navigationController;
  BOOL navVisible = (nav && !nav.navigationBarHidden && !nav.navigationBar.isHidden);
  CGFloat navH = navVisible ? nav.navigationBar.bounds.size.height : 0;

  CGFloat statusH = 0;
  if (@available(iOS 13.0, *)) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
      if (scene.activationState == UISceneActivationStateForegroundActive &&
          [scene isKindOfClass:UIWindowScene.class]) {
        UIStatusBarManager *mgr = ((UIWindowScene *)scene).statusBarManager;
        if (mgr) { statusH = mgr.statusBarFrame.size.height; break; }
      }
    }
  } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    statusH = UIApplication.sharedApplication.statusBarFrame.size.height;
#pragma clang diagnostic pop
  }

  // safeAreaInsets.top có thể = 0 khi chưa attach window
  CGFloat safeTop = vc.view.safeAreaInsets.top;
  if (safeTop <= 0) safeTop = statusH;

  // Với nav bar không translucent, safeTop đã ở dưới nav bar → không cộng navH.
  // Với nav bar translucent (mặc định), nội dung có thể nằm dưới nav → cộng navH.
  BOOL translucent = nav ? nav.navigationBar.isTranslucent : NO;
  return translucent ? (safeTop + navH) : safeTop;
}

+ (CGFloat)p_rnsHeaderHeightInsideStack:(UIView *)stack {
  Class HeaderCls = NSClassFromString(@"RNSScreenStackHeaderSubview");
  if (!HeaderCls) return 0;
  for (UIView *sub in stack.subviews) {
    if ([sub isKindOfClass:HeaderCls]) {
      [sub layoutIfNeeded];
      return sub.bounds.size.height;
    }
  }
  return 0;
}

#pragma mark - Strategy 1: Direct-to-Window (khuyến nghị)

+ (CGRect)p_frameInWindow_Direct:(UIView *)view {
  // 1) Nếu đang animate → presentationLayer
  CALayer *presentation = view.layer.presentationLayer;
  if (presentation && view.superview && view.window) {
    return [view.superview convertRect:presentation.frame toView:view.window];
  }

  // 2) Có window → convert thẳng sang window
  if (view.window) {
    [view.window layoutIfNeeded];
    return [view convertRect:view.bounds toView:view.window];
  }

  // 3) Không có window → dùng nearest VC (nếu có) rồi convert sang window của VC
  UIViewController *vc = [self p_nearestViewControllerFrom:view];
  if (vc) {
    [vc.view.superview layoutIfNeeded];
    [vc.view layoutIfNeeded];

    CGRect inVC = [view convertRect:view.bounds toView:vc.view];
    if (vc.view.window) {
      return [vc.view convertRect:inVC toView:vc.view.window];
    }

    // chưa attach window → trả về theo hệ quy chiếu VC.view
    return inVC;
  }

  // 4) Fallback root
  UIView *root = view;
  while (root.superview) root = root.superview;
  [root layoutIfNeeded];
  return [view convertRect:view.bounds toView:root];
}

#pragma mark - Strategy 2: RNS + add header

+ (CGRect)p_frameInWindow_RNSPlusHeader:(UIView *)view {
  // 1) Presentation
  CALayer *presentation = view.layer.presentationLayer;
  if (presentation && view.superview && view.window) {
    return [view.superview convertRect:presentation.frame toView:view.window];
  }

  // 2) Ưu tiên RNSScreenStackView (header là "chị em")
  UIView *stack = [self p_findAncestorOfClassNames:@[@"RNSScreenStackView", @"RNSScreenStack"] from:view];
  if (stack) {
    [stack.superview layoutIfNeeded];
    [stack layoutIfNeeded];

    CGRect r = [view convertRect:view.bounds toView:stack];

    // cộng header nếu tồn tại
    CGFloat headerH = [self p_rnsHeaderHeightInsideStack:stack];
    if (headerH <= 0) {
      // fallback qua navBar + safeArea của nearest VC
      UIViewController *vc = [self p_nearestViewControllerFrom:stack];
      headerH = [self p_navHeaderHeightForVC:vc];
    }
    r.origin.y += headerH;

    if (view.window) return [stack convertRect:r toView:view.window];
    return r;
  }

  // 3) RNSScreenView
  UIView *screen = [self p_findRNSScreenViewFrom:view];
  if (screen) {
    [screen.superview layoutIfNeeded];
    [screen layoutIfNeeded];

    CGRect r = [view convertRect:view.bounds toView:screen];
    UIViewController *vc = [self p_nearestViewControllerFrom:screen];
    r.origin.y += [self p_navHeaderHeightForVC:vc];

    if (view.window) return [screen convertRect:r toView:view.window];
    return r;
  }

  // 4) Fallback root
  UIView *root = view;
  while (root.superview) root = root.superview;
  [root layoutIfNeeded];

  CGRect r = [view convertRect:view.bounds toView:root];
  if (view.window) return [root convertRect:r toView:view.window];
  return r;
}

#pragma mark - Public API

+ (CGRect)frameInScreenStable:(UIView *)view {
  if (!view) return CGRectZero;

  switch (g_frameStrategy) {
    case RCTFrameStrategyDirectWindow:
      return [self p_frameInWindow_Direct:view];
    case RCTFrameStrategyRNSPlusHeader:
      return [self p_frameInWindow_RNSPlusHeader:view];
  }
  return [self p_frameInWindow_Direct:view];
}

+ (nullable UIViewController *)getRootViewController {
  UIWindow *win = [self getTargetWindow];
  return win.rootViewController;
}

+ (UIInterfaceOrientation)currentInterfaceOrientation {
  if (@available(iOS 13.0, *)) {
    for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
      if (scene.activationState == UISceneActivationStateForegroundActive &&
          [scene isKindOfClass:UIWindowScene.class]) {
        return scene.interfaceOrientation;
      }
    }
    return UIInterfaceOrientationPortrait;
  } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return UIApplication.sharedApplication.statusBarOrientation;
#pragma clang diagnostic pop
  }
}

@end

