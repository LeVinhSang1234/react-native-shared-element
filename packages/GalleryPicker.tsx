import { useEffect, useRef } from 'react';
import GalleryNativeComponent, {
  Commands,
} from '../natives/GalleryNativeComponent';
import type { GalleryNativeProps } from '../natives/GalleryNativeComponent';

type TNativeRef = React.ComponentRef<typeof GalleryNativeComponent>;

interface GalleryProps
  extends Omit<GalleryNativeProps, 'children' | 'type' | 'albumType'> {
  type?: 'Video' | 'Image' | 'All';
  albumType?: 'Album' | 'SmartAlbum' | 'All';
}

function GalleryPicker(props: GalleryProps) {
  const nativeRef = useRef<TNativeRef>(null);

  useEffect(() => {
    if (nativeRef.current) Commands.initialize(nativeRef.current);
  }, []);

  return <GalleryNativeComponent {...props} ref={nativeRef} />;
}

export default GalleryPicker;
