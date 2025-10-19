//
//  RCTNativeEarly.m
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 28/9/25.
//

#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "RCTNativeEarly.h"
#import "RNEarlyRegistry.h"

using namespace facebook;
using namespace facebook::react;

static void PrepareEarly() {
  [[RNEarlyRegistry shared] notifyNav];
    
  [CATransaction flush];
}
@implementation RCTNativeEarly

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:(const facebook::react::ObjCTurboModule::InitParams &)params {
  return std::make_shared<facebook::react::NativeEarlySpecJSI>(params);
}

- (NSNumber *)prepareForGoBackSync {
  if (NSThread.isMainThread) {
    PrepareEarly();
  } else {
    dispatch_sync(dispatch_get_main_queue(), ^{ PrepareEarly(); });
  }
  return @(YES);
}

+ (NSString *)moduleName
{
  return @"RCTNativeEarly";
}

@end
