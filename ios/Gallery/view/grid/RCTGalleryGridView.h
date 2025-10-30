//
//  RCTGalleryGridView.h
//  GalleryPicker
//
//  Created by Sang Lv on 01/11/25.
//

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

NS_ASSUME_NONNULL_BEGIN

@interface RCTGalleryGridView : UIView

/// Danh sách asset (ảnh/video) trong album hiện tại
@property (nonatomic, strong) NSArray<PHAsset *> *assets;

/// Danh sách asset đã được chọn (khi bật multiple)
@property (nonatomic, strong, readonly) NSMutableArray<PHAsset *> *selectedAssets;

/// Cho phép bật chế độ multiple (ẩn/hiện nút toggle)
@property (nonatomic, assign) BOOL allowMultiple;

/// Trạng thái hiện tại có đang bật multiple hay không
@property (nonatomic, assign) BOOL multiple;

/// Quản lý bộ sưu tập ảnh
@property (nonatomic, strong, readonly) UICollectionView *collectionView;

@property (nonatomic, copy, nullable) void (^onSelects)(NSArray<NSDictionary *> *photos);

/// Đặt lại tiêu đề album hiển thị trên header
@property (nonatomic, copy) NSString *albumTitle;

- (void)updateTextColorForBackground:(UIColor *)bgColor;

- (void)updateCellsForMultipleState:(BOOL)enabled;

@end

NS_ASSUME_NONNULL_END
