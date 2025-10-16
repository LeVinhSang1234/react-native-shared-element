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
        source={{
          uri: 'https://res.cloudinary.com/dn2lgibpf/video/upload/v1760546576/uploads_besties/1760544963083UcOz2OtpWAf9.mp4',
        }}
        sharingAnimatedDuration={300}
        onError={e => console.log(e.nativeEvent)}
        posterResizeMode="contain"
        stopWhenPaused
        progressInterval={2000}
        onBuffering={e => console.log(e.nativeEvent)}
        onLoad={e => console.log(e.nativeEvent)}
        onLoadStart={e => console.log(e.nativeEvent)}
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
