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
        sharingAnimatedDuration={1000}
      >
        <View style={{ flex: 1 }}>
          <Text
            style={{ color: 'white', width: '100%', backgroundColor: 'red' }}
          >
            asdasdadádasd ádasd ádsad ádasd ádasd áda đa ấ ádassa asdasdadádasd
            ádasd ádsad ádasd ádasd áda đa ấ ádassa
          </Text>
          <Pressable
            onPress={() => {
              refVideo.current?.presentFullscreenPlayer();
            }}
          >
            <Text style={{ color: 'white' }}>Fullscreen</Text>
          </Pressable>
          <Pressable onPress={() => navigation.navigate('Detail' as never)}>
            <Text style={{ color: 'white' }}>Goto Detail</Text>
          </Pressable>
        </View>
      </Video>
    </View>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1, backgroundColor: 'black' },
  root: {
    height: 400,
    width: '100%',
    backgroundColor: 'red',
  },
});
