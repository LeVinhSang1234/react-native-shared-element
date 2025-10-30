#import "RCTGalleryGridView.h"
#import "RCTGalleryGridItem.h"
#import "GalleryDataManager.h"
#import "RCTViewHelper.h"

@interface RCTGalleryGridView () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) UILabel *albumLabel;
@property (nonatomic, strong) UIImageView *chevronIcon;
@property (nonatomic, strong) UIButton *albumButton;
@property (nonatomic, strong) UIButton *multipleButton;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) PHCachingImageManager *imageManager;

@end

@implementation RCTGalleryGridView

#pragma mark - Init

- (instancetype)init {
  if (self = [super init]) {
    self.backgroundColor = UIColor.systemBackgroundColor;
    self.onSelects = nil;
    // 🔹 Album button (label + chevron)
    _albumButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _albumButton.backgroundColor = UIColor.clearColor;
    [_albumButton addTarget:self action:@selector(handleAlbumPress) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_albumButton];
    
    _albumLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _albumLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    _albumLabel.text = @"Recents";
    _albumLabel.textAlignment = NSTextAlignmentCenter;
    [_albumButton addSubview:_albumLabel];
    
    UIImageSymbolConfiguration *config =
    [UIImageSymbolConfiguration configurationWithPointSize:10 weight:UIImageSymbolWeightMedium];
    _chevronIcon = [[UIImageView alloc] initWithImage:
                    [UIImage systemImageNamed:@"chevron.down" withConfiguration:config]];
    _chevronIcon.tintColor = [UIColor labelColor];
    [_albumButton addSubview:_chevronIcon];
    
    // 🔹 Multiple button
    _multipleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_multipleButton setImage:[UIImage systemImageNamed:@"square.on.square"] forState:UIControlStateNormal];
    _multipleButton.tintColor = [UIColor labelColor];
    [_multipleButton addTarget:self action:@selector(toggleMultiple:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_multipleButton];
    
    // 🔹 Collection view
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.minimumLineSpacing = 1.0;
    layout.minimumInteritemSpacing = 1.0;
    
    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collectionView.backgroundColor = UIColor.clearColor;
    _collectionView.dataSource = self;
    _collectionView.delegate = self;
    [_collectionView registerClass:[RCTGalleryGridItem class] forCellWithReuseIdentifier:@"GalleryItem"];
    [self addSubview:_collectionView];
    
    [self updateTextColorForBackground:UIColor.systemBackgroundColor];
    
    _imageManager = [PHCachingImageManager new];
    _selectedAssets = [NSMutableArray new];
    _allowMultiple = NO;
    _multiple = NO;
  }
  return self;
}

#pragma mark - Layout

- (void)layoutSubviews {
  [super layoutSubviews];
  CGFloat headerHeight = 44.0;
  
  CGFloat albumWidth = [_albumLabel.text sizeWithAttributes:@{NSFontAttributeName:_albumLabel.font}].width + 18;
  _albumButton.frame = CGRectMake((self.bounds.size.width - albumWidth) / 2, 0, albumWidth, headerHeight);
  
  CGSize labelSize = [_albumLabel.text sizeWithAttributes:@{NSFontAttributeName:_albumLabel.font}];
  _albumLabel.frame = CGRectMake(0, 0, labelSize.width, headerHeight);
  _chevronIcon.frame = CGRectMake(CGRectGetMaxX(_albumLabel.frame) + 4, (headerHeight - 10)/2, 10, 10);
  
  _multipleButton.frame = CGRectMake(self.bounds.size.width - 52, 0, 44, headerHeight);
  
  CGFloat gridTop = headerHeight;
  _collectionView.frame = CGRectMake(0, gridTop, self.bounds.size.width, self.bounds.size.height - gridTop);
}

#pragma mark - Album Action

- (void)handleAlbumPress {
  NSLog(@"[Gallery] Album picker tapped");
}

#pragma mark - Property Setters

- (void)setAssets:(NSArray<PHAsset *> *)assets {
  _assets = assets;
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.collectionView reloadData];
  });
}

- (void)setAllowMultiple:(BOOL)allowMultiple {
  _allowMultiple = allowMultiple;
  _multipleButton.hidden = !allowMultiple;
  
  if (!allowMultiple) {
    _multiple = NO;
    [self updateCellsForMultipleState:NO];
  }
}

#pragma mark - Multiple Mode Toggle

