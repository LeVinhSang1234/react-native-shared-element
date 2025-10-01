import {
  forwardRef,
  memo,
  useCallback,
  useEffect,
  useImperativeHandle,
  useRef,
} from 'react';
import type { View } from 'react-native';
import type { Ref } from 'react';

import type { ShareViewNativeProps } from '../natives/ShareViewNativeComponent';
import ShareViewNativeComponent, {
  Commands,
} from '../natives/ShareViewNativeComponent';
type TNativeRef = React.ComponentRef<typeof ShareViewNativeComponent>;

export interface ShareViewProps extends ShareViewNativeProps {}

export interface ShareViewRef extends View {
  prepareForRecycle: () => Promise<void>;
}

const ShareView = forwardRef<ShareViewRef, ShareViewProps>(
  (props, ref: Ref<ShareViewRef>) => {
    const nativeRef = useRef<TNativeRef>(null);

    const prepareForRecycle = useCallback(async () => {
      return new Promise(res => {
        if (nativeRef.current) {
          Commands.prepareForRecycle(nativeRef.current);
        }
        setTimeout(() => res(null), 10);
      });
    }, []);

    useImperativeHandle(
      ref,
      () => {
        return {
          ...(nativeRef.current as unknown as View),
          prepareForRecycle,
        } as ShareViewRef;
      },
      [prepareForRecycle],
    );

    useEffect(() => {
      if (nativeRef.current) Commands.initialize(nativeRef.current);
    }, []);

    return <ShareViewNativeComponent {...props} ref={nativeRef} />;
  },
);

ShareView.displayName = 'ShareView';

export default memo(ShareView);
