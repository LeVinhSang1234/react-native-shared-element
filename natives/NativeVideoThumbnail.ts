import { TurboModule, TurboModuleRegistry } from 'react-native';
import type { Double } from 'react-native/Libraries/Types/CodegenTypes';

export interface Spec extends TurboModule {
  /**
   * Get thumbnail from video at timeMs (milliseconds)
   */
  getThumbnail(url: string, timeMs: Double): Promise<string>;
  getMemory(): Promise<string>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('VideoThumbnail');
