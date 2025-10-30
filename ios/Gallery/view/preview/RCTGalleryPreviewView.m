//
//  RCTGalleryPreviewView.m
//  GalleryPicker
//
//  Created by Sang Lv on 31/10/25.
//

#import "RCTGalleryPreviewView.h"
#import "RCTViewHelper.h"
#import <AVFoundation/AVFoundation.h>

@interface RCTGalleryPreviewView () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) PHAsset *asset;
@property (nonatomic, assign) CGRect originFrame;
@property (nonatomic, assign) CGSize imageSize;
@property (nonatomic, assign) BOOL isDismissing;
@property (nonatomic, weak) UIView *originView;
@end

@implementation RCTGalleryPreviewView

#pragma mark - Init

- (instancetype)initWithImage:(nullable UIImage *)image
                        asset:(nullable PHAsset *)asset
                     fromRect:(CGRect)originFrame
                   originView:(UIView *)originView {
  if (self = [super initWithFrame:UIScreen.mainScreen.bounds]) {
    _asset = asset;
    _originFrame = originFrame;
    _originView = originView;
    _imageSize = image ? image.size : CGSizeMake(1080, 1080);
    _isDismissing = NO;
    self.backgroundColor = UIColor.clearColor;
    
    // Blur nền mỏng để nhìn xuyên nhẹ
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
    _blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    _blurView.frame = self.bounds;
    _blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _blurView.alpha = 0.0;
    [self addSubview:_blurView];
    
    if (asset && asset.mediaType == PHAssetMediaTypeVideo) {
      // ⚙️ Video preview
      [self setupVideoPreviewFrom:asset placeholder:image];
    } else {
      // ⚙️ Ảnh preview
      _imageView = [[UIImageView alloc] initWithFrame:originFrame];
      _imageView.image = image;
      _imageView.contentMode = UIViewContentModeScaleAspectFill;
      _imageView.clipsToBounds = YES;
      _imageView.layer.cornerRadius = 0.0;
      _imageView.layer.masksToBounds = YES;
      [self addSubview:_imageView];
    }
    
    // tap để đóng
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDismiss)];
    [self addGestureRecognizer:tap];
    
    // pan để vuốt xuống
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    pan.delegate = self;
    [self addGestureRecognizer:pan];
  }
  return self;
}

#pragma mark - Video setup

