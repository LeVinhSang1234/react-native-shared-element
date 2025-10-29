//
//  GalleryDataManager.m
//  GalleryPicker
//
//  Created by Sang Le vinh on 10/29/25.
//

#import "GalleryDataManager.h"

@implementation GalleryDataManager

+ (NSArray<NSDictionary *> *)fetchAlbums:(BOOL)includeSmart
                                    type:(NSString *)type {
  NSMutableArray *albums = [NSMutableArray array];
  
  void (^processCollection)(PHFetchResult<PHAssetCollection *> *) = ^(PHFetchResult<PHAssetCollection *> *collections) {
    for (PHAssetCollection *collection in collections) {
      if (collection.estimatedAssetCount == 0) continue;
      PHFetchOptions *options = [PHFetchOptions new];
      if ([type isEqualToString:@"image"]) {
        options.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeImage];
      } else if ([type isEqualToString:@"video"]) {
        options.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeVideo];
      }
      
      PHFetchResult<PHAsset *> *assets = [PHAsset fetchAssetsInAssetCollection:collection options:options];
      if (assets.count == 0) continue;
      
      [albums addObject:@{
        @"id": collection.localIdentifier ?: @"",
        @"title": collection.localizedTitle ?: @"",
        @"count": @(assets.count)
      }];
    }
  };
  
  PHFetchResult<PHAssetCollection *> *userAlbums =
  [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                           subtype:PHAssetCollectionSubtypeAny
                                           options:nil];
  processCollection(userAlbums);
  
  if (includeSmart) {
    PHFetchResult<PHAssetCollection *> *smartAlbums =
    [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum
                                             subtype:PHAssetCollectionSubtypeAny
                                             options:nil];
    processCollection(smartAlbums);
  }
  
  return albums;
}
@end
