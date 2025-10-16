import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import ShareView from '../packages/ShareView';
import Video from '../packages/Video';

export default function Home() {
  const navigation = useNavigation();

  return (
    <View style={styles.flex}>
      <ShareView shareTagElement="ShareView">
        <Text>Hello</Text>
        <Text>How are you</Text>
      </ShareView>
      <Video
        shareTagElement="Hello"
        style={styles.root}
        poster={{ uri: 'https://picsum.photos/300/200' }}
        source={{
          uri: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        }}
        sharingAnimatedDuration={300}
        onError={e => console.log(e.nativeEvent)}
        posterResizeMode="contain"
        stopWhenPaused
        progressInterval={2000}
      />
      <Pressable onPress={() => navigation.navigate('Detail' as never)}>
        <Text>Goto Detail</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  root: {
    height: 400,
    width: '100%',
  },
});
