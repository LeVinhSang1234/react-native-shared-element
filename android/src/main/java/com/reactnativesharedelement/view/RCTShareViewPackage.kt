package com.reactnativesharedelement.view

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager

class RCTShareViewPackage : ReactPackage {
    override fun createViewManagers(reactContext: ReactApplicationContext)
            = listOf<ViewManager<*, *>>(RCTShareViewManager())

    @Deprecated("Migrate to [BaseReactPackage] and implement [getModule] instead.")
    override fun createNativeModules(reactContext: ReactApplicationContext)
            = emptyList<NativeModule>()
}