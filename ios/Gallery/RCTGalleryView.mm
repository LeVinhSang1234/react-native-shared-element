//
//  RCTGalleryView.m
//  GalleryPicker
//
//  Created by Sang Le Vinh on 10/29/25.
//

#import "RCTGalleryView.h"
#import "GalleryDataManager.h"
#import "RCTGalleryGridView.h"

#import <Photos/Photos.h>
#import <react/renderer/components/reactnativegallery/Props.h>
#import <react/renderer/components/reactnativegallery/ComponentDescriptors.h>
#import <react/renderer/components/reactnativegallery/EventEmitters.h>
#import <React/RCTConversions.h>

using namespace facebook::react;

#pragma mark - Error Mapping

static facebook::react::GalleryEventEmitter::OnErrorCode
ErrorCodeFromNSString(NSString *code) {
  using Code = facebook::react::GalleryEventEmitter::OnErrorCode;
  if ([code isEqualToString:@"NOT_DETERMINED"]) return Code::NOT_DETERMINED;
  if ([code isEqualToString:@"RESTRICTED"])     return Code::RESTRICTED;
  if ([code isEqualToString:@"DENIED"])         return Code::DENIED;
  if ([code isEqualToString:@"AUTHORIZED"])     return Code::AUTHORIZED;
  if ([code isEqualToString:@"LIMITED"])        return Code::LIMITED;
  return Code::UNKNOWN;
}

#pragma mark - Interface

@interface RCTGalleryView () <PHPhotoLibraryChangeObserver>

@property (nonatomic, assign) BOOL hasPermission;
@property (nonatomic, assign) BOOL allowMultiple;
@property (nonatomic, assign) double maxFiles;
@property (nonatomic, assign) double maxSize;
@property (nonatomic, assign) double maxDuration;

@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy) NSString *albumType;

@property (nonatomic, strong) NSArray *albums;
@property (nonatomic, strong) NSDictionary *album;
@property (nonatomic, copy) NSString *currentAlbumId;
@property (nonatomic, strong) PHFetchResult<PHAsset *> *currentFetchResult;

@property (nonatomic, strong) RCTGalleryGridView *photoGridView;

@end


@implementation RCTGalleryView

#pragma mark - Fabric Setup

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<GalleryComponentDescriptor>();
}

#pragma mark - Init & Lifecycle

- (instancetype)init {
  if (self = [super init]) {
    _photoGridView = [[RCTGalleryGridView alloc] init];
    _photoGridView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:_photoGridView];
  }
  return self;
}

