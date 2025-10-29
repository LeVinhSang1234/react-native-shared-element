/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 */

import { StatusBar, StyleSheet, useColorScheme, View } from 'react-native';
import GalleryPicker from './packages/GalleryPicker';

function App() {
  const isDarkMode = useColorScheme() === 'dark';

  return (
    <View style={styles.container}>
      <StatusBar barStyle={isDarkMode ? 'light-content' : 'dark-content'} />
      <AppContent />
    </View>
  );
}

function AppContent() {
  return (
    <View
      style={styles.container}
      onLayout={e => console.log(e.nativeEvent.layout)}
    >
      <GalleryPicker
        onLayout={e => console.log('asdasa', e.nativeEvent.layout)}
        style={styles.container}
        onError={e => {
          console.log(e.nativeEvent);
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: 'white',
  },
});

export default App;
