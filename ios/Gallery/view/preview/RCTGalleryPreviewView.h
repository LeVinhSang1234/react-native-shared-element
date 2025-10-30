//
//  RCTGalleryPreviewView.h
//  GalleryPicker
//
//  Created by Sang Le vinh on 10/30/25.
//

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

NS_ASSUME_NONNULL_BEGIN

@interface RCTGalleryPreviewView : UIView

@property (nonatomic, strong, readonly) UIImageView *imageView;
@property (nonatomic, copy, nullable) void (^onDismiss)(void);

/// Khởi tạo với ảnh, frame gốc và view gốc (để ẩn khi preview)
- (instancetype)initWithImage:(nullable UIImage *)image
                        asset:(nullable PHAsset *)asset
                     fromRect:(CGRect)originFrame
                   originView:(UIView *)originView;

/// Hiển thị preview (hiệu ứng nổi + phóng to liền mạch)
- (void)showInWindow;

/// Đóng preview (có animation)
- (void)dismissWithAnimation:(BOOL)animated;


@end

NS_ASSUME_NONNULL_END
