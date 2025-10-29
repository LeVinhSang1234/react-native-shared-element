//
//  GalleryPhotoGridView.m
//  GalleryPicker
//
//  Created by Sang Lv on 30/10/25.
//

#import "GalleryPhotoGridView.h"
#import <Photos/Photos.h>

#pragma mark - GalleryPhotoCell

@interface GalleryPhotoCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *imageView;
@end

@implementation GalleryPhotoCell

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    self.backgroundColor = [UIColor whiteColor];

    _imageView = [[UIImageView alloc] initWithFrame:self.contentView.bounds];
    _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _imageView.contentMode = UIViewContentModeScaleAspectFill;
    _imageView.clipsToBounds = YES;
    _imageView.backgroundColor = [UIColor colorWithWhite:0.94 alpha:1.0]; // xám nhẹ cho đẹp

    [self.contentView addSubview:_imageView];
  }
  return self;
}

- (void)prepareForReuse {
  [super prepareForReuse];
  _imageView.image = nil;
  _imageView.backgroundColor = [UIColor colorWithWhite:0.94 alpha:1.0];
}

@end

#pragma mark - GalleryPhotoGridView

@interface GalleryPhotoGridView () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) PHCachingImageManager *imageManager;
@end

@implementation GalleryPhotoGridView

#pragma mark - Init & Layout

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    self.backgroundColor = [UIColor whiteColor];
    _imageManager = [PHCachingImageManager new];
  }
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];

  if (!_collectionView) {
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.minimumLineSpacing = 1.0;
    layout.minimumInteritemSpacing = 1.0;

    _collectionView = [[UICollectionView alloc] initWithFrame:self.bounds collectionViewLayout:layout];
    _collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _collectionView.backgroundColor = [UIColor whiteColor];
    _collectionView.dataSource = self;
    _collectionView.delegate = self;
    [_collectionView registerClass:[GalleryPhotoCell class] forCellWithReuseIdentifier:@"PhotoCell"];
    [self addSubview:_collectionView];
  } else {
    _collectionView.frame = self.bounds;
    [_collectionView.collectionViewLayout invalidateLayout]; // refresh khi xoay ngang
  }
}

#pragma mark - Public

- (void)setAssets:(NSArray<PHAsset *> *)assets {
  _assets = assets;
  [self reloadData];
}

- (void)reloadData {
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.collectionView reloadData];
  });
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
  return _assets.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                          cellForItemAtIndexPath:(NSIndexPath *)indexPath {
  GalleryPhotoCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"PhotoCell" forIndexPath:indexPath];
  PHAsset *asset = _assets[indexPath.item];

  // ✅ Kích thước thumbnail vừa khớp item (mờ nhanh)
  CGFloat scale = [UIScreen mainScreen].scale;
  CGFloat itemWidth = ((UICollectionViewFlowLayout *)collectionView.collectionViewLayout).itemSize.width;
  CGSize targetSize = CGSizeMake(itemWidth * scale, itemWidth * scale);

  PHImageRequestOptions *options = [PHImageRequestOptions new];
  options.deliveryMode = PHImageRequestOptionsDeliveryModeFastFormat; // chỉ thumbnail preview
  options.resizeMode = PHImageRequestOptionsResizeModeFast;
  options.networkAccessAllowed = YES; // tránh ảnh trắng khi ở iCloud

  __block PHImageRequestID requestId = 0; // khởi tạo = 0
  requestId = [_imageManager requestImageForAsset:asset
                                      targetSize:targetSize
                                     contentMode:PHImageContentModeAspectFill
                                         options:options
                                   resultHandler:^(UIImage *result, NSDictionary *info) {
      if (result) {
          dispatch_async(dispatch_get_main_queue(), ^{
              cell.imageView.image = result;
          });
      } else {
          dispatch_async(dispatch_get_main_queue(), ^{
              cell.imageView.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
          });
      }

      // ✅ Hủy request sau khi frame đầu tiên
      [self.imageManager cancelImageRequest:requestId];
  }];

  return cell;
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)layout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
  CGFloat spacing = 1.0;
  CGFloat width = collectionView.bounds.size.width;
  CGFloat columns = 4.0;

  if (width >= 1000) {
    columns = 6.0;
  } else if (width >= 700) {
    columns = 5.0;
  }

  CGFloat totalSpacing = (columns - 1) * spacing;
  CGFloat itemWidth = floor((width - totalSpacing) / columns);
  return CGSizeMake(itemWidth, itemWidth);
}

@end
