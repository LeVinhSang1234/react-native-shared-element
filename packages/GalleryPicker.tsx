import { useEffect, useRef } from 'react';
import GalleryNativeComponent, {
  Commands,
} from '../natives/GalleryNativeComponent';
import type { GalleryNativeProps } from '../natives/GalleryNativeComponent';

type TNativeRef = React.ComponentRef<typeof GalleryNativeComponent>;

interface GalleryProps extends Omit<GalleryNativeProps, 'children' | 'type'> {
  type?: 'video' | 'image' | 'all';
}

function GalleryPicker(props: GalleryProps) {
  const nativeRef = useRef<TNativeRef>(null);

  useEffect(() => {
    if (nativeRef.current) Commands.initialize(nativeRef.current);
  }, []);

  return <GalleryNativeComponent {...props} />;
}

export default GalleryPicker;
