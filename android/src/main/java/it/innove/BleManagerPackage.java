package it.innove;

import com.facebook.react.ReactPackage;
import com.facebook.react.bridge.JavaScriptModule;
import com.facebook.react.bridge.NativeModule;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.uimanager.ViewManager;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;


public class BleManagerPackage implements ReactPackage {

	public BleManagerPackage() {}

	@Override
	public List<NativeModule> createNativeModules(ReactApplicationContext reactApplicationContext) {
		List<NativeModule> modules = new ArrayList<>();

		modules.add(new BleManager(reactApplicationContext));
		return  modules;
	}

	public List<Class<? extends JavaScriptModule>> createJSModules() {
		return new ArrayList<>();
	}

	@Override
	public List<ViewManager> createViewManagers(ReactApplicationContext reactApplicationContext) {
		return Collections.emptyList();
	}
}
