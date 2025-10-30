//
//  RCTGalleryGridItem.h
//  GalleryPicker
//
//  Created by Sang Le vinh on 10/30/25.
//


#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

NS_ASSUME_NONNULL_BEGIN

@interface RCTGalleryGridItem : UICollectionViewCell

@property (nonatomic, strong, readonly) UIImageView *imageView;
@property (nonatomic, strong, nullable) PHAsset *asset;

@property (nonatomic, assign) PHImageRequestID requestId;
@property (nonatomic, copy, nullable) NSString *representedAssetIdentifier;

// state dùng cho chọn upload
@property (nonatomic, assign) BOOL multipleEnabled;        // có đang ở chế độ multiple hay không
@property (nonatomic, assign) BOOL isSelectedForUpload;    // cell này đang được chọn hay chưa
@property (nonatomic, assign) NSInteger selectionIndex;    // thứ tự chọn (1,2,3...)

- (void)setSelectedForUpload:(BOOL)selected
                       index:(NSInteger)index
                    animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
