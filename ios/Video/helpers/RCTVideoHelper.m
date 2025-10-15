//
//  RCTVideoHelper.m
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 27/9/25.
//

#import "RCTVideoHelper.h"
#import "RCTVideoCache.h"
#import <UIKit/UIKit.h>

#pragma mark - Config (switch strategy at runtime if needed)

typedef NS_ENUM(NSUInteger, RCTFrameStrategy) {
  // Cách 1: convert trực tiếp sang UIWindow (khuyến nghị)
  RCTFrameStrategyDirectWindow = 1,
  // Cách 2: convert vào RNSScreen/RNSScreenStack rồi tự cộng header
  RCTFrameStrategyRNSPlusHeader = 2,
};

static RCTFrameStrategy g_frameStrategy = RCTFrameStrategyDirectWindow;

@implementation RCTVideoHelper

+ (void)setFrameStrategyDirectWindow {
  g_frameStrategy = RCTFrameStrategyDirectWindow;
}
+ (void)setFrameStrategyRNSPlusHeader {
  g_frameStrategy = RCTFrameStrategyRNSPlusHeader;
}

#pragma mark - Constants

static NSString * const kPosterCacheDirName = @"video_posters";
static NSTimeInterval const kPosterMaxAge   = 6 * 60 * 60; // 6h

#pragma mark - Video Cache

+ (void)applyMaxSizeCache:(NSUInteger)sizeMB {
  [RCTVideoCache VC_ConfigureCache:sizeMB];
}

#pragma mark - Video URL

+ (nullable NSURL *)createVideoURL:(NSString *)source {
  if (source.length == 0) return nil;

  // Remote
  if ([source hasPrefix:@"http"]) {
    NSURL *url = [NSURL URLWithString:source];
    if (!url) return nil;

    [RCTVideoCache VC_StartProxy];
    [RCTVideoCache VC_PrefetchHead:url seconds:3.0 bitratebps:10e6];

    return [RCTVideoCache proxyURLWithOriginalURL:url];
  }

  // File://
  if ([source hasPrefix:@"file://"]) {
    return [NSURL URLWithString:source];
  }

  // Local path
  return [NSURL fileURLWithPath:source];
}

#pragma mark - Poster URL

+ (nullable NSURL *)createPosterURL:(NSString *)source {
  if (source.length == 0) return nil;

  if ([source hasPrefix:@"http"]) {
    NSString *cacheDir = [NSTemporaryDirectory() stringByAppendingPathComponent:kPosterCacheDirName];
    [[NSFileManager defaultManager] createDirectoryAtPath:cacheDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

    NSString *fileName = [source.lastPathComponent stringByAppendingFormat:@"_%lu",
                          (unsigned long)source.hash];
    NSString *filePath = [cacheDir stringByAppendingPathComponent:fileName];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];

    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
    NSDate *modDate = attrs[NSFileModificationDate];
    BOOL expired = modDate ? ([[NSDate date] timeIntervalSinceDate:modDate] > kPosterMaxAge) : YES;

    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath] && !expired) {
      return fileURL;
    }

    NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:source]];
    if (imageData) {
      [imageData writeToFile:filePath atomically:YES];
      return fileURL;
    }
    return [NSURL URLWithString:source];
  }

  if ([source hasPrefix:@"file://"]) {
    return [NSURL URLWithString:source];
  }

  return [NSURL fileURLWithPath:source];
}

@end
