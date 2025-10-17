//
//  RCTVideoManager.m
//  ReactNativeSharedElement
//
//  Created by Sang Lv on 27/9/25.
//

#import "RCTVideoManager.h"
#import "RCTVideoHelper.h"
#import "RCTViewHelper.h"
#import "AVPlayerViewController.h"

static NSString * const kResizeModeContain = @"contain";
static NSString * const kResizeModeCover   = @"cover";
static NSString * const kResizeModeStretch = @"stretch";
static NSString * const kResizeModeCenter  = @"center";

@interface RCTVideoManager ()

// React props state
@property (nonatomic, copy) NSString *resizeMode;
@property (nonatomic, assign) BOOL loop;
@property (nonatomic, assign) BOOL muted;
@property (nonatomic, assign) BOOL enableProgress;
@property (nonatomic, assign) BOOL enableOnLoad;
@property (nonatomic, assign) BOOL isBuffering;
@property (nonatomic, assign) double seek;
@property (nonatomic, assign) double volume;
@property (nonatomic, assign) double progressInterval;
@property (nonatomic, assign) double maxBitRate;
@property (nonatomic, assign) double maxBuffer;
@property (nonatomic, assign) BOOL keepAwake;

// Event emitter
@property (nonatomic, assign) const facebook::react::VideoEventEmitter *eventEmitter;

// Internal
@end

@implementation RCTVideoManager {
  id _timeObserver;
  NSTimer *_loadEventTimer;
  double _lastLoadedDuration;
}

#pragma mark - Init

- (instancetype)init {
  if (self = [super init]) {
    _aVLayerVideoGravity = AVLayerVideoGravityResizeAspect;
    _volume = 1.0;
    _paused = YES;
  }
  return self;
}

#pragma mark - Apply props

- (void)applySource:(NSString *)source {
  if ([source isEqualToString:_source]) return;
  [self applySourceFromCommand:source];
}

- (void)applySourceFromCommand:(NSString *)source {
  [self willUnmount];
  [self unmount];
  
  [RCTVideoHelper createVideoURL:source completion:^(NSURL *finalURL) {
    dispatch_async(dispatch_get_main_queue(), ^{
      self.player = [AVPlayer playerWithURL:finalURL];
      [self _attachStolenPlayer];
      
      self.source = source;
      if(self.onUpdateLayout) self.onUpdateLayout();
      if (!self.paused) [self.player play];
   });
  }];
}

- (void)applyResizeMode:(NSString *)resizeMode {
  if ([resizeMode isEqualToString:_resizeMode]) return;
  
  _aVLayerVideoGravity = [self videoGravityFromResizeMode:resizeMode];
  if (_playerLayer) _playerLayer.videoGravity = _aVLayerVideoGravity;
  
  _resizeMode = resizeMode;
}

- (void)applyPaused:(BOOL)paused {
  if (paused == _paused) return;
  [self applyPausedFromCommand:paused];
  _paused = paused;
  [self updateIdleTimer];
}

- (void)applyPausedFromCommand:(BOOL)paused {
  __weak __typeof__(self) weakSelf = self;
  if (paused) {
    [_player setMuted:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [weakSelf.player pause]; });
  } else {
    [_player play];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [weakSelf.player setMuted:weakSelf.muted]; });
  }
}

- (void)applyMuted:(BOOL)muted {
  if (muted == _muted) return;
  _muted = muted;
  [_player setMuted:muted];
}

- (void)applyVolume:(double)volume {
  if (volume == _volume) return;
  [self applyVolumeFromCommand:volume];
  _volume = volume;
}

- (void)applyVolumeFromCommand:(double)volume {
  double clamped = fmax(0.0, fmin(1.0, volume));
  [_player setVolume:clamped];
}

- (void)applySeek:(double)seek {
  if (seek == _seek) return;
  [self seekToTime:seek];
  _seek = seek;
}

- (void)seekToTime:(double)seek {
  if (!_player || !_player.currentItem || _player.currentItem.status != AVPlayerItemStatusReadyToPlay) return;
  CMTime seekTime = CMTimeMakeWithSeconds(seek, NSEC_PER_SEC);
  CMTime duration = _player.currentItem.duration;
  if (CMTIME_IS_VALID(duration) && CMTimeCompare(seekTime, duration) > 0) {
    seekTime = duration;
  }
  [_player seekToTime:seekTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:{}];
}

