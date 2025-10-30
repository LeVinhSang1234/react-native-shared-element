//
//  GalleryDataManager.m
//  GalleryPicker
//
//  Created by Sang Le Vinh on 10/29/25.
//

#import "GalleryDataManager.h"

#pragma mark - 🔹 Helper

static NSString *GalleryStringFromAuthorizationStatus(PHAuthorizationStatus status) {
  switch (status) {
    case PHAuthorizationStatusNotDetermined: return @"NOT_DETERMINED";
    case PHAuthorizationStatusRestricted:    return @"RESTRICTED";
    case PHAuthorizationStatusDenied:        return @"DENIED";
    case PHAuthorizationStatusAuthorized:    return @"AUTHORIZED";
    case PHAuthorizationStatusLimited:       return @"LIMITED";
    default:                                 return @"UNKNOWN";
  }
}

@implementation GalleryDataManager

#pragma mark - 🔐 PHOTO PERMISSION

+ (void)requestPhotoPermission:(void (^)(void))onGranted
                       onError:(void (^)(NSString *code, NSString *message))onError
{
  PHAuthorizationStatus status;
  if (@available(iOS 14, *)) {
    status = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelReadWrite];
  } else {
    status = [PHPhotoLibrary authorizationStatus];
  }
  
  void (^emitError)(PHAuthorizationStatus, NSString *) = ^(PHAuthorizationStatus st, NSString *msg) {
    NSString *code = GalleryStringFromAuthorizationStatus(st);
    if (onError) {
      dispatch_async(dispatch_get_main_queue(), ^{
        onError(code, msg);
      });
    }
  };
  
  switch (status) {
    case PHAuthorizationStatusAuthorized:
    case PHAuthorizationStatusLimited:
      if (onGranted) dispatch_async(dispatch_get_main_queue(), onGranted);
      break;
      
    case PHAuthorizationStatusNotDetermined: {
      if (@available(iOS 14, *)) {
        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite
                                                   handler:^(PHAuthorizationStatus newStatus) {
          if (newStatus == PHAuthorizationStatusAuthorized ||
              newStatus == PHAuthorizationStatusLimited) {
            dispatch_async(dispatch_get_main_queue(), onGranted);
          } else {
            emitError(newStatus, @"User denied access to photo library.");
          }
        }];
      } else {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus newStatus) {
          if (newStatus == PHAuthorizationStatusAuthorized) {
            dispatch_async(dispatch_get_main_queue(), onGranted);
          } else {
            emitError(newStatus, @"User denied access to photo library.");
          }
        }];
      }
      break;
    }
      
    case PHAuthorizationStatusRestricted:
      emitError(status, @"Photo library access is restricted (e.g., parental controls).");
      break;
      
    default:
      emitError(status, @"No access to photo library.");
      break;
  }
}

#pragma mark - 📁 CACHE MANAGEMENT

+ (NSString *)cacheDirectory {
  NSString *base = NSTemporaryDirectory();
  NSString *dir = [base stringByAppendingPathComponent:@"gallery_cache"];
  NSFileManager *fm = [NSFileManager defaultManager];
  if (![fm fileExistsAtPath:dir]) {
    [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
  }
  return dir;
}

+ (void)clearCache {
  NSString *cacheDir = [self cacheDirectory];
  NSFileManager *fm = [NSFileManager defaultManager];
  if ([fm fileExistsAtPath:cacheDir]) {
    NSError *err = nil;
    [fm removeItemAtPath:cacheDir error:&err];
    if (err) {
      NSLog(@"[GalleryDataManager] Failed to clear cache: %@", err.localizedDescription);
    }
  }
}

#pragma mark - 📸 FETCH ALBUMS

+ (NSArray<NSDictionary *> *)fetchAlbums:(NSString *)albumType
                                    type:(NSString *)type
{
  NSMutableArray<NSDictionary *> *albums = [NSMutableArray array];
  PHFetchOptions *fetchOptions = [PHFetchOptions new];
  
  if ([type isEqualToString:@"image"]) {
    fetchOptions.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeImage];
  } else if ([type isEqualToString:@"video"]) {
    fetchOptions.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeVideo];
  }
  
  BOOL includeUserAlbums = ![albumType isEqualToString:@"SmartAlbum"];
  BOOL includeSmartAlbums = ![albumType isEqualToString:@"Album"];
  
  void (^processCollections)(PHFetchResult<PHAssetCollection *> *, BOOL) =
  ^(PHFetchResult<PHAssetCollection *> *collections, BOOL isSmart) {
    for (PHAssetCollection *collection in collections) {
      PHFetchResult<PHAsset *> *assets =
      [PHAsset fetchAssetsInAssetCollection:collection options:fetchOptions];
      if (assets.count == 0) continue;
      
      PHAsset *asset = assets.firstObject;
      if (!asset) continue;
      
      __block UIImage *thumbnail = nil;
      PHImageRequestOptions *opts = [PHImageRequestOptions new];
      opts.deliveryMode = PHImageRequestOptionsDeliveryModeFastFormat;
      opts.resizeMode = PHImageRequestOptionsResizeModeFast;
      opts.synchronous = YES;
      
      CGSize targetSize = CGSizeMake(200, 200);
      [[PHImageManager defaultManager] requestImageForAsset:asset
                                                 targetSize:targetSize
                                                contentMode:PHImageContentModeAspectFill
                                                    options:opts
                                              resultHandler:^(UIImage *result, NSDictionary *info) {
        thumbnail = result;
      }];
      
      if (!thumbnail) continue;
      
      [albums addObject:@{
        @"id": collection.localIdentifier ?: @"",
        @"title": collection.localizedTitle ?: @"",
        @"count": @(assets.count),
        @"isSmart": @(isSmart),
        @"thumbnail": thumbnail,
        @"collection": collection
      }];
    }
  };
  
  if (includeUserAlbums) {
    PHFetchResult<PHAssetCollection *> *userAlbums =
    [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                             subtype:PHAssetCollectionSubtypeAny
                                             options:nil];
    processCollections(userAlbums, NO);
  }
  
  if (includeSmartAlbums) {
    PHFetchResult<PHAssetCollection *> *smartAlbums =
    [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum
                                             subtype:PHAssetCollectionSubtypeAny
                                             options:nil];
    processCollections(smartAlbums, YES);
  }
  
  [albums sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
    return [b[@"count"] compare:a[@"count"]];
  }];
  
  return albums;
}

