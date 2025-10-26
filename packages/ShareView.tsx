import {
  forwardRef,
  memo,
  useCallback,
  useEffect,
  useImperativeHandle,
  useRef,
  useState,
} from 'react';
import { LayoutChangeEvent, Platform, View } from 'react-native';
import type { Ref } from 'react';

import type { ShareViewNativeProps } from '../natives/ShareViewNativeComponent';
import ShareViewNativeComponent, {
  Commands,
} from '../natives/ShareViewNativeComponent';
type TNativeRef = React.ComponentRef<typeof ShareViewNativeComponent>;

export interface ShareViewProps extends ShareViewNativeProps {}

export interface ShareViewRef extends View {
  prepareForRecycle: () => Promise<void>;
  freeze: () => void;
  unfreeze: () => void;
}

const ShareView = forwardRef<ShareViewRef, ShareViewProps>(
  ({ children, onLayout, ...props }, ref: Ref<ShareViewRef>) => {
    const nativeRef = useRef<TNativeRef>(null);
    const [freeze, setFreeze] = useState(false);
    const refSize = useRef({ width: 0, height: 0 });

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
          freeze: function () {
            if (nativeRef.current) {
              Commands.freeze(nativeRef.current);
              if (Platform.OS !== 'android') setFreeze(true);
            }
          },
          unfreeze: function () {
            setFreeze(false);
            setTimeout(() => {
              if (nativeRef.current) {
                Commands.unfreeze(nativeRef.current);
              }
            }, 0);
          },
        } as ShareViewRef;
      },
      [prepareForRecycle],
    );

    useEffect(() => {
      if (nativeRef.current) Commands.initialize(nativeRef.current);
    }, []);

    const _onLayout = (e: LayoutChangeEvent) => {
      onLayout?.(e);
      refSize.current = {
        width: e.nativeEvent.layout.width,
        height: e.nativeEvent.layout.height,
      };
    };

    return (
      <ShareViewNativeComponent {...props} onLayout={_onLayout} ref={nativeRef}>
        {freeze ? <View style={refSize.current} /> : children}
      </ShareViewNativeComponent>
    );
  },
);

ShareView.displayName = 'ShareView';

export default memo(ShareView);