- (void)applyLoop:(BOOL)loop {
  if (loop == _loop) return;
  [self applyLoopFromCommand:loop];
  _loop = loop;
}

- (void)applyLoopFromCommand:(BOOL)loop {
  if (loop && _player && _player.currentItem) {
    double cur = CMTimeGetSeconds(_player.currentTime);
    double dur = CMTimeGetSeconds(_player.currentItem.duration);
    if (dur > 0 && cur >= dur) {
      [_player seekToTime:kCMTimeZero];
      [self applyPaused:_paused];
    }
  }
}

- (void)applyProgressInterval:(double)interval {
  if (interval == _progressInterval) return;
  _progressInterval = interval;
  if (_enableProgress) [self addProgressTracking];
}

- (void)applyProgress:(BOOL)enable {
  if (enable == _enableProgress) return;
  enable ? [self addProgressTracking] : [self removeProgressTracking];
  _enableProgress = enable;
}

- (void)applyOnLoad:(BOOL)enable {
  if (enable == _enableOnLoad) return;
  enable ? [self addOnLoadTracking] : [self removeOnLoadTracking];
  _enableOnLoad = enable;
}

- (void)applyRate:(double)rate {
  if (!_player) return;
  if (rate <= 0) {
    _player.rate = 0.0;
  } else {
    _player.rate = rate;
    _player.automaticallyWaitsToMinimizeStalling = NO;
    if(_maxBuffer > 0) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.player.automaticallyWaitsToMinimizeStalling = self.maxBuffer >= 3000;
      });
    }
  }
}

- (void)applyBufferConfig:(double)maxBuffer {
  if (!_player || maxBuffer == _maxBuffer) return;
  _maxBuffer = maxBuffer;
  if (maxBuffer > 0) {
    _player.currentItem.preferredForwardBufferDuration = maxBuffer / 1000.0;
  }
}

- (void)applyMaxRate:(double)maxBitRate {
  if (maxBitRate > 0 && maxBitRate != _maxBitRate) {
    _maxBitRate = maxBitRate;
    _player.currentItem.preferredPeakBitRate = maxBitRate;
  }
}

- (void)applyPreventsDisplaySleepDuringVideoPlayback:(BOOL)keepAwake {
  if(keepAwake == _keepAwake) return;
  _keepAwake = keepAwake;
  [self updateIdleTimer];
}

- (void)updateIdleTimer {
  dispatch_async(dispatch_get_main_queue(), ^{
    UIApplication *app = [UIApplication sharedApplication];
    BOOL shouldKeepAwake = self.keepAwake && !self.paused && self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying;
    app.idleTimerDisabled = shouldKeepAwake;
  });
}

#pragma mark - Player layer

- (void)createPlayerLayer {
  if (_player && !_playerLayer) {
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
    _playerLayer.videoGravity = _aVLayerVideoGravity;
  }
}

- (AVLayerVideoGravity)videoGravityFromResizeMode:(NSString *)resizeMode {
  if ([resizeMode isEqualToString:kResizeModeCover])   return AVLayerVideoGravityResizeAspectFill;
  if ([resizeMode isEqualToString:kResizeModeStretch]) return AVLayerVideoGravityResize;
  return AVLayerVideoGravityResizeAspect; // default / contain / center
}

#pragma mark - Event emitter

- (void)updateEventEmitter:(const facebook::react::VideoEventEmitter *)eventEmitter {
  _eventEmitter = eventEmitter;
}

#pragma mark - Progress / OnLoad trackers

- (void)addOnLoadTracking {
  if (!_player) return;
  [self removeOnLoadTracking];
  _loadEventTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                     target:self
                                                   selector:@selector(sendOnLoadEvent)
                                                   userInfo:nil
                                                    repeats:YES];
  [[NSRunLoop mainRunLoop] addTimer:_loadEventTimer forMode:NSRunLoopCommonModes];
}

