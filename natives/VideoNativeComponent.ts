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
