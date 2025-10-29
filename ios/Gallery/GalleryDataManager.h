//
//  GalleryDataManager.h
//  GalleryPicker
//
//  Created by Sang Le vinh on 10/29/25.
//
#import <Foundation/Foundation.h>
#import <Photos/Photos.h>

@interface GalleryDataManager : NSObject
+ (NSArray<NSDictionary *> *)fetchAlbums:(BOOL)includeSmart
                                    type:(NSString *)type;

+ (void)requestPhotoPermission:(void (^)(void))onGranted;

@end