- (void)removeOnLoadTracking {
  [_loadEventTimer invalidate];
  _loadEventTimer = nil;
}

- (void)addProgressTracking {
  if (!_player) return;
  [self removeProgressTracking];
  
  __weak __typeof__(self) weakSelf = self;
  double sec = (_progressInterval == 0 ? 1.0 : _progressInterval / 1000.0);
  
  _timeObserver = [_player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(sec, NSEC_PER_SEC)
                                                        queue:dispatch_get_main_queue()
                                                   usingBlock:^(__unused CMTime t) {
    [weakSelf sendProgressEvent];
  }];
}

- (void)removeProgressTracking {
  if (_timeObserver && _player) {
    [_player removeTimeObserver:_timeObserver];
    _timeObserver = nil;
  }
}

#pragma mark - Events

- (void)playerItemDidFailToPlayToEnd:(NSNotification *)notification {
  NSError *error = notification.userInfo[AVPlayerItemFailedToPlayToEndTimeErrorKey];
  [self sendOnErrorEvent:error];
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
  if (!_player) return;
  [self sendEndEvent];
  if (_loop) {
    [_player seekToTime:kCMTimeZero];
    [self applyPausedFromCommand:_paused];
  } else [self updateIdleTimer];
}


- (void)sendOnErrorEvent:(NSError *)error {
  if (!_eventEmitter || !error) return;
  NSString *codeString = [NSString stringWithFormat:@"%ld", (long)error.code];
  NSString *message = error.localizedDescription ?: @"Unknown error";
  
  NSError *under = error.userInfo[NSUnderlyingErrorKey];
  if (under && under.localizedDescription) {
    message = [message stringByAppendingFormat:@" | underlying: %@", under.localizedDescription];
  }
  
  facebook::react::VideoEventEmitter::OnError data = {
    .message = [message UTF8String],
    .code = [codeString UTF8String],
  };
  _eventEmitter->onError(data);
}

- (void)sendProgressEvent {
  if (!_player || !_player.currentItem) return;
  
  double currentSeconds = CMTimeGetSeconds(_player.currentTime);
  double durationSeconds = CMTimeGetSeconds(_player.currentItem.duration);
  double playableDuration = 0.0;
  
  if (isnan(currentSeconds)) currentSeconds = 0.0;
  if (isnan(durationSeconds)) durationSeconds = 0.0;
  
  NSArray *ranges = _player.currentItem.loadedTimeRanges;
  if (ranges.count > 0) {
    CMTimeRange r = [ranges.firstObject CMTimeRangeValue];
    playableDuration = CMTimeGetSeconds(CMTimeRangeGetEnd(r));
  }
  if (isnan(playableDuration)) playableDuration = 0.0;
  
  if (_eventEmitter) {
    facebook::react::VideoEventEmitter::OnProgress data = {
      .currentTime = currentSeconds,
      .duration = durationSeconds,
      .playableDuration = playableDuration
    };
    _eventEmitter->onProgress(data);
  }
}

- (void)sendEndEvent {
  if (!_player || !_player.currentItem) return;
  if (_eventEmitter) {
    facebook::react::VideoEventEmitter::OnEnd data = {};
    _eventEmitter->onEnd(data);
  }
}

- (void)sendLoadStartEvent {
  if (!_player || !_player.currentItem) return;
  
  double durationSeconds = CMTimeGetSeconds(_player.currentItem.duration);
  if (isnan(durationSeconds)) durationSeconds = 0.0;
  
  if (_seek > 0 && durationSeconds > 0) {
    double seekValue = MIN(_seek, durationSeconds);
    CMTime seekTime = CMTimeMakeWithSeconds(seekValue, NSEC_PER_SEC);
    [_player seekToTime:seekTime];
  }
  
  double playableDuration = 0.0;
  NSArray *ranges = _player.currentItem.loadedTimeRanges;
  if (ranges.count > 0) {
    CMTimeRange r = [ranges.firstObject CMTimeRangeValue];
    playableDuration = CMTimeGetSeconds(CMTimeRangeGetEnd(r));
  }
  if (isnan(playableDuration)) playableDuration = 0.0;
  
  CGSize videoSize = CGSizeZero;
  NSArray *tracks = [_player.currentItem.asset tracksWithMediaType:AVMediaTypeVideo];
  if (tracks.count > 0) {
    AVAssetTrack *track = tracks.firstObject;
    videoSize = track.naturalSize;
  }
  
  if (_eventEmitter) {
    facebook::react::VideoEventEmitter::OnLoadStart data = {
      .duration = durationSeconds,
      .playableDuration = playableDuration,
      .width = videoSize.width,
      .height = videoSize.height
    };
    _eventEmitter->onLoadStart(data);
  }
}

