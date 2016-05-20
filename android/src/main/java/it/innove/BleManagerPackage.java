package it.innove;

import android.app.Activity;
import com.facebook.react.ReactPackage;
import com.facebook.react.bridge.JavaScriptModule;
import com.facebook.react.bridge.NativeModule;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.uimanager.ViewManager;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;


public class BleManagerPackage implements ReactPackage {

	private Activity mActivity;

	public BleManagerPackage(Activity activityContext) {
		mActivity = activityContext;
	}


	@Override
	public List<NativeModule> createNativeModules(ReactApplicationContext reactApplicationContext) {
		List<NativeModule> modules = new ArrayList<>();

		modules.add(new BleManager(reactApplicationContext, mActivity));
		return  modules;
	}

	@Override
	public List<Class<? extends JavaScriptModule>> createJSModules() {
		return new ArrayList<>();
	}

	@Override
	public List<ViewManager> createViewManagers(ReactApplicationContext reactApplicationContext) {
		return Arrays.asList();
	}
}
