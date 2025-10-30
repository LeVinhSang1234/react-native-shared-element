import { codegenNativeCommands, codegenNativeComponent } from 'react-native';
import type { HostComponent, ViewProps } from 'react-native';
import type {
  DirectEventHandler,
  Double,
} from 'react-native/Libraries/Types/CodegenTypes';

export interface PhotoLocation {
  latitude: Double;
  longitude: Double;
}

export interface OnSelectsData {
  photos: {
    readonly id: string; // Unique asset identifier (e.g. PHAsset.localIdentifier on iOS)
    readonly uri: string; // Local file URI or content:// path
    readonly type: string; // "image" | "video"
    readonly filename?: string; // File name, e.g. "IMG_1234.JPG"
    readonly extension?: string; // File extension, e.g. ".jpg", ".mp4"
    readonly width?: Double; // Media width in pixels
    readonly height?: Double; // Media height in pixels
    readonly size?: Double; // File size in bytes
    readonly duration?: Double; // Duration in seconds (for videos)
    readonly orientation?: Double; // 0, 90, 180, or 270 degrees
    readonly timestamp?: Double; // Unix timestamp (milliseconds since epoch)
    readonly location?: {
      latitude: Double;
      longitude: Double;
    } | null; // GPS location, if available
  }[];
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
  readonly onSelects?: DirectEventHandler<OnSelectsData>; // Triggered when a media item is selected
  readonly onError?: DirectEventHandler<OnErrorData>; // Fires when a native error occurs
  readonly allowMultiple?: boolean; // Allow selecting multiple items
  readonly maxFiles?: Double; // Maximum number of files selectable
  readonly type?: string; // "Image" | "Video" | "All"
  readonly maxSize?: Double; // Maximum file size (bytes)
  readonly maxDuration?: Double; // Maximum video duration (seconds)
  readonly albumType?: string; //'Album' | 'SmartAlbum' | 'All'
  readonly allowOnSelects?: boolean; //'Album' | 'SmartAlbum' | 'All'
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
