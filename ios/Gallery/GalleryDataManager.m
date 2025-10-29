//
//  GalleryDataManager.m
//  GalleryPicker
//
//  Created by Sang Le vinh on 10/29/25.
//

#import "GalleryDataManager.h"


static NSString *GalleryStringFromAuthorizationStatus(PHAuthorizationStatus status) {
  switch (status) {
    case PHAuthorizationStatusNotDetermined:
      return @"NOT_DETERMINED";
    case PHAuthorizationStatusRestricted:
      return @"RESTRICTED";
    case PHAuthorizationStatusDenied:
      return @"DENIED";
    case PHAuthorizationStatusAuthorized:
      return @"AUTHORIZED";
    case PHAuthorizationStatusLimited:
      return @"LIMITED";
    default:
      return @"UNKNOWN";
  }
}

@implementation GalleryDataManager

#pragma mark - PERMISSION

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
      if (onGranted) {
        dispatch_async(dispatch_get_main_queue(), ^{
          onGranted();
        });
      }
      break;
      
    case PHAuthorizationStatusNotDetermined: {
      if (@available(iOS 14, *)) {
        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite
                                                   handler:^(PHAuthorizationStatus newStatus) {
          if (newStatus == PHAuthorizationStatusAuthorized ||
              newStatus == PHAuthorizationStatusLimited) {
            dispatch_async(dispatch_get_main_queue(), ^{
              if (onGranted) onGranted();
            });
          } else {
            emitError(newStatus, @"User denied access to photo library.");
          }
        }];
      } else {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus newStatus) {
          if (newStatus == PHAuthorizationStatusAuthorized) {
            dispatch_async(dispatch_get_main_queue(), ^{
              if (onGranted) onGranted();
            });
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

#pragma mark - ALBUMS

+ (NSArray<NSDictionary *> *)fetchAlbums:(NSString *)albumType
                                    type:(NSString *)type
{
  NSMutableArray<NSDictionary *> *albums = [NSMutableArray array];
  
  // 1️⃣ Filter by media type
  PHFetchOptions *fetchOptions = [PHFetchOptions new];
  if ([type isEqualToString:@"image"]) {
    fetchOptions.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeImage];
  } else if ([type isEqualToString:@"video"]) {
    fetchOptions.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeVideo];
  }
  
  BOOL includeUserAlbums = ![albumType isEqualToString:@"SmartAlbum"];
  BOOL includeSmartAlbums = ![albumType isEqualToString:@"Album"];
  
  // 2️⃣ Helper block: process album collections
  void (^processCollections)(PHFetchResult<PHAssetCollection *> *, BOOL) =
  ^(PHFetchResult<PHAssetCollection *> *collections, BOOL isSmart) {
    
    for (PHAssetCollection *collection in collections) {
      PHFetchResult<PHAsset *> *assets =
      [PHAsset fetchAssetsInAssetCollection:collection options:fetchOptions];
      
      if (assets.count == 0) continue;
      
      // Lấy asset mới nhất (thumbnail)
      PHAsset *asset = assets.firstObject;
      if (!asset) continue;
      
      __block UIImage *thumbnail = nil;
      PHImageRequestOptions *opts = [PHImageRequestOptions new];
      opts.deliveryMode = PHImageRequestOptionsDeliveryModeFastFormat;
      opts.resizeMode = PHImageRequestOptionsResizeModeFast;
      opts.synchronous = YES; // load nhanh trong background, không block UI
      
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
        @"thumbnail": thumbnail
      }];
    }
  };
  
  // 3️⃣ User albums
  if (includeUserAlbums) {
    PHFetchResult<PHAssetCollection *> *userAlbums =
    [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                             subtype:PHAssetCollectionSubtypeAny
                                             options:nil];
    processCollections(userAlbums, NO);
  }
  
  // 4️⃣ Smart albums
  if (includeSmartAlbums) {
    PHFetchResult<PHAssetCollection *> *smartAlbums =
    [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum
                                             subtype:PHAssetCollectionSubtypeAny
                                             options:nil];
    processCollections(smartAlbums, YES);
  }
  
  // 5️⃣ Sort descending by number of items
  [albums sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
    return [b[@"count"] compare:a[@"count"]];
  }];
  
  return albums;
}

+ (NSArray<PHAsset *> *)fetchPhotos:(NSString *)albumId
                               type:(NSString *)type
                            maxSize:(double)maxSize
                        maxDuration:(double)maxDuration
{
  NSMutableArray<PHAsset *> *result = [NSMutableArray array];

  // 1️⃣ Tìm album theo id
  PHFetchResult<PHAssetCollection *> *collections =
    [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[albumId]
                                                         options:nil];
  if (collections.count == 0) {
    return result;
  }

  PHAssetCollection *album = collections.firstObject;

  // 2️⃣ Filter theo type (image/video/all)
  PHFetchOptions *options = [PHFetchOptions new];
  if ([type isEqualToString:@"image"]) {
    options.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeImage];
  } else if ([type isEqualToString:@"video"]) {
    options.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeVideo];
  }

  // 3️⃣ Fetch assets trong album
  PHFetchResult<PHAsset *> *assets = [PHAsset fetchAssetsInAssetCollection:album options:options];

  // 4️⃣ Lọc theo maxSize / maxDuration
  [assets enumerateObjectsUsingBlock:^(PHAsset *asset, NSUInteger idx, BOOL *stop) {

    // Filter video duration
    if (asset.mediaType == PHAssetMediaTypeVideo && maxDuration > 0 && asset.duration > maxDuration) {
      return;
    }

    // Filter file size (approx via PHAssetResource)
    if (maxSize > 0) {
      NSArray *resources = [PHAssetResource assetResourcesForAsset:asset];
      PHAssetResource *res = resources.firstObject;
      long long fileSize = [[res valueForKey:@"fileSize"] longLongValue];
      if (fileSize > maxSize) {
        return;
      }
    }

    [result addObject:asset];
  }];

  // 5️⃣ Sort newest first
  [result sortUsingComparator:^NSComparisonResult(PHAsset *a, PHAsset *b) {
    return [b.creationDate compare:a.creationDate];
  }];

  return result;
}

@end
