import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import ShareView, { ShareViewRef } from '../packages/ShareView';
import Video from '../packages/Video';
import { useRef } from 'react';

export default function Home() {
  const navigation = useNavigation();

  const refView = useRef<ShareViewRef>(null);

  const freeze = () => {
    refView.current?.freeze();
  };

  const unfreeze = () => {
    refView.current?.unfreeze();
  };

  return (
    <ScrollView
      style={styles.flex}
      contentContainerStyle={{ paddingBottom: 100 }}
    >
      <ShareView ref={refView}>
        <View style={{ opacity: 1 }}>
          <Video
            style={styles.root}
            source={{
              uri: 'https://res.cloudinary.com/dn2lgibpf/video/upload/v1760553824/uploads_besties/1760553776667Z2gawA4AW35j.mp4',
            }}
            loop
            sharingAnimatedDuration={300}
            onError={e => console.log(e.nativeEvent)}
            posterResizeMode="contain"
            muted
          />
          <View style={{ opacity: 1 }}>
            <Text style={{ color: 'red' }}>Color red</Text>
            <Text style={{ color: 'red' }}>Color red</Text>
            <Text style={{ color: 'red' }}>Color red</Text>
            <Text style={{ color: 'red' }}>Color red</Text>
            <Text style={{ color: 'red' }}>Color red</Text>
            <Text style={{ color: 'red' }}>Color red</Text>
          </View>
        </View>
      </ShareView>

      <Pressable onPress={freeze}>
        <Text>Freeze</Text>
      </Pressable>
      <Pressable onPress={unfreeze}>
        <Text>Unfreeze</Text>
      </Pressable>
      <Pressable onPress={() => navigation.navigate('Detail')}>
        <Text>Goto Detail</Text>
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
});