- (void)toggleMultiple:(UIButton *)sender {
  if (!_allowMultiple) return;
  
  _multiple = !_multiple;
  _multipleButton.tintColor = _multiple ? UIColor.systemBlueColor : [UIColor labelColor];
  
  // 🟢 Nếu bật multiple khi đang chọn 1 ảnh single → giữ làm #1
  if (_multiple && _selectedAssets.count == 1) {
    PHAsset *first = _selectedAssets.firstObject;
    NSInteger idx = [_assets indexOfObject:first];
    if (idx != NSNotFound) {
      NSIndexPath *path = [NSIndexPath indexPathForItem:idx inSection:0];
      RCTGalleryGridItem *cell = (RCTGalleryGridItem *)[_collectionView cellForItemAtIndexPath:path];
      if (cell) {
        cell.multipleEnabled = YES;
        [cell setSelectedForUpload:YES index:1 animated:NO];
      }
    }
  }
  // 🔵 Nếu tắt multiple → giữ lại duy nhất ảnh đầu tiên
  else if (!_multiple && _selectedAssets.count > 1) {
    NSArray *removedAssets = [_selectedAssets subarrayWithRange:NSMakeRange(1, _selectedAssets.count - 1)];
    [_selectedAssets removeObjectsInArray:removedAssets];
    
    // 🔹 Cập nhật cell bị bỏ chọn (chỉ những ảnh từ thứ 2 trở đi)
    for (PHAsset *asset in removedAssets) {
      NSUInteger index = [_assets indexOfObject:asset];
      if (index != NSNotFound) {
        NSIndexPath *path = [NSIndexPath indexPathForItem:index inSection:0];
        RCTGalleryGridItem *cell = (RCTGalleryGridItem *)[_collectionView cellForItemAtIndexPath:path];
        if (cell) [cell setSelectedForUpload:NO index:0 animated:NO];
      }
    }
  }
  
  [self updateCellsForMultipleState:_multiple];
}

