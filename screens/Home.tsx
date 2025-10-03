import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import ShareView from '../packages/ShareView';
import Video from '../packages/Video';

export default function Home() {
  const navigation = useNavigation();

  return (
    <View style={styles.flex}>
      <ShareView shareTagElement="ShareView" style={{ backgroundColor: 'red' }}>
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
  },
});