- (void)dealloc {
  [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
}

#pragma mark - Layout

- (void)layoutSubviews {
  [super layoutSubviews];
  _photoGridView.frame = self.bounds;
}

#pragma mark - Commands

- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args {
  if ([commandName isEqualToString:@"initialize"]) {
    [self initialize];
  }
}

#pragma mark - Initialization & Permissions

- (void)initialize {
  [GalleryDataManager requestPhotoPermission:^{
    self.hasPermission = YES;
    [self fetchDebounceAlbums];
  } onError:^(NSString *code, NSString *message) {
    [self sendOnErrorEvent:code message:message];
  }];
}

- (void)prepareForRecycle {
  [super prepareForRecycle];
  
  _albums = nil;
  _album = nil;
  _currentAlbumId = nil;
  _currentFetchResult = nil;
  
  // 🧹 Clear grid state (no need to reload)
  _photoGridView.assets = @[];
  [_photoGridView.selectedAssets removeAllObjects];
  _photoGridView.allowMultiple = NO;
  _photoGridView.multiple = NO;
  
  // 🧹 Optionally clear temporary cache
  [GalleryDataManager clearCache];
}

#pragma mark - Props Update

- (void)updateProps:(const Props::Shared &)props oldProps:(const Props::Shared &)oldProps {
  const auto &newProps = *std::static_pointer_cast<const GalleryProps>(props);
  
  NSString *newType = [[NSString alloc] initWithUTF8String:newProps.type.c_str()];
  NSString *newAlbumType = [[NSString alloc] initWithUTF8String:newProps.albumType.c_str()];
  BOOL shouldFetch = NO;
  
  if (![_type isEqualToString:newType]) {
    _type = newType;
    shouldFetch = YES;
  }
  if (![_albumType isEqualToString:newAlbumType]) {
    _albumType = newAlbumType;
    shouldFetch = YES;
  }
  
  _allowMultiple = newProps.allowMultiple;
  _maxFiles = newProps.maxFiles;
  _maxSize = newProps.maxSize;
  _maxDuration = newProps.maxDuration;
  
  // 🔹 Truyền trạng thái multiple xuống GridView
  _photoGridView.allowMultiple = _allowMultiple;
  
  if (newProps.allowOnSelects && _photoGridView.onSelects == nil) {
    __weak __typeof__(self) weakSelf = self;
    _photoGridView.onSelects = ^(NSArray<NSDictionary *> *photos) {
      [weakSelf emitOnSelectsEventWithPhotos:photos];
    };
  } else if(_photoGridView.onSelects){
    _photoGridView.onSelects = nil;
  }
  
  if (shouldFetch) {
    [_photoGridView.selectedAssets removeAllObjects];
    [self fetchDebounceAlbums];
  }
  
  // 🔹 Cập nhật background & header color
  UIColor *newBgColor = RCTUIColorFromSharedColor(newProps.backgroundColor);
  if (!newBgColor) {
    newBgColor = UIColor.systemBackgroundColor;
  }
  UIColor *currentBgColor = _photoGridView.backgroundColor ?: UIColor.clearColor;
  
  // Chỉ cập nhật nếu khác màu hiện tại
  if (![currentBgColor isEqual:newBgColor]) {
    _photoGridView.backgroundColor = newBgColor;
    [_photoGridView updateTextColorForBackground:newBgColor];
  }
  
  [super updateProps:props oldProps:oldProps];
}

#pragma mark - Error Handling

- (void)sendOnErrorEvent:(NSString *)code message:(NSString *)message {
  auto emitter = std::static_pointer_cast<const GalleryEventEmitter>(_eventEmitter);
  if (!emitter) return;
  
  facebook::react::GalleryEventEmitter::OnError event = {
    .code = ErrorCodeFromNSString(code),
    .message = std::string([message UTF8String])
  };
  emitter->onError(event);
}

#pragma mark - Album Fetching

- (void)fetchDebounceAlbums {
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fetchAlbums) object:nil];
  [self performSelector:@selector(fetchAlbums) withObject:nil afterDelay:0.05];
}

- (void)fetchAlbums {
  if (!_hasPermission) return;
  
  NSArray *albums = [GalleryDataManager fetchAlbums:_albumType type:_type];
  if (albums.count == 0) return;
  
  dispatch_async(dispatch_get_main_queue(), ^{
    self.albums = albums;
    self.album = self.albums.firstObject;
    [self fetchPhotosForAlbum:self.album[@"id"]];
  });
}

#pragma mark - Photo Fetching

- (void)fetchPhotosForAlbum:(NSString *)albumId {
  if (!albumId) return;
  
  // 🔹 Tìm album tương ứng
  NSDictionary *albumDict = nil;
  for (NSDictionary *dict in _albums) {
    if ([dict[@"id"] isEqualToString:albumId]) {
      albumDict = dict;
      break;
    }
  }
  if (!albumDict) return;
  
  PHAssetCollection *collection = albumDict[@"collection"];
  if (!collection) return;
  
  // 🔹 Nếu đổi album → bỏ đăng ký cũ
  if (![_currentAlbumId isEqualToString:albumId]) {
    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
    _currentAlbumId = albumId;
  }
  
  // 🔹 Fetch option: sort + filter theo type
  PHFetchOptions *options = [PHFetchOptions new];
  options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
  
  if ([_type isEqualToString:@"image"]) {
    options.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeImage];
  } else if ([_type isEqualToString:@"video"]) {
    options.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeVideo];
  } else {
    options.predicate = nil; // "All" hoặc rỗng
  }
  
  // 🔹 Lấy danh sách asset
  _currentFetchResult = [PHAsset fetchAssetsInAssetCollection:collection options:options];
  
  NSMutableArray<PHAsset *> *assets = [NSMutableArray arrayWithCapacity:_currentFetchResult.count];
  [_currentFetchResult enumerateObjectsUsingBlock:^(PHAsset *asset, NSUInteger idx, BOOL *stop) {
    [assets addObject:asset];
  }];
  
  // 🔹 Gán vào grid
  dispatch_async(dispatch_get_main_queue(), ^{
    self.photoGridView.assets = assets;
  });
  
  // 🔹 Theo dõi thay đổi realtime
  [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
}

#pragma mark - Realtime Photo Library Updates

