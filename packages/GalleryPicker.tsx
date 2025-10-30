import { useEffect, useRef } from 'react';
import GalleryNativeComponent, {
  Commands,
} from '../natives/GalleryNativeComponent';
import type { GalleryNativeProps } from '../natives/GalleryNativeComponent';

type TNativeRef = React.ComponentRef<typeof GalleryNativeComponent>;

export interface GalleryPickerProps
  extends Omit<
    GalleryNativeProps,
    'children' | 'type' | 'albumType' | 'allowOnSelects'
  > {
  type?: 'video' | 'image' | 'all';
  albumType?: 'Album' | 'SmartAlbum' | 'All';
}

function GalleryPicker(props: GalleryPickerProps) {
  const nativeRef = useRef<TNativeRef>(null);

  useEffect(() => {
    if (nativeRef.current) Commands.initialize(nativeRef.current);
  }, []);

  return (
    <GalleryNativeComponent
      {...props}
      ref={nativeRef}
      allowOnSelects={!!props.onSelects}
    />
  );
}

export default GalleryPicker;
