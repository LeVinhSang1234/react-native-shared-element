//
//  RCTGalleryView.m
//  GalleryPicker
//
//  Created by Sang Le vinh on 10/29/25.
//

#import "RCTGalleryView.h"
#import "GalleryDataManager.h"
#import "GalleryPhotoGridView.h"

#import <react/renderer/components/reactnativegallery/Props.h>
#import <react/renderer/components/reactnativegallery/ComponentDescriptors.h>
#import <react/renderer/components/reactnativegallery/EventEmitters.h>

using namespace facebook::react;

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


@interface RCTGalleryView()
@property (nonatomic, assign) BOOL hasPermission;        // Allow selecting multiple items
@property (nonatomic, assign) BOOL multiple;        // Allow selecting multiple items
@property (nonatomic, assign) double maxFiles;      // Maximum number of files selectable
@property (nonatomic, copy) NSString *type;         // "Image" | "Video" | "All"
@property (nonatomic, copy) NSString *albumType;         // "All" | "Album" | "SmartAlbum"
@property (nonatomic, assign) double maxSize;       // Maximum file size (bytes)
@property (nonatomic, assign) double maxDuration;   // Maximum video duration (seconds)
@property (nonatomic, assign) NSArray *albums;   // Maximum video duration (seconds)
@property (nonatomic, assign) NSDictionary *album;

@property (nonatomic, strong) GalleryPhotoGridView *photoGridView;


@end

@implementation RCTGalleryView

#pragma mark - Fabric
+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<GalleryComponentDescriptor>();
}

#pragma mark - Commands

- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args {
  if ([commandName isEqualToString:@"initialize"]) {
    [self initialize];
  }
}

- (instancetype)init {
  if(self = [super init]) {
    _photoGridView = [[GalleryPhotoGridView alloc] init];
    _photoGridView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:_photoGridView];
  }
  return self;
}

#pragma mark - Lifecycle

- (void)initialize {
  [GalleryDataManager requestPhotoPermission:^{
    self.hasPermission = YES;
    [self fetchDebounceAlbums];
  }
                                     onError:^(NSString *code, NSString *message) {
    [self sendOnErrorEvent:code message:message];
  }];
}

- (void)prepareForRecycle {
  [super prepareForRecycle];
}

- (void)didMoveToWindow {
  [super didMoveToWindow];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  _photoGridView.frame = self.bounds;
  NSLog(@"self.bounds %@", NSStringFromCGRect(self.bounds));
}

#pragma mark - React props / events

- (void)updateProps:(const Props::Shared &)props oldProps:(const Props::Shared &)oldProps
{
  const auto &newProps = *std::static_pointer_cast<const GalleryProps>(props);
  
  _multiple = newProps.multiple;
  _maxFiles = newProps.maxFiles;
  _type = [[NSString alloc] initWithUTF8String:newProps.type.c_str()];
  _maxSize = newProps.maxSize;
  _maxDuration = newProps.maxDuration;
  
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
  if (shouldFetch) [self fetchDebounceAlbums];
  
  [super updateProps:props oldProps:oldProps];
}

- (void)sendOnErrorEvent:(NSString *)code message:(NSString *)message {
  auto emitter = std::static_pointer_cast<const GalleryEventEmitter>(_eventEmitter);
  if (!emitter) return;
  facebook::react::GalleryEventEmitter::OnError event = {
    .code = ErrorCodeFromNSString(code),
    .message = std::string([message UTF8String])
  };
  emitter->onError(event);
}

- (void)fetchDebounceAlbums {
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fetchAlbums) object:nil];
  [self performSelector:@selector(fetchAlbums) withObject:nil afterDelay:0.05];
}

- (void)fetchAlbums {
  if(!_hasPermission) return;
  NSArray *albums = [GalleryDataManager fetchAlbums:_albumType type:_type];
  if(albums.count == 0) return;
  
  dispatch_async(dispatch_get_main_queue(), ^{
    self.albums = albums;
    self.album = self.albums.firstObject;
    NSString *albumId = self.album[@"id"];
    if (albumId.length == 0) return;
    [self fetchPhotosForAlbum:albumId];
  });
}

- (void)fetchPhotosForAlbum:(NSString *)albumId {
  NSArray<PHAsset *> *assets = [GalleryDataManager fetchPhotos:albumId
                                               type:_type
                                            maxSize:_maxSize
                                        maxDuration:_maxDuration];
  self.photoGridView.assets = assets;

  //  for (NSDictionary *photo in photos) {
  //    NSLog(@"[Photo] %@ (%@, %@x%@)",
  //          photo[@"id"],
  //          photo[@"type"],
  //          photo[@"width"],
  //          photo[@"height"]);
  //  }
}

@end