- (void)photoLibraryDidChange:(PHChange *)changeInstance {
  if (!_currentFetchResult) return;
  
  PHFetchResultChangeDetails *details =
  [changeInstance changeDetailsForFetchResult:_currentFetchResult];
  if (!details) return;
  
  dispatch_async(dispatch_get_main_queue(), ^{
    self.currentFetchResult = [details fetchResultAfterChanges];
    
    NSMutableArray *assets = [NSMutableArray new];
    [self.currentFetchResult enumerateObjectsUsingBlock:^(PHAsset *asset, NSUInteger idx, BOOL *stop) {
      [assets addObject:asset];
    }];
    self.photoGridView.assets = assets;
    
    if (![details hasIncrementalChanges] || [details hasMoves]) {
      [self.photoGridView.collectionView reloadData];
      return;
    }
    
    BOOL hasInsert = details.insertedIndexes.count > 0;
    BOOL hasRemove = details.removedIndexes.count > 0;
    BOOL hasChange = details.changedIndexes.count > 0;
    
    if ((hasInsert && hasRemove) || (hasInsert && hasChange) || (hasRemove && hasChange)) {
      [self.photoGridView.collectionView reloadData];
      return;
    }
    
    [self.photoGridView.collectionView performBatchUpdates:^{
      if (hasInsert) {
        NSMutableArray<NSIndexPath *> *inserted = [NSMutableArray new];
        [details.insertedIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
          [inserted addObject:[NSIndexPath indexPathForItem:idx inSection:0]];
        }];
        [self.photoGridView.collectionView insertItemsAtIndexPaths:inserted];
      } else if (hasRemove) {
        NSMutableArray<NSIndexPath *> *removed = [NSMutableArray new];
        [details.removedIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
          [removed addObject:[NSIndexPath indexPathForItem:idx inSection:0]];
        }];
        [self.photoGridView.collectionView deleteItemsAtIndexPaths:removed];
      } else if (hasChange) {
        NSMutableArray<NSIndexPath *> *changed = [NSMutableArray new];
        [details.changedIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
          [changed addObject:[NSIndexPath indexPathForItem:idx inSection:0]];
        }];
        [self.photoGridView.collectionView reloadItemsAtIndexPaths:changed];
      }
    } completion:nil];
  });
}

#pragma mark - JS Event Emitters
- (void)emitOnSelectsEventWithPhotos:(NSArray<NSDictionary *> *)photos {
  if (!_eventEmitter) return;
  
  auto emitter = std::static_pointer_cast<const facebook::react::GalleryEventEmitter>(_eventEmitter);
  if (!emitter) return;
  
  // 🔹 Convert NSArray<NSDictionary *> → std::vector<OnSelectsPhotos>
  std::vector<facebook::react::GalleryEventEmitter::OnSelectsPhotos> photoList;
  photoList.reserve(photos.count);
  
  for (NSDictionary *dict in photos) {
    facebook::react::GalleryEventEmitter::OnSelectsPhotos photo{};
    
    // Required fields
    photo.id = std::string([[dict objectForKey:@"id"] UTF8String]);
    photo.uri = std::string([[dict objectForKey:@"uri"] UTF8String]);
    photo.type = std::string([[dict objectForKey:@"type"] UTF8String]);
    
    // Optional numeric fields
    if (dict[@"width"]) photo.width = [dict[@"width"] doubleValue];
    if (dict[@"height"]) photo.height = [dict[@"height"] doubleValue];
    if (dict[@"size"]) photo.size = [dict[@"size"] doubleValue];
    if (dict[@"duration"]) photo.duration = [dict[@"duration"] doubleValue];
    if (dict[@"timestamp"]) photo.timestamp = [dict[@"timestamp"] doubleValue];
    if (dict[@"orientation"]) photo.orientation = [dict[@"orientation"] doubleValue];
    
    // Optional strings
    if (dict[@"filename"]) photo.filename = std::string([[dict objectForKey:@"filename"] UTF8String]);
    if (dict[@"extension"]) photo.extension = std::string([[dict objectForKey:@"extension"] UTF8String]);
    
    // Optional nested location
    NSDictionary *loc = dict[@"location"];
    if (loc && loc != (id)[NSNull null]) {
      photo.location = facebook::react::GalleryEventEmitter::OnSelectsPhotosLocation{
        [loc[@"latitude"] doubleValue],
        [loc[@"longitude"] doubleValue]
      };
    }
    
    photoList.push_back(photo);
  }
  
  // 🔹 Emit sang JS
  facebook::react::GalleryEventEmitter::OnSelects event = {
    .photos = std::move(photoList)
  };
  
  emitter->onSelects(event);
}

@end
