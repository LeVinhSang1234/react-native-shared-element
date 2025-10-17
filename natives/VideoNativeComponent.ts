import { codegenNativeCommands, codegenNativeComponent } from 'react-native';
import type { ViewProps, HostComponent } from 'react-native';
import type {
  BubblingEventHandler,
  Double,
} from 'react-native/Libraries/Types/CodegenTypes';

export interface OnLoadStartData {
  readonly duration: Double;
  readonly playableDuration: Double;
  readonly width: Double;
  readonly height: Double;
}

export interface OnLoadData {
  readonly loadedDuration: Double;
  readonly duration: Double;
}

export interface OnProgressData {
  readonly currentTime: Double;
  readonly duration: Double;
  readonly playableDuration: Double;
}

export interface OnErrorData {
  readonly message: string;
  readonly code?: string;
  readonly track?: string;
}

export interface OnBufferingData {
  readonly isBuffering: boolean;
}

export interface OnEndData {}

export interface OnMemoryData {
  heapMB: Double;
  nativeMB: Double;
  message: string;
}

export interface BufferConfig {
  readonly minBufferMs?: Double;
  readonly maxBufferMs?: Double;
  readonly bufferForPlaybackMs?: Double;
  readonly bufferForPlaybackAfterRebufferMs?: Double;
  readonly maxHeapAllocationPercent?: Double;
}

export interface VideoNativeProps extends ViewProps {
  readonly source: string;
  readonly poster?: string;
  readonly loop?: boolean;
  readonly muted?: boolean;
  readonly paused?: boolean;
  readonly seek?: Double;
  readonly volume?: Double;
  readonly shareTagElement?: string;
  readonly bgColor?: string;
  readonly resizeMode?: string;
  readonly posterResizeMode?: string;
  readonly progressInterval?: Double;
  readonly enableProgress?: boolean;
  readonly enableOnLoad?: boolean;
  readonly sharingAnimatedDuration?: Double;
  readonly onEnd?: BubblingEventHandler<OnEndData>;
  readonly onLoad?: BubblingEventHandler<OnLoadData>;
  readonly onError?: BubblingEventHandler<OnErrorData>;
  readonly onProgress?: BubblingEventHandler<OnProgressData>;
  readonly onLoadStart?: BubblingEventHandler<OnLoadStartData>;
  readonly onBuffering?: BubblingEventHandler<OnBufferingData>;
  readonly onFullscreenPlayerDidDismiss?: BubblingEventHandler<{}>;
  readonly cacheMaxSize?: Double;
  readonly fullscreen?: boolean;
  readonly bufferConfig?: BufferConfig;
  readonly maxBitRate?: Double;
  readonly rate?: Double;
  readonly preventsDisplaySleepDuringVideoPlayback?: boolean;

  /**
   * ⚠️ Android only.
   *
   * When `true` (default), uses OkHttp as the HTTP client for video streaming.
   * This enables caching and custom headers for smoother playback.
   *
   * When `false`, falls back to ExoPlayer's built-in
   * DefaultHttpDataSource which uses **less RAM** but disables caching.
   *
   * 👉 Keep this `true` for better performance on most devices.
   * 👉 Set to `false` only when you want to minimize memory usage or run multiple videos at once.
   */
  readonly useOkHttp?: boolean;

  /**
   * ⚠️ Android only.
   *
   * When true, the player will fully stop playback instead of just pausing when `paused={true}`.
   *
   * This immediately releases video decoders and buffered data to reduce memory usage,
   * but playback will need to re-prepare when resumed.
   *
   * Default: false (normal pause behavior — keeps buffer in memory)
   */
  readonly stopWhenPaused?: boolean;

  /**
   * ⚙️ Android only.
   *
   * Periodically reports memory usage (heap, native, total) while video is active.
   * Useful for debugging leaks or performance bottlenecks.
   *
   * The event fires roughly every 3 seconds when `debugMemory` is true.
   */
  readonly onMemoryDebug?: BubblingEventHandler<OnMemoryData>;
  readonly enableOnMemoryDebug?: boolean;
  /**
   * ⚙️ Android only.
   */
  readonly memoryDebugInterval?: Double;
}

interface NativeCommands {
  setSeekCommand: (
    viewRef: React.ElementRef<HostComponent<VideoNativeProps>>,
    seek: Double,
  ) => void;
  setPausedCommand: (
    viewRef: React.ElementRef<HostComponent<VideoNativeProps>>,
    paused: boolean,
  ) => void;
  setVolumeCommand: (
    viewRef: React.ElementRef<HostComponent<VideoNativeProps>>,
    volume: Double,
  ) => void;
  initialize: (
    viewRef: React.ElementRef<HostComponent<VideoNativeProps>>,
  ) => void;
  prepareForRecycle: (
    viewRef: React.ElementRef<HostComponent<VideoNativeProps>>,
  ) => void;
  presentFullscreenPlayer: (
    viewRef: React.ElementRef<HostComponent<VideoNativeProps>>,
  ) => void;
  dismissFullscreenPlayer: (
    viewRef: React.ElementRef<HostComponent<VideoNativeProps>>,
  ) => void;
}

export const Commands = codegenNativeCommands<NativeCommands>({
  supportedCommands: [
    'initialize',
    'prepareForRecycle',
    'setSeekCommand',
    'setPausedCommand',
    'setVolumeCommand',
    'presentFullscreenPlayer',
    'dismissFullscreenPlayer',
  ],
});

export default codegenNativeComponent<VideoNativeProps>(
  'Video',
) as HostComponent<VideoNativeProps>;
