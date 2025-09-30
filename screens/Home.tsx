import { Pressable, StyleSheet, Text, View } from 'react-native';
import Video, { VideoRef } from '../packages/Video';
import { useNavigation } from '@react-navigation/native';
import { useRef } from 'react';

export default function Home() {
  const navigation = useNavigation();
  const refVideo = useRef<VideoRef>(null);

  return (
    <View style={styles.flex}>
      <Video
        ref={refVideo}
        style={styles.root}
        poster={{ uri: 'https://picsum.photos/300/200' }}
        source={{
          uri: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        }}
        shareTagElement="Video"
      />
      <Pressable onPress={() => navigation.navigate('Detail' as never)}>
        <Text style={{ color: 'white' }}>Goto Detail</Text>
      </Pressable>
    </View>
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
