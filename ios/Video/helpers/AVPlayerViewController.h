//
//  AVPlayerViewController.h
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 28/9/25.
//
#import <AVKit/AVKit.h>

@interface CustomPlayerViewController : AVPlayerViewController
@property (nonatomic, copy) void (^onDismiss)(void);
@end
