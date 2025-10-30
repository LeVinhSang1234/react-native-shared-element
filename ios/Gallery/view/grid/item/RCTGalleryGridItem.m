//
//  RCTGalleryGridItem.m
//  GalleryPicker
//
//  Created by Sang Le Vinh on 10/30/25.
//

#import "RCTGalleryGridItem.h"
#import "RCTViewHelper.h"
#import "RCTGalleryPreviewView.h"
#import "RCTGallerySelectionOverlay.h"

@interface RCTGalleryGridItem ()

// UI cho video
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) CAGradientLayer *bottomGradient;

// Overlay chọn (trắng mờ + vòng tròn + số)
@property (nonatomic, strong) RCTGallerySelectionOverlay *selectionOverlay;

// Preview control
@property (nonatomic, assign) BOOL isPreviewShowing;

@end

@implementation RCTGalleryGridItem

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    self.backgroundColor = UIColor.whiteColor;
    
    // Ảnh hiển thị trong cell
    _imageView = [[UIImageView alloc] initWithFrame:self.contentView.bounds];
    _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _imageView.contentMode = UIViewContentModeScaleAspectFill;
    _imageView.clipsToBounds = YES;
    _imageView.backgroundColor = [UIColor colorWithWhite:0.94 alpha:1.0];
    [self.contentView addSubview:_imageView];
    
    // Gradient đen mờ đáy (hiển thị duration video)
    _bottomGradient = [CAGradientLayer layer];
    _bottomGradient.colors = @[
      (__bridge id)[UIColor clearColor].CGColor,
      (__bridge id)[[UIColor blackColor] colorWithAlphaComponent:0.6].CGColor
    ];
    _bottomGradient.locations = @[@0.5, @1.0];
    [_imageView.layer addSublayer:_bottomGradient];
    _bottomGradient.hidden = YES;
    
    // Label thời lượng video
    _durationLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _durationLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightSemibold];
    _durationLabel.textColor = UIColor.whiteColor;
    _durationLabel.textAlignment = NSTextAlignmentRight;
    _durationLabel.backgroundColor = UIColor.clearColor;
    _durationLabel.hidden = YES;
    [_imageView addSubview:_durationLabel];
    
    // Overlay chọn
    _selectionOverlay = [[RCTGallerySelectionOverlay alloc] initWithFrame:self.contentView.bounds];
    _selectionOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_selectionOverlay setSelected:NO index:0 animated:NO];
    [self.contentView addSubview:_selectionOverlay];
    
    // Long press preview
    UILongPressGestureRecognizer *longPress =
    [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    [self.contentView addGestureRecognizer:longPress];
    
    _requestId = PHInvalidImageRequestID;
    _multipleEnabled = NO;
    _isSelectedForUpload = NO;
    _selectionIndex = 0;
    _isPreviewShowing = NO;
  }
  return self;
}

#pragma mark - Layout

- (void)layoutSubviews {
  [super layoutSubviews];
  
  // Gradient nằm 30% dưới cùng
  CGFloat gradientHeight = self.bounds.size.height * 0.3;
  CGFloat gradientY = self.bounds.size.height - gradientHeight;
  _bottomGradient.frame = CGRectMake(0, gradientY, self.bounds.size.width, gradientHeight);
  
  // Duration label ở góc phải dưới
  CGFloat labelHeight = 16;
  CGFloat padding = 5;
  CGFloat labelY = self.bounds.size.height - labelHeight - padding;
  CGFloat labelWidth = self.bounds.size.width - padding * 2;
  _durationLabel.frame = CGRectMake(padding, labelY, labelWidth, labelHeight);
}

#pragma mark - Asset Setup

- (void)setAsset:(PHAsset *)asset {
  _asset = asset;
  
  if (asset.mediaType == PHAssetMediaTypeVideo) {
    _bottomGradient.hidden = NO;
    _durationLabel.hidden = NO;
    _durationLabel.text = [self.class formatDuration:asset.duration];
  } else {
    _bottomGradient.hidden = YES;
    _durationLabel.hidden = YES;
  }
}

+ (NSString *)formatDuration:(NSTimeInterval)duration {
  NSInteger totalSeconds = (NSInteger)round(duration);
  NSInteger minutes = totalSeconds / 60;
  NSInteger seconds = totalSeconds % 60;
  return [NSString stringWithFormat:@"%ld:%02ld", (long)minutes, (long)seconds];
}

#pragma mark - Multiple Mode Control

- (void)setMultipleEnabled:(BOOL)multipleEnabled {
  _multipleEnabled = multipleEnabled;
  
  // thông báo xuống overlay để hiển thị vòng tròn/số khi cần
  _selectionOverlay.multipleEnabled = multipleEnabled;
  
  // không reset selection, chỉ sync lại UI
  [_selectionOverlay setSelected:_isSelectedForUpload
                           index:_isSelectedForUpload ? _selectionIndex : 0
                        animated:NO];
}

#pragma mark - Selection (Tap)

- (void)setSelectedForUpload:(BOOL)selected
                       index:(NSInteger)index
                    animated:(BOOL)animated
{
  _isSelectedForUpload = selected;
  _selectionIndex = index;
  
  _selectionOverlay.multipleEnabled = _multipleEnabled;
  [_selectionOverlay setSelected:selected
                           index:index
                        animated:(animated && selected && _multipleEnabled)];
}

#pragma mark - Preview (Long Press)

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
  // tắt preview nếu đang bật multiple
  if (_multipleEnabled) return;
  
  if (gesture.state == UIGestureRecognizerStateBegan &&
      _asset &&
      !_isPreviewShowing)
  {
    _isPreviewShowing = YES;
    
    UIImpactFeedbackGenerator *gen =
    [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen impactOccurred];
    
    CGRect frameInWindow = [RCTViewHelper frameInScreenStable:self];
    
    PHImageRequestOptions *options = [PHImageRequestOptions new];
    options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    options.networkAccessAllowed = YES;
    
    CGSize screenSize = UIScreen.mainScreen.bounds.size;
    PHCachingImageManager *manager = [PHCachingImageManager new];
    
    [manager requestImageForAsset:_asset
                       targetSize:screenSize
                      contentMode:PHImageContentModeAspectFit
                          options:options
                    resultHandler:^(UIImage *result, NSDictionary *info) {
      if (!result) {
        self.isPreviewShowing = NO;
        return;
      }
      
      dispatch_async(dispatch_get_main_queue(), ^{
        RCTGalleryPreviewView *preview =
        [[RCTGalleryPreviewView alloc] initWithImage:result
                                               asset:self.asset
                                            fromRect:frameInWindow
                                          originView:self];
        
        __weak typeof(self) weakSelf = self;
        preview.onDismiss = ^{
          weakSelf.isPreviewShowing = NO;
        };
        
        [preview showInWindow];
      });
    }];
  }
}

#pragma mark - Reuse

- (void)prepareForReuse {
  [super prepareForReuse];
  
  if (_requestId != PHInvalidImageRequestID) {
    [[PHImageManager defaultManager] cancelImageRequest:_requestId];
    _requestId = PHInvalidImageRequestID;
  }
  
  _asset = nil;
  _representedAssetIdentifier = nil;
  _durationLabel.text = @"";
  _isPreviewShowing = NO;
  _isSelectedForUpload = NO;
  _selectionIndex = 0;
  _imageView.image = nil;
  _bottomGradient.hidden = YES;
  _durationLabel.hidden = YES;
  
  [_selectionOverlay setSelected:NO index:0 animated:NO];
}

@end
