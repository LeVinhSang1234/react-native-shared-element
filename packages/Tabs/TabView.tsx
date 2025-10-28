import { ComponentType, useCallback } from 'react';
import { StyleSheet, useWindowDimensions, View } from 'react-native';
import { useSharedValue, withSpring } from 'react-native-reanimated';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import TabItem from './TabItem';
import TabProvider from './TabProvider';

type Props = {
  tabs: { name: string; Component: ComponentType }[];
  defaultActive?: number;
};

const SPACE = 0;

function TabView({ tabs, defaultActive = 0 }: Props) {
  const { width } = useWindowDimensions();
  const active = useSharedValue(defaultActive);
  const animated = useSharedValue(defaultActive);

  const gesture = Gesture.Pan()
    .onUpdate(({ translationX: _tr }) => {
      'worklet';
      if (Math.abs(_tr) < SPACE) return;
      let next = active.value - (_tr - (_tr > 0 ? SPACE : -SPACE)) / width;
      next = Math.max(0, Math.min(next, tabs.length - 1));
      animated.value = next;
    })
    .onEnd(({ velocityX }) => {
      'worklet';
      const delta = animated.value - active.value;
      const isStrongSwipe = Math.abs(velocityX) > 800;
      let nextIdx = active.value;

      if (isStrongSwipe) {
        if (velocityX > 0 && delta < -0.1 && active.value > 0) {
          nextIdx = active.value - 1;
        } else if (
          velocityX < 0 &&
          delta > 0.1 &&
          active.value < tabs.length - 1
        ) {
          nextIdx = active.value + 1;
        }
      } else {
        if (delta < -0.25 && active.value > 0) {
          nextIdx = active.value - 1;
        } else if (delta > 0.25 && active.value < tabs.length - 1) {
          nextIdx = active.value + 1;
        }
      }
      animated.value = withSpring(nextIdx, { duration: 350 });
      active.value = nextIdx;
    });

  const navigate = useCallback(
    (name: string) => {
      const tabIndex = tabs.findIndex(e => e.name === name);
      if (tabIndex < 0) return;
      animated.value = withSpring(tabIndex, { duration: 350 });
      active.value = tabIndex;
    },
    [active, animated, tabs],
  );

  return (
    <GestureDetector gesture={gesture}>
      <View style={styles.root}>
        <TabProvider navigate={navigate}>
          {tabs.map((Tab, i) => (
            <TabItem
              key={`${Tab.Component.name}_${Tab.name}_${i}`}
              _key={i}
              animated={animated}
              defautVisible={animated.value === i}
              defaultBackdrop={animated.value > i}
            >
              <Tab.Component />
            </TabItem>
          ))}
        </TabProvider>
      </View>
    </GestureDetector>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
});

export default TabView;