- (void)setupVideoPreviewFrom:(PHAsset *)asset placeholder:(UIImage *)placeholder {
  // Ảnh placeholder ban đầu
  _imageView = [[UIImageView alloc] initWithFrame:_originFrame];
  _imageView.image = placeholder;
  _imageView.contentMode = UIViewContentModeScaleAspectFill;
  _imageView.clipsToBounds = YES;
  [self addSubview:_imageView];
  
  // Tạo player trước nhưng chưa show (opacity 0)
  PHVideoRequestOptions *options = [PHVideoRequestOptions new];
  options.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
  options.networkAccessAllowed = YES;
  
  [[PHImageManager defaultManager] requestPlayerItemForVideo:asset
                                                     options:options
                                               resultHandler:^(AVPlayerItem * _Nullable playerItem, NSDictionary * _Nullable info) {
    dispatch_async(dispatch_get_main_queue(), ^{
      self.player = [AVPlayer playerWithPlayerItem:playerItem];
      self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
      self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
      self.playerLayer.frame = self->_imageView.frame;
      self.playerLayer.opacity = 0.0; // bắt đầu ẩn
      [self.layer insertSublayer:self.playerLayer above:self.imageView.layer];
      
      // cùng transform scale 1.12
      self.playerLayer.transform = CATransform3DMakeScale(1.12, 1.12, 1.0);
      
      // Quan sát player ready để fade in mượt
      [self.player addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
      [self.player play];
    });
  }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
  if ([keyPath isEqualToString:@"status"] && self.player.status == AVPlayerStatusReadyToPlay) {
    // 🔹 fade-in player mượt cùng lúc ảnh mờ vẫn còn
    [UIView animateWithDuration:0.25 animations:^{
      self.playerLayer.opacity = 1.0; // player hiện dần
    } completion:^(BOOL finished) {
      // 🔹 sau khi video hiển thị ổn, fade-out ảnh mờ nhẹ
      [UIView animateWithDuration:0.15 animations:^{
        self.imageView.alpha = 0.0;
      } completion:^(BOOL done) {
        [self.imageView removeFromSuperview];
        self.imageView = nil;
        [self.player removeObserver:self forKeyPath:@"status"];
      }];
    }];
  }
}

#pragma mark - Show

- (void)showInWindow {
  UIWindow *window = [RCTViewHelper getTargetWindow];
  if (!window) return;
  
  _originView.alpha = 0.0; // ẩn item gốc
  
  [window addSubview:self];
  CGRect targetFrame = [self targetFrameForImage:_imageSize];
  
  // Giai đoạn 1: nổi lên nhẹ
  [UIView animateWithDuration:0.3
                        delay:0
                      options:UIViewAnimationOptionCurveEaseOut
                   animations:^{
    if (self.imageView) {
      self.imageView.transform = CGAffineTransformMakeScale(1.15, 1.15);
      self.imageView.layer.cornerRadius = 4.0;
    }
    if (self.playerLayer) {
      self.playerLayer.affineTransform = CGAffineTransformMakeScale(1.15, 1.15);
      self.playerLayer.cornerRadius = 4.0;
    }
  } completion:^(BOOL finished) {
    [self animateToFullScreen:targetFrame];
  }];
}

- (void)animateToFullScreen:(CGRect)targetFrame {
  [UIView animateWithDuration:0.35
                        delay:0
       usingSpringWithDamping:0.85
        initialSpringVelocity:0.7
                      options:UIViewAnimationOptionCurveEaseOut
                   animations:^{
    self.blurView.alpha = 1.0;
    if (self.imageView) {
      self.imageView.frame = targetFrame;
      self.imageView.layer.cornerRadius = 16.0;
      self.imageView.transform = CGAffineTransformIdentity;
    }
    if (self.playerLayer) {
      self.playerLayer.frame = targetFrame;
      self.playerLayer.cornerRadius = 16.0;
      self.playerLayer.masksToBounds = YES;
      self.playerLayer.affineTransform = CGAffineTransformIdentity;
    }
  } completion:nil];
}

#pragma mark - Dismiss

- (void)dismissWithAnimation:(BOOL)animated {
  if (_isDismissing) return;
  _isDismissing = YES;
  
  void (^cleanup)(void) = ^{
    self.originView.alpha = 1.0;
    [self.player pause];
    [self removeFromSuperview];
  };
  
  if (!animated) {
    cleanup();
    return;
  }
  
  [UIView animateWithDuration:0.3
                        delay:0
       usingSpringWithDamping:1.0
        initialSpringVelocity:0.7
                      options:UIViewAnimationOptionCurveEaseIn
                   animations:^{
    self.blurView.alpha = 0.0;
    if (self.imageView) {
      self.imageView.frame = self.originFrame;
      self.imageView.layer.cornerRadius = 0.0;
    }
    if (self.playerLayer) {
      self.playerLayer.frame = self.originFrame;
      self.playerLayer.cornerRadius = 0.0;
    }
  } completion:^(BOOL finished) {
    cleanup();
    if (self.onDismiss) self.onDismiss();
  }];
}

#pragma mark - Gestures

- (void)handleDismiss {
  [self dismissWithAnimation:YES];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
  CGPoint translation = [gesture translationInView:self];
  CGFloat progress = translation.y / self.bounds.size.height;
  
  if (gesture.state == UIGestureRecognizerStateChanged) {
    if (translation.y > 0) {
      // 🔹 scale + translate đồng thời
      CGFloat scale = MAX(0.85, 1 - progress * 0.3);
      CGAffineTransform translate = CGAffineTransformMakeTranslation(0, translation.y / 2);
      CGAffineTransform transform = CGAffineTransformScale(translate, scale, scale);
      self.imageView.transform = transform;
      self.playerLayer.affineTransform = transform; // nếu đang là video thì player cũng di chuyển theo
      
      self.blurView.alpha = MAX(0.0, 1 - progress * 2);
    }
  } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
    if (translation.y > 120) {
      [self dismissWithAnimation:YES];
    } else {
      [UIView animateWithDuration:0.25
                            delay:0
           usingSpringWithDamping:0.85
            initialSpringVelocity:0.7
                          options:UIViewAnimationOptionCurveEaseOut
                       animations:^{
        // 🔹 reset về giữa màn hình
        self.imageView.transform = CGAffineTransformIdentity;
        self.playerLayer.affineTransform = CGAffineTransformIdentity;
        self.blurView.alpha = 1.0;
      } completion:nil];
    }
  }
}

#pragma mark - Helpers

- (CGRect)targetFrameForImage:(CGSize)size {
  CGSize screen = UIScreen.mainScreen.bounds.size;
  CGFloat maxW = screen.width;
  CGFloat maxH = screen.height * 0.8;
  CGFloat aspect = size.width / size.height;
  
  CGFloat width = maxW;
  CGFloat height = width / aspect;
  if (height > maxH) {
    height = maxH;
    width = height * aspect;
  }
  
  CGFloat x = (screen.width - width) / 2.0;
  CGFloat y = (screen.height - height) / 2.0;
  return CGRectMake(x, y, width, height);
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
  return YES;
}

@end
