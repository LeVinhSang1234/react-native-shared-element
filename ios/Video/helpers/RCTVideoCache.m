//
//  RCTVideoCache.m
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 27/9/25.
//

#import "RCTVideoCache.h"
#import "KTVHTTPCache/KTVHTTPCache.h"

static double maxSizeMB = 5000; // 5GB

@implementation RCTVideoCache

-(instancetype)init {
  self = [super init];
  return self;
}

+ (NSString *)VC_CacheDir {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
  NSString *cachesDir = [paths firstObject];
  return [cachesDir stringByAppendingPathComponent:@"KTVHTTPCache"];
}

+(NSInteger)VC_BytesFor:(double) seconds bitratebps:(double) bitratebps {
  if (bitratebps <= 0) bitratebps = 2e6;
  NSInteger bytes = (NSInteger)((bitratebps / 8.0) * seconds);
  return MAX(bytes, 128 * 1024);
}

+(void)VC_StartProxy {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSError *err = nil;
    [KTVHTTPCache proxyStart:&err]; // start global proxy 1 lần
    [KTVHTTPCache logSetConsoleLogEnable:NO];
    [KTVHTTPCache logSetRecordLogEnable:NO];
    
    if ([KTVHTTPCache respondsToSelector:@selector(logSetConsoleLogEnable:)]) {
      [KTVHTTPCache logSetConsoleLogEnable:NO];
    }
    if (err) NSLog(@"[VideoView] proxyStart error: %@", err);
  });
}

+ (void)VC_ConfigureCache:(NSUInteger)sizeMB {
  double size = sizeMB <= 0 ? 300 : sizeMB;
  if(maxSizeMB != size) {
    maxSizeMB = size;
    [KTVHTTPCache cacheSetMaxCacheLength:(NSUInteger)(maxSizeMB * 1024 * 1024)];
  };
}

+(void)VC_PrefetchHead:(NSURL *) url seconds:(double) seconds bitratebps:(double) bitratebps {
  NSInteger want = [self VC_BytesFor:seconds bitratebps:bitratebps];
  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
  [req setValue:[NSString stringWithFormat:@"bytes=0-%ld", (long)(want - 1)]
forHTTPHeaderField:@"Range"];
  [[[NSURLSession sharedSession] dataTaskWithRequest:req
                                   completionHandler:^(__unused NSData *data,
                                                       __unused NSURLResponse *resp,
                                                       __unused NSError *error) {
  }] resume];
}

+ (void)proxyURLWithOriginalURL:(NSURL *)url completion:(void (^)(NSURL *finalURL))completion {
  long long maxCacheBytes = [KTVHTTPCache cacheMaxCacheLength];
  if (maxCacheBytes <= 0) {
    maxCacheBytes = 300L * 1024L * 1024L;
  }
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  request.HTTPMethod = @"HEAD";
  
  NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                                               completionHandler:^(NSData * _Nullable data,
                                                                                   NSURLResponse * _Nullable response,
                                                                                   NSError * _Nullable error) {
    long long contentLength = response.expectedContentLength;
    NSURL *finalURL = url;
    
    NSLog(@"⚠️ [VideoHelper] File too large for cache (%lld bytes > %lld bytes), using direct URL.",
          contentLength, maxCacheBytes);
    
    if (!error && contentLength > 0 && contentLength <= maxCacheBytes) {
      NSURL *proxyURL = [KTVHTTPCache proxyURLWithOriginalURL:url bindToLocalhost:NO];
      if (proxyURL && [KTVHTTPCache proxyIsRunning]) {
        finalURL = proxyURL;
      }
    }
    if (completion) completion(finalURL);
  }];
  [task resume];
}

@end
