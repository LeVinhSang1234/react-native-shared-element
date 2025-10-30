//
//  RCTGallerySelectionOverlay.h
//  GalleryPicker
//
//  Created by Sang Le vinh on 10/31/25.
//

#import <UIKit/UIKit.h>

@interface RCTGallerySelectionOverlay : UIView

@property (nonatomic, assign) BOOL selected;
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, assign) BOOL multipleEnabled;

- (void)setSelected:(BOOL)selected index:(NSInteger)index animated:(BOOL)animated;

@end
