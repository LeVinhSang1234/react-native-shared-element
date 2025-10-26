import { codegenNativeCommands, codegenNativeComponent } from 'react-native';
import type { Double } from 'react-native/Libraries/Types/CodegenTypes';
import type { HostComponent, ViewProps } from 'react-native';

export interface ShareViewNativeProps extends ViewProps {
  readonly shareTagElement?: string;
  readonly sharingAnimatedDuration?: Double;
}

interface NativeCommands {
  initialize: (
    viewRef: React.ElementRef<HostComponent<ShareViewNativeProps>>,
  ) => void;
  prepareForRecycle: (
    viewRef: React.ElementRef<HostComponent<ShareViewNativeProps>>,
  ) => void;
  freeze: (
    viewRef: React.ElementRef<HostComponent<ShareViewNativeProps>>,
  ) => void;
  unfreeze: (
    viewRef: React.ElementRef<HostComponent<ShareViewNativeProps>>,
  ) => void;
}

export const Commands = codegenNativeCommands<NativeCommands>({
  supportedCommands: ['initialize', 'prepareForRecycle', 'freeze', 'unfreeze'],
});

export default codegenNativeComponent<ShareViewNativeProps>(
  'ShareView',
) as HostComponent<ShareViewNativeProps>;