- (void)sendOnLoadEvent {
  if (!_player || !_player.currentItem) return;
  
  double duration = CMTimeGetSeconds(_player.currentItem.duration);
  if (isnan(duration)) duration = 0.0;
  
  double loadedDuration = 0.0;
  NSArray *ranges = _player.currentItem.loadedTimeRanges;
  if (ranges.count > 0) {
    CMTimeRange r = [ranges.firstObject CMTimeRangeValue];
    loadedDuration = CMTimeGetSeconds(CMTimeRangeGetEnd(r));
    if (isnan(loadedDuration)) loadedDuration = 0.0;
  }
  if (loadedDuration != _lastLoadedDuration) {
    _lastLoadedDuration = loadedDuration;
    if (loadedDuration >= duration) [self removeOnLoadTracking];
    if (_eventEmitter) {
      facebook::react::VideoEventEmitter::OnLoad data = {
        .loadedDuration = loadedDuration,
        .duration = duration
      };
      _eventEmitter->onLoad(data);
    }
  }
}

- (void)sendBufferingEvent:(BOOL)buffering {
  if (_eventEmitter && _isBuffering != buffering) {
    _isBuffering = buffering;
    facebook::react::VideoEventEmitter::OnBuffering data = { .isBuffering = buffering };
    _eventEmitter->onBuffering(data);
  }
}

#pragma mark - Observers

- (void)trackEventsPlayer {
  AVPlayerItem *item = _player.currentItem;
  if (!item) return;
  [_player addObserver:self forKeyPath:@"timeControlStatus" options:NSKeyValueObservingOptionNew context:nil];

  [item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
  [item addObserver:self forKeyPath:@"error" options:NSKeyValueObservingOptionNew context:nil];
  [item addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
  [_player addObserver:self forKeyPath:@"timeControlStatus" options:NSKeyValueObservingOptionNew context:nil];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidFailToPlayToEnd:)
                                               name:AVPlayerItemFailedToPlayToEndTimeNotification object:item];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidReachEnd:)
                                               name:AVPlayerItemDidPlayToEndTimeNotification object:item];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)ctx {
  
  if (object == _player && [keyPath isEqualToString:@"timeControlStatus"]) {
      switch (_player.timeControlStatus) {
          case AVPlayerTimeControlStatusPaused:
              [self sendBufferingEvent:NO];
              break;
          case AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate:
              [self sendBufferingEvent:YES];
              break;
          case AVPlayerTimeControlStatusPlaying:
              [self sendBufferingEvent:NO];
              break;
          default:
              break;
      }
      return;
  }
  
  if (object != _player.currentItem) return;
  
  if ([keyPath isEqualToString:@"status"] && _player.currentItem.status == AVPlayerItemStatusReadyToPlay) {
    if (_onPlayerReady) _onPlayerReady();
    [self sendLoadStartEvent];
    [_player.currentItem removeObserver:self forKeyPath:@"status"];
  } else if ([keyPath isEqualToString:@"error"]) {
    [self sendOnErrorEvent:_player.currentItem.error];
  } else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
    [self sendBufferingEvent:YES];
  } else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
    [self sendBufferingEvent:NO];
  }
}

