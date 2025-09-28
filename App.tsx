import { ScrollView, StyleSheet } from 'react-native';
import Video from './packages/Video';

export default function App() {
  return (
    <ScrollView style={styles.flex}>
      <Video
        style={styles.root}
        poster={{ uri: 'https://picsum.photos/300/200' }}
        source={{
          uri: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        }}
      />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  root: {
    height: 400,
    width: '100%',
    backgroundColor: 'red',
  },
});
