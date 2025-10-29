//
//  GalleryPhotoGridView.h
//  GalleryPicker
//
//  Created by Sang Lv on 30/10/25.
//

#import <UIKit/UIKit.h>

@interface GalleryPhotoGridView : UIView

// Danh sách PHAsset để hiển thị
@property (nonatomic, strong) NSArray *assets;

// Reload lại grid khi assets thay đổi
- (void)reloadData;

@end
