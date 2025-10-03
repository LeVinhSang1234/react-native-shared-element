import { StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import Video from '../packages/Video';
import { useState } from 'react';

export default function Detail() {
  const [copy, setCopy] = useState(false);
  const [removeTag, setRemoveTag] = useState(false);

  return (
    <View>
      <Video
        shareTagElement={'Hello'}
        style={styles.root}
        poster={{ uri: 'https://picsum.photos/300/200' }}
        source={{
          uri: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        }}
        sharingAnimatedDuration={300}
      />
      {copy ? (
        <Video
          shareTagElement={removeTag ? undefined : 'Hello'}
          style={styles.root}
          poster={{ uri: 'https://picsum.photos/300/200' }}
          source={{
            uri: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          }}
          sharingAnimatedDuration={500}
        />
      ) : null}

      <TouchableOpacity onPress={() => setCopy(!copy)}>
        <Text>Toggle Copy Video</Text>
      </TouchableOpacity>

      <TouchableOpacity onPress={() => setRemoveTag(!removeTag)}>
        <Text>{removeTag ? 'Add ShareTag' : 'Remove ShareTag'}</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    width: '80%',
    height: 300,
  },
});
