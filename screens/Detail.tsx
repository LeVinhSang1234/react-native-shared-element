import { StyleSheet, Text, TouchableOpacity, View, Image } from 'react-native';
import Video from '../packages/Video';
import { useRef, useState } from 'react';
import ShareView, { ShareViewRef } from '../packages/ShareView';
import { useNavigation } from '@react-navigation/native';

export default function Detail() {
  const [copy, setCopy] = useState(false);
  const [removeTag, setRemoveTag] = useState(false);
  const navigation = useNavigation();

  const refView = useRef<ShareViewRef>(null);

  return (
    <View>
      <Video
        shareTagElement={'Hello'}
        style={styles.root}
        poster={{ uri: 'https://picsum.photos/300/200' }}
        source={{
          uri: 'https://res.cloudinary.com/dn2lgibpf/video/upload/v1760553824/uploads_besties/1760553776667Z2gawA4AW35j.mp4',
        }}
        sharingAnimatedDuration={300}
      />
      <ShareView shareTagElement="ShareView" ref={refView}>
        <Image
          source={require('./test.png')}
          style={styles.image}
          resizeMode="cover"
        />
      </ShareView>

      <TouchableOpacity onPress={() => setCopy(!copy)}>
        <Text>Toggle Copy Video</Text>
      </TouchableOpacity>

      <TouchableOpacity
        onPress={async () => {
          navigation.goBack();
        }}
      >
        <Text>Back</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    width: '100%',
    height: 300,
  },
  image: { width: '100%', height: 400 },
});
