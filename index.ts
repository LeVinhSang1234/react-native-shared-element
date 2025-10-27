import Video, {
  setCacheMaxSize,
  getThumbnailVideo,
  getMemory,
} from './packages/Video';
export type { VideoProps, VideoRef } from './packages/Video';
export type {
  OnBufferingData,
  OnEndData,
  OnErrorData,
  OnLoadData,
  OnLoadStartData,
  OnProgressData,
  BufferConfig,
} from './natives/VideoNativeComponent';

export { Video, setCacheMaxSize, getThumbnailVideo, getMemory };
