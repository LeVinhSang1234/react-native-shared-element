//
//  RCTShareViewRouteRegistry.m
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 1/10/25.
//

#import "RCTShareViewRouteRegistry.h"
#import "RCTShareView.h"

@implementation RCTShareViewRouteRegistry

static NSMutableDictionary<NSString *, NSMutableArray<RCTShareView *> *> *gRegistry;

+ (void)initialize {
  if (self == [RCTShareViewRouteRegistry class] && !gRegistry) {
    gRegistry = [NSMutableDictionary dictionary];
  }
}

+ (void)registerView:(RCTShareView *)view tag:(NSString *)tag {
  if (!tag.length || !view) return;
  NSMutableArray *arr = gRegistry[tag];
  if (!arr) {
    arr = [NSMutableArray array];
    gRegistry[tag] = arr;
  }
  if (![arr containsObject:view]) {
    [arr addObject:view];
  }
}

+ (void)unregisterView:(RCTShareView *)view tag:(NSString *)tag {
  if (!tag.length || !view) return;
  NSMutableArray *arr = gRegistry[tag];
  [arr removeObject:view];
  if (arr.count == 0) [gRegistry removeObjectForKey:tag];
}

+ (nullable RCTShareView *)resolveViewForTag:(NSString *)tag exclude:(RCTShareView *)excludeView {
  if (!tag.length) return nil;
  NSArray *arr = gRegistry[tag];
  for (RCTShareView *v in [arr reverseObjectEnumerator]) {
    if (v != excludeView) {
      return v;
    }
  }
  return nil;
}

@end
