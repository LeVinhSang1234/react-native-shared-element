import { Pressable, ScrollView, StyleSheet, Text } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import Video, { getMemory } from '../packages/Video';

export default function Home() {
  const navigation = useNavigation();

  return (
    <ScrollView
      style={styles.flex}
      contentContainerStyle={{ paddingBottom: 100 }}
    >
      <Video
        shareTagElement={'Hello'}
        style={styles.root}
        poster={{ uri: 'https://picsum.photos/300/200' }}
        source={{
          uri: 'https://res.cloudinary.com/dn2lgibpf/video/upload/v1760553824/uploads_besties/1760553776667Z2gawA4AW35j.mp4',
        }}
        loop
        sharingAnimatedDuration={300}
      />
      <Pressable onPress={() => navigation.navigate('Detail')}>
        <Text>Goto Detail</Text>
      </Pressable>
      <Pressable onPress={() => getMemory().then(console.log)}>
        <Text>MEmmeee</Text>
      </Pressable>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  root: {
    height: 400,
    width: '100%',
  },
  image: { width: '100%', height: 200 },
});
