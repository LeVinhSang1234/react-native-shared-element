import { StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import Video from '../packages/Video';
import { useNavigation } from '@react-navigation/native';
import { useState } from 'react';

export default function Detail() {
  const [copy, setCopy] = useState(false);
  return (
    <View>
      <Video
        shareTagElement="Hello"
        style={styles.root}
        poster={{ uri: 'https://picsum.photos/300/200' }}
        source={{
          uri: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        }}
        sharingAnimatedDuration={300}
      />
      {copy ? (
        <Video
          shareTagElement="Hello"
          style={styles.root}
          poster={{ uri: 'https://picsum.photos/300/200' }}
          source={{
            uri: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          }}
          sharingAnimatedDuration={500}
        />
      ) : null}
      <TouchableOpacity onPress={() => setCopy(!copy)}>
        <Text>Goback</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    width: '80%',
    height: 300,
    backgroundColor: 'red',
    marginTop: 100,
  },
});
