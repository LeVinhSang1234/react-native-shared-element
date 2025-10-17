# @rn-slv/react-native-shared-element

A custom React Native component for shared element transitions, supporting both **video** and **any view** (images, text, custom layouts).

---

## Features

- Shared element transitions for video and any React Native view
- Smooth, native-powered animations between screens
- Full support for React Navigation (auto integration)
- Exposes imperative methods for advanced control
- TypeScript ready
- All transitions and animations are handled fully on the native side (no JS overlays or hacks)

---

> **Note:**
> The video component uses [KTVHTTPCache](https://github.com/ChangbaDevs/KTVHTTPCache) for advanced HTTP caching on **iOS**, and [OkHttp](https://square.github.io/okhttp/) for efficient networking on **Android**.

---

## Source

GitHub: [https://github.com/LeVinhSang1234/React-Native-Shared-Element/tree/share-element](https://github.com/LeVinhSang1234/React-Native-Shared-Element/tree/share-element)

---

---

## Installation

```bash
npm install @rn-slv/react-native-shared-element
# or
yarn add @rn-slv/react-native-shared-element
```

### iOS

After installation, run pod install in the ios directory:

```bash
cd ios && pod install
```

---

## Note: KTVHTTPCache iOS Build Fix

If you encounter build errors related to `LONG_LONG_MAX` when building for iOS, the Podfile includes an automatic fix using the following script:

```ruby
files = `find Pods -name KTVHCRange.h`.split("\n")
files.each do |file|
  system("sed -i '' -e 's/LONG_LONG_MAX/LLONG_MAX/g' \"#{file}\"")
end
```

Example:

```ruby
post_install do |installer|
    react_native_post_install(
      installer,
      config[:reactNativePath],
      :mac_catalyst_enabled => false,
    )
    files = `find Pods -name KTVHCRange.h`.split("\n")
    files.each do |file|
      system("sed -i '' -e 's/LONG_LONG_MAX/LLONG_MAX/g' \"#{file}\"")
    end
  end
```

---

### Android

Native code is autolinked. No extra steps needed.

---

## Important Note for Navigation Patch

If you are using React Navigation please add the following command to your app's `package.json`:

```json
"postinstall": "if [ -d ./node_modules/@react-navigation/core/lib/module ] && [ -d ./node_modules/@rn-slv/react-native-shared-element ]; then cp ./node_modules/@rn-slv/react-native-shared-element/packages/auto-navigation.txt ./node_modules/@react-navigation/core/lib/module/useNavigation.js fi"
```

This ensures the navigation patch is always applied after installing dependencies.

---

## Usage

# Shared Video

You can change the video cache size limit by calling the function `setCacheMaxSize(size: number)` (unit: MB), imported from the package. The default is 300MB.

**Tip:** Call `setCacheMaxSize` as early as possible in your app (ideally before any video is loaded) to ensure the cache limit is applied correctly.

Example:

```tsx
import { Video, setCacheMaxSize } from '@rn-slv/react-native-shared-element';

// Set maximum cache size to 500MB
setCacheMaxSize(500);
```

```tsx
import { Video } from '@rn-slv/react-native-shared-element';

<Video
  source={{
    uri: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
  }}
  shareTagElement="myVideo"
  sharingAnimatedDuration={500}
  // ...other props
/>;
```

---

The `Video` component also supports passing children, allowing you to overlay any React Native views (such as buttons, text, or icons) on top of the video.

Example:

```tsx
<Video
  source={{ uri: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4' }}
  shareTagElement="myVideo"
  sharingAnimatedDuration={500}
>
  <View>
    <Text style={{ color: 'white' }}>Overlay Text</Text>
    <TouchableOpacity onPress={...}>
      <Icon name="play" />
    </TouchableOpacity>
  </View>
</Video>
```

## Props

| Prop                                      | Type                                          | Default      | Description                                                                                                                                      |
| ----------------------------------------- | --------------------------------------------- | ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `source`                                  | string / { uri: string } / number             | **Required** | Video source. Can be a URL string, local asset, or resource ID.                                                                                  |
| `poster`                                  | string / { uri: string } / number             |              | Poster image to display before the video loads.                                                                                                  |
| `loop`                                    | boolean                                       | `false`      | If true, the video will loop when it ends.                                                                                                       |
| `muted`                                   | boolean                                       | `false`      | If true, the video will be muted.                                                                                                                |
| `paused`                                  | boolean                                       | `false`      | If true, the video will be paused.                                                                                                               |
| `seek`                                    | number                                        |              | Seek to a specific time (in seconds).                                                                                                            |
| `volume`                                  | number                                        | `1`          | Video volume (0 to 1).                                                                                                                           |
| `shareTagElement`                         | string                                        |              | Tag for shared element transition.                                                                                                               |
| `resizeMode`                              | 'contain' \| 'cover' \| 'stretch' \| 'center' | `'contain'`  | Video resize mode.                                                                                                                               |
| `posterResizeMode`                        | 'contain' \| 'cover' \| 'stretch' \| 'center' |              | Poster resize mode.                                                                                                                              |
| `progressInterval`                        | number                                        | `250`        | Interval (ms) for progress updates via onProgress.                                                                                               |
| `enableProgress`                          | boolean                                       |              | Enable onProgress event (auto if onProgress is provided).                                                                                        |
| `enableOnLoad`                            | boolean                                       |              | Enable onLoad event (auto if onLoad is provided).                                                                                                |
| `sharingAnimatedDuration`                 | number                                        | `350`        | Duration (ms) for shared element transition animation.<br>Note: Will try to get from React Navigation if available, otherwise defaults to 350ms. |
| `fullscreen`                              | boolean                                       | `false`      | Enable fullscreen mode for video.                                                                                                                |
| `bufferConfig`                            | object (BufferConfig)                         |              | Advanced buffer configuration for video playback (Android only). See [BufferConfig](#bufferconfig) below.                                        |
| `maxBitRate`                              | number                                        |              | Maximum video bit rate.                                                                                                                          |
| `rate`                                    | number                                        |              | Playback rate (speed).                                                                                                                           |
| `preventsDisplaySleepDuringVideoPlayback` | boolean                                       |              | Prevent device display from sleeping during video playback.                                                                                      |
| `children`                                | ReactNode                                     |              | Any React Native view(s) to overlay on top of the video.                                                                                         |

### BufferConfig

BufferConfig object fields (Android only):

| Field                              | Type   | Description                                                             |
| ---------------------------------- | ------ | ----------------------------------------------------------------------- |
| `minBufferMs`                      | number | Minimum buffer duration (ms) before playback starts.                    |
| `maxBufferMs`                      | number | Maximum buffer duration (ms) allowed during playback.                   |
| `bufferForPlaybackMs`              | number | Amount of buffer (ms) required to start playback.                       |
| `bufferForPlaybackAfterRebufferMs` | number | Amount of buffer (ms) required to resume playback after rebuffering.    |
| `maxHeapAllocationPercent`         | number | Maximum percent of heap memory allowed for video buffer (Android only). |

## Event Props (Video only)

The following event props apply only to the `Video` component:

| Prop          | Type     | Description                                      |
| ------------- | -------- | ------------------------------------------------ |
| `onEnd`       | function | Called when the video reaches the end.           |
| `onLoad`      | function | Called when the video is loaded.                 |
| `onError`     | function | Called when an error occurs.                     |
| `onProgress`  | function | Called periodically with playback progress.      |
| `onLoadStart` | function | Called when the video starts loading.            |
| `onBuffering` | function | Called when the video starts or stops buffering. |

---

## Imperative Methods (Ref)

### Video Ref Methods

```tsx
const videoRef = useRef<VideoRef>(null);

<Video ref={videoRef} source={...} />

// Pause the video playback
videoRef.current?.pause();

// Resume the video playback
videoRef.current?.resume();

// Seek to a specific time (in seconds)
videoRef.current?.seek(30);

// Measure the component's dimensions (returns {x, y, width, height, pageX, pageY})
videoRef.current?.measure((data) => {
  console.log('Dimensions:', data);
});

// Prepare for recycle (preserves shared element for transition)
// Triggers shared element back transition.
// This is the main method for backShareElement. Call it manually if you want to run the shared element transition when navigating back, especially in cases where you do not use navigation.
await videoRef.current?.prepareForRecycle();

// Present the fullscreen video player
videoRef.current?.presentFullscreenPlayer();

// Dismiss the fullscreen video player
videoRef.current?.dismissFullscreenPlayer();
```

---

## License

MIT License - see the [LICENSE](LICENSE) file for details.

---

## Author

Sang Le (lsang2884@gmail.com)

<video src="https://github.com/user-attachments/assets/24d59a51-fd69-41c0-b299-1e031c982607" controls width="400"></video>
