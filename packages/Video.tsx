import VideoNativeComponent, {
  Commands,
  VideoNativeProps,
} from '../natives/VideoNativeComponent';
import {
  forwardRef,
  memo,
  useEffect,
  useImperativeHandle,
  useMemo,
  useRef,
} from 'react';
import { StyleSheet, type MeasureOnSuccessCallback } from 'react-native';
import { preloadVideoSource } from './utils';
import NativeVideoThumbnail from '../natives/NativeVideoThumbnail';

type TNativeRef = React.ComponentRef<typeof VideoNativeComponent>;

export interface VideoRef {
  measure: (callback: MeasureOnSuccessCallback) => void;
  pause: () => void;
  resume: () => void;
  prepareForRecycle: () => Promise<void>;
  presentFullscreenPlayer: () => void;
  dismissFullscreenPlayer: () => void;
  seek: (seek: number) => void;
}

export interface VideoProps
  extends Omit<
    VideoNativeProps,
    | 'resizeMode'
    | 'source'
    | 'enableProgress'
    | 'enableOnLoad'
    | 'headerHeight'
    | 'poster'
    | 'posterResizeMode'
    | 'cacheMaxSize'
    | 'fullscreenMode'
    | 'bgColor'
  > {
  resizeMode?: 'contain' | 'cover' | 'stretch' | 'center';
  posterResizeMode?: 'contain' | 'cover' | 'stretch' | 'center';
  source?: string | { uri: string } | number;
  poster?: string | { uri: string } | number;
}

const config = { cacheMaxSize: 200 }; // 2GB

const Video = forwardRef<VideoRef, VideoProps>((props, ref) => {
  const {
    source,
    poster,
    progressInterval = 250,
    volume = 1,
    rate = 1,
    useOkHttp = true,
    ...p
  } = props;

  const nativeRef = useRef<TNativeRef>(null);

  useEffect(() => {
    if (nativeRef.current) Commands.initialize(nativeRef.current);
  }, []);

  useImperativeHandle(ref, () => ({
    measure(callback) {
      nativeRef.current?.measure(callback);
    },
    pause() {
      if (nativeRef.current) Commands.setPausedCommand(nativeRef.current, true);
    },
    resume() {
      if (nativeRef.current) {
        Commands.setPausedCommand(nativeRef.current, false);
      }
    },
    seek(seek: number) {
      if (nativeRef.current) Commands.setSeekCommand(nativeRef.current, seek);
    },
    presentFullscreenPlayer() {
      if (nativeRef.current) {
        Commands.presentFullscreenPlayer(nativeRef.current);
      }
    },
    dismissFullscreenPlayer() {
      if (nativeRef.current) {
        Commands.dismissFullscreenPlayer(nativeRef.current);
      }
    },
    async prepareForRecycle() {
      await new Promise(res => {
        if (nativeRef.current) Commands.prepareForRecycle(nativeRef.current);
        setTimeout(() => res(null), 10);
      });
    },
  }));

  const _source = useMemo(() => preloadVideoSource(source ?? ''), [source]);
  const _poster = useMemo(() => preloadVideoSource(poster ?? ''), [poster]);

  const bg = useMemo(
    () => StyleSheet.flatten(p.style)?.backgroundColor,
    [p.style],
  );

  return (
    <VideoNativeComponent
      {...p}
      useOkHttp={useOkHttp}
      ref={nativeRef}
      rate={rate}
      source={_source}
      poster={_poster}
      enableProgress={!!p.onProgress}
      enableOnLoad={!!p.onLoad}
      progressInterval={progressInterval}
      volume={volume}
      cacheMaxSize={config.cacheMaxSize}
      bgColor={bg as string}
    />
  );
});

export function setCacheMaxSize(size: number = 300) {
  config.cacheMaxSize = size;
}

export async function getThumbnailVideo(url: string, timeSec: number) {
  const base64 = await NativeVideoThumbnail.getThumbnail(url, timeSec * 1000);
  return base64;
}

Video.displayName = 'Video';

export default memo(Video);
