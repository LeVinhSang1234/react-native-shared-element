//
//  RCTGallerySelectionOverlay.m
//  GalleryPicker
//
//  Created by Sang Le vinh on 10/31/25.
//
//

#import "RCTGallerySelectionOverlay.h"

@interface RCTGallerySelectionOverlay ()
@property (nonatomic, strong) UIView *overlayView;
@property (nonatomic, strong) UIView *circleView;
@property (nonatomic, strong) UILabel *indexLabel;
@end

@implementation RCTGallerySelectionOverlay

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    self.backgroundColor = UIColor.clearColor;
    
    // lớp phủ trắng mờ
    _overlayView = [[UIView alloc] initWithFrame:self.bounds];
    _overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _overlayView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.35];
    _overlayView.hidden = YES; // ❗ chỉ hiện khi được chọn
    [self addSubview:_overlayView];
    
    // vòng tròn
    _circleView = [[UIView alloc] initWithFrame:CGRectMake(frame.size.width - 26, 6, 24, 24)];
    _circleView.layer.cornerRadius = 12;
    _circleView.layer.borderWidth = 1.5;
    _circleView.layer.borderColor = UIColor.whiteColor.CGColor;
    _circleView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
    _circleView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self addSubview:_circleView];
    
    // số thứ tự
    _indexLabel = [[UILabel alloc] initWithFrame:_circleView.bounds];
    _indexLabel.textAlignment = NSTextAlignmentCenter;
    _indexLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    _indexLabel.textColor = UIColor.whiteColor;
    _indexLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_circleView addSubview:_indexLabel];
  }
  return self;
}

- (void)setSelected:(BOOL)selected index:(NSInteger)index animated:(BOOL)animated {
  // overlay luôn hiển thị khi được chọn (kể cả single)
  _overlayView.hidden = !selected;

  // Nếu multipleEnabled thì hiển thị circle + số đếm
  if (_multipleEnabled) {
    _circleView.hidden = NO;
    _indexLabel.text = selected ? [NSString stringWithFormat:@"%ld", (long)index] : @"";
    
    if (selected) {
      _circleView.backgroundColor = UIColor.systemBlueColor;
      _circleView.layer.borderColor = UIColor.systemBlueColor.CGColor;
    } else {
      _circleView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
      _circleView.layer.borderColor = UIColor.whiteColor.CGColor;
    }
  } else {
    // Single mode → ẩn circle
    _circleView.hidden = YES;
    _indexLabel.text = @"";
  }

  // Animation chỉ áp dụng cho cell đang được chọn
  if (animated && selected && _multipleEnabled) {
    [UIView animateWithDuration:0.15 animations:^{
      self.circleView.transform = CGAffineTransformMakeScale(1.25, 1.25);
    } completion:^(BOOL finished) {
      [UIView animateWithDuration:0.15 animations:^{
        self.circleView.transform = CGAffineTransformIdentity;
      }];
    }];
  }
}

@end
