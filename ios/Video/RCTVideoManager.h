//
//  RCTVideoManager.h
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 27/9/25.
//

#import <Foundation/Foundation.h>
#import <AVKit/AVKit.h>
#import <react/renderer/components/ShareElement/EventEmitters.h>

NS_ASSUME_NONNULL_BEGIN
@interface RCTVideoManager : NSObject
@property (nonatomic, copy) NSString *source;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, copy) AVLayerVideoGravity aVLayerVideoGravity;
@property (nonatomic, assign) BOOL paused;
@property (nonatomic, copy, nullable) void (^onPlayerReady)(void);

- (void)applySource:(NSString *)source;
- (void)applySourceFromCommand:(NSString *)source;
- (void)applyResizeMode:(NSString *)resizeMode;
- (void)applyPaused:(BOOL)paused;
- (void)applyPausedFromCommand:(BOOL)paused;
- (void)applyMuted:(BOOL)muted;
- (void)applyVolume:(double)volume;
- (void)applyVolumeFromCommand:(double)volume;
- (void)applySeek:(double)seek;
- (void)applyLoop:(BOOL)loop;
- (void)applyLoopFromCommand:(BOOL)loop;
- (void)applyProgressInterval:(double)interval;
- (void)applyProgress:(BOOL)enable;
- (void)applyOnLoad:(BOOL)enable;
- (void)updateEventEmitter:(const facebook::react::VideoEventEmitter *)eventEmitter;
- (void)seekToTime:(double)seek;
- (void)enterFullscreen;
- (void)exitFullscreen;
- (void)applyBufferConfig:(double)maxBuffer;
- (void)applyMaxRate:(double) maxBitRate;
- (void)applyRate:(double) rate;
- (void)applyPreventsDisplaySleepDuringVideoPlayback:(BOOL)keepAwake;

// Share element: chuyển NGUYÊN player từ manager khác sang đây
- (void)adoptPlayerFromManager:(RCTVideoManager *)other;
- (void)detachPlayer;

- (void)willUnmount;
- (void)unmount;

@end
NS_ASSUME_NONNULL_END
