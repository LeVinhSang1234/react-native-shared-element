import { memo, PropsWithChildren, useState } from 'react';
import { StyleSheet, useWindowDimensions } from 'react-native';
import Animated, {
  useAnimatedStyle,
  interpolate,
  SharedValue,
  useAnimatedReaction,
} from 'react-native-reanimated';
import { scheduleOnRN } from 'react-native-worklets';
import { TabItemProvider } from './TabProvider';
import { useColors } from 'providers/Theme';

type Props = {
  animated: SharedValue<number>;
  _key: number;
  defautVisible?: boolean;
  defaultBackdrop?: boolean;
};

function TabItem(props: PropsWithChildren<Props>) {
  const { children, animated, _key, defautVisible, defaultBackdrop } = props;
  const { width } = useWindowDimensions();
  const [visible, setVisible] = useState(defautVisible);
  const [focus, setFocus] = useState(defautVisible);
  const [backdrop, setBackdrop] = useState(!!defaultBackdrop);
  const colors = useColors();

  const showTab = () => setVisible(true);

  const setFocusTrue = () => setFocus(true);
  const setFocusFalse = () => setFocus(false);

  const setBackdropTrue = () => setBackdrop(true);
  const setBackdropFalse = () => setBackdrop(false);

  useAnimatedReaction(
    () => animated.value,
    (value, prev = null) => {
      'worklet';
      const _value = value < (prev ?? 0) ? Math.floor(value) : Math.ceil(value);
      if (_value === _key && !visible) scheduleOnRN(showTab);
      if (_value === _key && !focus) scheduleOnRN(setFocusTrue);
      if (value === _value && _value !== _key && focus) {
        scheduleOnRN(setFocusFalse);
      }
      if (value === _value && _value === _key && backdrop) {
        scheduleOnRN(setBackdropFalse);
      }
      if (!backdrop && value > _key) scheduleOnRN(setBackdropTrue);
    },
    [_key, focus, visible, backdrop],
  );

  const animatedStyle = useAnimatedStyle(() => {
    'worklet';
    const translateX = interpolate(
      animated.value,
      [_key - 1, _key, _key + 1],
      [width, 0, -width / 4],
      'clamp',
    );
    return {
      transform: [{ translateX }],
    };
  });

  const backdropStyle = useAnimatedStyle(() => {
    'worklet';
    const opacity = interpolate(
      animated.value,
      [_key - 1, _key, _key + 1],
      [0.7, 0, 0.7],
      'clamp',
    );
    return { opacity, backgroundColor: colors.black30 };
  });

  return (
    <Animated.View
      style={[StyleSheet.absoluteFill, styles.root, animatedStyle]}
    >
      <TabItemProvider focus={!!focus}>
        {visible ? children : null}
      </TabItemProvider>
      {backdrop && visible ? (
        <Animated.View style={[StyleSheet.absoluteFill, backdropStyle]} />
      ) : null}
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
});

export default memo(TabItem);
