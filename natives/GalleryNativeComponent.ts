import { codegenNativeCommands, codegenNativeComponent } from 'react-native';
import type { HostComponent, ViewProps } from 'react-native';
import type {
  DirectEventHandler,
  Double,
} from 'react-native/Libraries/Types/CodegenTypes';

/**
 * Represents a single photo or video item from the device gallery.
 */
export interface Photo {
  id: string; // Unique asset identifier (e.g. PHAsset.localIdentifier on iOS)
  uri: string; // Local file URI or content:// path
  type: string; // "image" | "video"
  filename?: string; // File name, e.g. "IMG_1234.JPG"
  extension?: string; // File extension, e.g. ".jpg", ".mp4"
  width?: Double; // Media width in pixels
  height?: Double; // Media height in pixels
  size?: Double; // File size in bytes
  duration?: Double; // Duration in seconds (for videos)
  orientation?: Double; // 0, 90, 180, or 270 degrees
  timestamp?: Double; // Unix timestamp (milliseconds since epoch)
  location?: {
    latitude: Double;
    longitude: Double;
  } | null; // GPS location, if available
  readonly includeSmartAlbums?: boolean; // Whether to include Smart Albums (e.g. Favorites, Selfies)
}

/**
 * Native component props for the Gallery view.
 */
export interface GalleryNativeProps extends ViewProps {
  onSelect?: DirectEventHandler<Photo>; // Triggered when a media item is selected
  readonly multiple?: boolean; // Allow selecting multiple items
  readonly maxFiles?: Double; // Maximum number of files selectable
  readonly type?: string; // "image" | "video" | "all"
  readonly maxSize?: Double; // Maximum file size (bytes)
  readonly maxDuration?: Double; // Maximum video duration (seconds)
}

interface NativeCommands {
  initialize: (
    viewRef: React.ElementRef<HostComponent<GalleryNativeProps>>,
  ) => void;
}

export const Commands = codegenNativeCommands<NativeCommands>({
  supportedCommands: ['initialize'],
});

/**
 * Codegen registration for Fabric (New Architecture)
 */
export default codegenNativeComponent<GalleryNativeProps>(
  'Gallery',
) as HostComponent<GalleryNativeProps>;
