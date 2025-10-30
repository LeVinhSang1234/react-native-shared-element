//
//  GalleryDataManager.h
//  GalleryPicker
//
//  Created by Sang Le vinh on 10/29/25.
//
#import <Foundation/Foundation.h>
#import <Photos/Photos.h>

@interface GalleryDataManager : NSObject
+ (NSArray<NSDictionary *> *)fetchAlbums:(NSString *)albumType
                                    type:(NSString *)type;

/// Request permission to access Photos library.
/// Calls `onGranted` on main thread when authorized or limited.
/// Calls `onError` on main thread when denied or restricted.
+ (void)requestPhotoPermission:(void (^)(void))onGranted
                       onError:(void (^)(NSString *code, NSString *message))onError;

+ (NSArray<PHAsset *> *)fetchPhotos:(NSString *)albumId
                                    type:(NSString *)type
                                 maxSize:(double)maxSize
                             maxDuration:(double)maxDuration;

+ (NSString *)uriForAsset:(PHAsset *)asset;

+ (void)clearCache;

@end
