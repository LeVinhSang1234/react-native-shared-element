//
//  RCTGalleryView.m
//  GalleryPicker
//
//  Created by Sang Le vinh on 10/29/25.
//

#import "RCTGalleryView.h"

#import <react/renderer/components/reactnativegallery/Props.h>
#import <react/renderer/components/reactnativegallery/ComponentDescriptors.h>

using namespace facebook::react;

@interface RCTGalleryView()
@property (nonatomic, assign) BOOL multiple;        // Allow selecting multiple items
@property (nonatomic, assign) double maxFiles;      // Maximum number of files selectable
@property (nonatomic, copy) NSString *type;         // "image" | "video" | "all"
@property (nonatomic, assign) double maxSize;       // Maximum file size (bytes)
@property (nonatomic, assign) double maxDuration;   // Maximum video duration (seconds)
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
  if(self = [super init]) {}
  return self;
}

- (void)initialize {
  
}

- (void)updateProps:(const Props::Shared &)props oldProps:(const Props::Shared &)oldProps
{
  const auto &newProps = *std::static_pointer_cast<const GalleryProps>(props);
  
  _multiple = newProps.multiple;
    _maxFiles = newProps.maxFiles;
    _type = [[NSString alloc] initWithUTF8String:newProps.type.c_str()];
    _maxSize = newProps.maxSize;
    _maxDuration = newProps.maxDuration;
  [super updateProps:props oldProps:oldProps];
}

- (void)prepareForRecycle {
  [super prepareForRecycle];
}

- (void)didMoveToWindow {
  [super didMoveToWindow];
}

@end