- (void)updateCellsForMultipleState:(BOOL)enabled {
  for (RCTGalleryGridItem *cell in _collectionView.visibleCells) {
    cell.multipleEnabled = enabled;
  }
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
  return _assets.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                           cellForItemAtIndexPath:(NSIndexPath *)indexPath {
  RCTGalleryGridItem *cell =
  [collectionView dequeueReusableCellWithReuseIdentifier:@"GalleryItem" forIndexPath:indexPath];
  
  PHAsset *asset = _assets[indexPath.item];
  
  CGFloat spacing = 1.0;
  CGFloat width = collectionView.bounds.size.width;
  CGFloat columns = width > 800 ? 6.0 : width > 600 ? 5.0 : 4.0;
  CGFloat totalSpacing = (columns - 1) * spacing;
  CGFloat itemWidth = floor((width - totalSpacing) / columns);
  CGFloat scale = UIScreen.mainScreen.scale;
  CGSize targetSize = CGSizeMake(itemWidth * scale, itemWidth * scale);
  
  PHImageRequestOptions *options = [PHImageRequestOptions new];
  options.deliveryMode = PHImageRequestOptionsDeliveryModeFastFormat;
  options.resizeMode = PHImageRequestOptionsResizeModeFast;
  options.networkAccessAllowed = NO;
  
  [_imageManager requestImageForAsset:asset
                           targetSize:targetSize
                          contentMode:PHImageContentModeAspectFill
                              options:options
                        resultHandler:^(UIImage *result, NSDictionary *info) {
    if (result) {
      dispatch_async(dispatch_get_main_queue(), ^{
        cell.asset = asset;
        cell.imageView.image = result;
        cell.multipleEnabled = self.multiple;
        
        NSInteger selectedIndex = [self->_selectedAssets indexOfObject:asset];
        BOOL isSelected = selectedIndex != NSNotFound;
        [cell setSelectedForUpload:isSelected
                             index:isSelected ? selectedIndex + 1 : 0
                          animated:NO];
      });
    }
  }];
  
  return cell;
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)layout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
  CGFloat spacing = 1.0;
  CGFloat width = collectionView.bounds.size.width;
  CGFloat columns = width > 800 ? 6.0 : width > 600 ? 5.0 : 4.0;
  CGFloat totalSpacing = (columns - 1) * spacing;
  CGFloat itemWidth = floor((width - totalSpacing) / columns);
  return CGSizeMake(itemWidth, itemWidth);
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
  PHAsset *asset = _assets[indexPath.item];
  BOOL wasSelected = [_selectedAssets containsObject:asset];
  RCTGalleryGridItem *cell = (RCTGalleryGridItem *)[collectionView cellForItemAtIndexPath:indexPath];
  
  if (_multiple) {
    if (wasSelected) {
      NSInteger removedIdx = [_selectedAssets indexOfObject:asset];
      [_selectedAssets removeObject:asset];
      [cell setSelectedForUpload:NO index:0 animated:YES];
      
      // Cập nhật lại thứ tự các ảnh sau khi bỏ chọn
      for (NSInteger i = removedIdx; i < _selectedAssets.count; i++) {
        PHAsset *next = _selectedAssets[i];
        NSIndexPath *p = [NSIndexPath indexPathForItem:[_assets indexOfObject:next] inSection:0];
        RCTGalleryGridItem *nextCell = (RCTGalleryGridItem *)[collectionView cellForItemAtIndexPath:p];
        if (nextCell) [nextCell setSelectedForUpload:YES index:i + 1 animated:NO];
      }
    } else {
      [_selectedAssets addObject:asset];
      [cell setSelectedForUpload:YES index:_selectedAssets.count animated:YES];
    }
  } else {
    PHAsset *previous = _selectedAssets.firstObject;
    
    // Nếu bấm lại cùng ảnh đã chọn => bỏ qua
    if (wasSelected && previous && [previous isEqual:asset]) {
      return;
    }
    
    [_selectedAssets removeAllObjects];
    [_selectedAssets addObject:asset];
    
    if (previous && ![previous isEqual:asset]) {
      NSUInteger prevIndex = [_assets indexOfObject:previous];
      if (prevIndex != NSNotFound) {
        NSIndexPath *prevPath = [NSIndexPath indexPathForItem:prevIndex inSection:0];
        RCTGalleryGridItem *prevCell =
        (RCTGalleryGridItem *)[collectionView cellForItemAtIndexPath:prevPath];
        if (prevCell) [prevCell setSelectedForUpload:NO index:0 animated:NO];
      }
    }
    [cell setSelectedForUpload:!wasSelected index:!wasSelected ? 1 : 0 animated:YES];
  }
  
  if (self.onSelects) {
    NSMutableArray *photos = [NSMutableArray new];
    
    for (PHAsset *a in _selectedAssets) {
      // Lấy thông tin cơ bản
      NSString *type = a.mediaType == PHAssetMediaTypeVideo ? @"video" : @"image";
      NSString *uri = [GalleryDataManager uriForAsset:a] ?: @"";
      
      // Lấy filename & extension chính xác
      NSArray *resources = [PHAssetResource assetResourcesForAsset:a];
      PHAssetResource *res = resources.firstObject;
      NSString *filename = res.originalFilename ?: @"";
      NSString *extension = [filename pathExtension];
      
      // Nếu thiếu extension thì fallback
      if (extension.length == 0) {
        if (a.mediaType == PHAssetMediaTypeImage) {
          extension = @"jpg";
        } else if (a.mediaType == PHAssetMediaTypeVideo) {
          extension = @"mov";
        }
      }
      
      // Build photo dictionary
      NSDictionary *photo = @{
        @"id": a.localIdentifier ?: @"",
        @"uri": uri,
        @"type": type,
        @"filename": filename ?: @"",
        @"extension": extension ?: @"",
        @"width": @(a.pixelWidth),
        @"height": @(a.pixelHeight),
        @"timestamp": a.creationDate ? @([a.creationDate timeIntervalSince1970] * 1000) : @0,
        @"duration": @(a.duration)
      };
      
      [photos addObject:photo];
    }
    
    // Emit event
    self.onSelects(photos);
  }
}

#pragma mark - Update Header Colors

- (UIColor *)contrastingColorForBackground:(UIColor *)background {
  CGFloat r = 0, g = 0, b = 0, a = 0;
  if (![background getRed:&r green:&g blue:&b alpha:&a]) {
    CGFloat white = 0;
    [background getWhite:&white alpha:&a];
    r = g = b = white;
  }
  CGFloat brightness = ((r * 299) + (g * 587) + (b * 114)) / 1000;
  return brightness < 0.6 ? UIColor.whiteColor : UIColor.blackColor;
}

- (void)updateTextColorForBackground:(UIColor *)bgColor {
  UIColor *textColor = [self contrastingColorForBackground:bgColor];
  _albumLabel.textColor = textColor;
  _chevronIcon.tintColor = textColor;
  _multipleButton.tintColor = textColor;
}

@end