#pragma mark - 🖼️ FETCH PHOTOS

+ (NSArray<PHAsset *> *)fetchPhotos:(NSString *)albumId
                               type:(NSString *)type
                            maxSize:(double)maxSize
                        maxDuration:(double)maxDuration
{
  NSMutableArray<PHAsset *> *result = [NSMutableArray array];
  PHFetchResult<PHAssetCollection *> *collections =
  [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[albumId] options:nil];
  
  if (collections.count == 0) return result;
  PHAssetCollection *album = collections.firstObject;
  
  PHFetchOptions *options = [PHFetchOptions new];
  if ([type isEqualToString:@"image"]) {
    options.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeImage];
  } else if ([type isEqualToString:@"video"]) {
    options.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeVideo];
  }
  
  PHFetchResult<PHAsset *> *assets = [PHAsset fetchAssetsInAssetCollection:album options:options];
  [assets enumerateObjectsUsingBlock:^(PHAsset *asset, NSUInteger idx, BOOL *stop) {
    if (asset.mediaType == PHAssetMediaTypeVideo && maxDuration > 0 && asset.duration > maxDuration) return;
    if (maxSize > 0) {
      NSArray *resources = [PHAssetResource assetResourcesForAsset:asset];
      PHAssetResource *res = resources.firstObject;
      long long fileSize = [[res valueForKey:@"fileSize"] longLongValue];
      if (fileSize > maxSize) return;
    }
    [result addObject:asset];
  }];
  
  [result sortUsingComparator:^NSComparisonResult(PHAsset *a, PHAsset *b) {
    return [b.creationDate compare:a.creationDate];
  }];
  
  return result;
}

#pragma mark - 🔗 ASSET URI

+ (NSString *)uriForAsset:(PHAsset *)asset {
  if (!asset) return nil;
  
  __block NSString *uri = nil;
  PHImageManager *manager = [PHImageManager defaultManager];
  NSString *cacheDir = [self cacheDirectory];
  NSFileManager *fm = [NSFileManager defaultManager];
  
  if (asset.mediaType == PHAssetMediaTypeImage) {
    NSString *tempFile = [cacheDir stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"%@.jpg", asset.localIdentifier]];
    if ([fm fileExistsAtPath:tempFile]) {
      return [NSString stringWithFormat:@"file://%@", tempFile];
    }
    
    PHImageRequestOptions *options = [PHImageRequestOptions new];
    options.synchronous = YES;
    options.networkAccessAllowed = YES;
    
    [manager requestImageDataAndOrientationForAsset:asset
                                            options:options
                                      resultHandler:^(NSData *data,
                                                      NSString *UTI,
                                                      CGImagePropertyOrientation orientation,
                                                      NSDictionary *info) {
      NSURL *fileURL = info[@"PHImageFileURLKey"];
      if (fileURL) {
        uri = fileURL.absoluteString;
      } else if (data) {
        [data writeToFile:tempFile atomically:YES];
        uri = [NSString stringWithFormat:@"file://%@", tempFile];
      }
    }];
  } else if (asset.mediaType == PHAssetMediaTypeVideo) {
    NSString *tempFile = [cacheDir stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"%@.mov", asset.localIdentifier]];
    if ([fm fileExistsAtPath:tempFile]) {
      return [NSString stringWithFormat:@"file://%@", tempFile];
    }
    
    PHVideoRequestOptions *options = [PHVideoRequestOptions new];
    options.networkAccessAllowed = YES;
    options.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [manager requestAVAssetForVideo:asset
                            options:options
                      resultHandler:^(AVAsset *avAsset, AVAudioMix *audioMix, NSDictionary *info) {
      if ([avAsset isKindOfClass:[AVURLAsset class]]) {
        NSURL *url = [(AVURLAsset *)avAsset URL];
        if (url) uri = url.absoluteString;
      } else {
        NSURL *tempURL = [NSURL fileURLWithPath:tempFile];
        AVAssetExportSession *exportSession =
        [[AVAssetExportSession alloc] initWithAsset:avAsset presetName:AVAssetExportPresetPassthrough];
        exportSession.outputURL = tempURL;
        exportSession.outputFileType = AVFileTypeQuickTimeMovie;
        
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
          if (exportSession.status == AVAssetExportSessionStatusCompleted) {
            uri = tempURL.absoluteString;
          }
          dispatch_semaphore_signal(sema);
        }];
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
      }
      dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
  }
  
  return uri;
}

@end
