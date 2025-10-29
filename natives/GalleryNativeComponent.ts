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
 * Event data when an error occurs.
 */
export interface OnErrorData {
  code:
    | 'NOT_DETERMINED'
    | 'RESTRICTED'
    | 'DENIED'
    | 'AUTHORIZED'
    | 'LIMITED'
    | 'UNKNOWN'; // Short error code, e.g. "NO_PERMISSION", "FETCH_FAILED"
  message: string; // Human-readable error message
}

/**
 * Native component props for the Gallery view.
 */
export interface GalleryNativeProps extends ViewProps {
  readonly onSelect?: DirectEventHandler<Photo>; // Triggered when a media item is selected
  readonly onError?: DirectEventHandler<OnErrorData>; // Fires when a native error occurs
  readonly multiple?: boolean; // Allow selecting multiple items
  readonly maxFiles?: Double; // Maximum number of files selectable
  readonly type?: string; // "Image" | "Video" | "All"
  readonly maxSize?: Double; // Maximum file size (bytes)
  readonly maxDuration?: Double; // Maximum video duration (seconds)
  readonly albumType?: string; //'Album' | 'SmartAlbum' | 'All'
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