- (void)safeRemoveObservers {
  @try { [_player removeObserver:self forKeyPath:@"timeControlStatus"]; } @catch (__unused NSException *e) {}
  
  AVPlayerItem *item = _player.currentItem;
  if (!item) return;
  
  @try { [item removeObserver:self forKeyPath:@"status"]; } @catch (__unused NSException *e) {}
  @try { [item removeObserver:self forKeyPath:@"error"]; } @catch (__unused NSException *e) {}
  @try { [item removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"]; } @catch (__unused NSException *e) {}
}


#pragma mark - Fullscreen

- (void)enterFullscreen {
  if (!_player) return;
  UIViewController *rootVC = [RCTViewHelper getRootViewController];
  
  
  CustomPlayerViewController *playerVC = [CustomPlayerViewController new];
  playerVC.player = _player;
  playerVC.modalPresentationStyle = UIModalPresentationFullScreen;
  
  __weak __typeof__(self) weakSelf = self;
  playerVC.onDismiss = ^{
    dispatch_async(dispatch_get_main_queue(), ^ {
      if (!weakSelf.paused) {
        [weakSelf.player play];
      }
      if (weakSelf.eventEmitter) {
        facebook::react::VideoEventEmitter::OnFullscreenPlayerDidDismiss data = {};
        weakSelf.eventEmitter->onFullscreenPlayerDidDismiss(data);
      }
    });
  };
  
  [rootVC presentViewController:playerVC animated:YES completion:^{
    [playerVC.player play];
  }];
}

- (void)exitFullscreen {
  UIViewController *rootVC = [RCTViewHelper getRootViewController];
  [rootVC dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Share element (move player, no seek)

- (void)adoptPlayerFromManager:(RCTVideoManager *)other {
  if (!other || other == self) return;
  
  AVPlayer *movingPlayer = other.player;
  if (!movingPlayer) return;
  @try {
    if (other.playerLayer) {
      [other.playerLayer removeFromSuperlayer];
    }
  } @catch (__unused NSException *e) {}
  
  @try { [other removeProgressTracking]; } @catch (__unused NSException *e) {}
  @try { [other removeOnLoadTracking]; }   @catch (__unused NSException *e) {}
  @try { [other safeRemoveObservers]; }    @catch (__unused NSException *e) {}
  
  @try {
    if (_playerLayer) {
      [_playerLayer removeFromSuperlayer];
      _playerLayer = nil;
    }
  } @catch (__unused NSException *e) {}
  
  _player = movingPlayer;
  [self createPlayerLayer];
  if (_playerLayer && _playerLayer.superlayer == nil) {
  }
  
  if (_playerLayer) _playerLayer.videoGravity = _aVLayerVideoGravity;
  [self applyVolumeFromCommand:_volume];
  [self applyLoopFromCommand:_loop];
  [self applyPausedFromCommand:_paused];
}

- (void)detachPlayer {
  if (self.playerLayer.superlayer) {
    [self.playerLayer removeFromSuperlayer];
  }
  _playerLayer = nil;
  _player = nil;
}

// Internal: gỡ sạch other, trả về player (không đổi trạng thái play/pause)
- (AVPlayer *)_stealPlayerAndDetach {
  if (!_player) return nil;
  
  // timers
  [self removeProgressTracking];
  [self removeOnLoadTracking];
  
  // observers & notifications
  [self safeRemoveObservers];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  // layer
  if (_playerLayer) {
    [_playerLayer removeFromSuperlayer];
    _playerLayer = nil;
  }
  
  AVPlayer *stolen = _player;
  _player = nil;
  return stolen;
}

- (void)_attachStolenPlayer {
  [self createPlayerLayer];
  [self trackEventsPlayer];
  
  if (_enableOnLoad)   [self addOnLoadTracking];
  if (_enableProgress) [self addProgressTracking];
}

#pragma mark - Cleanup

- (void)willUnmount {
  [self removeProgressTracking];
  [self removeOnLoadTracking];
  [self safeRemoveObservers];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  _source = @"";
  _seek = 0;
  _paused = NO;
  _muted = NO;
  _volume = 1.0;
  _loop = NO;
  _resizeMode = @"contain";
  _progressInterval = 0;
  _enableProgress = NO;
  _enableOnLoad = NO;
  _lastLoadedDuration = 0;
  _eventEmitter = nil;
  
  if (_playerLayer) {
    [_playerLayer removeFromSuperlayer];
    _playerLayer = nil;
  }
}

- (void)unmount {
  if (_player) {
    [_player pause];
    _player = nil;
  }
}

@end
