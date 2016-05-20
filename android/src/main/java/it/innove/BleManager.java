package it.innove;

import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothManager;
import android.bluetooth.le.*;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.os.Bundle;
import android.support.annotation.Nullable;
import android.util.Base64;
import android.util.Log;
import com.facebook.react.bridge.*;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import org.json.JSONException;

import java.util.*;

import static com.facebook.react.bridge.UiThreadUtil.runOnUiThread;


public class BleManager extends ReactContextBaseJavaModule {

	public static final String LOG_TAG = "logs";


	private static Activity activity;
	private BluetoothAdapter bluetoothAdapter;
	private BluetoothLeScanner bluetoothLeScanner;
	private ScanSettings settings;
	private Context context;
	private ReactContext reactContext;

	// key is the MAC Address
	Map<String, Peripheral> peripherals = new LinkedHashMap<String, Peripheral>();
	Map<String, Callback> connectCallback = new LinkedHashMap<String, Callback>();

	private Timer timer = new Timer();

	public BleManager(ReactApplicationContext reactContext, Activity activity) {
		super(reactContext);
		BleManager.activity = activity;
		context = reactContext;
		this.reactContext = reactContext;

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
			settings = new ScanSettings.Builder()
					.setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
					.build();
		}

		Log.d(LOG_TAG, "Inizializzo modulo");


		IntentFilter filter = new IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED);
		context.registerReceiver(mReceiver, filter);
		Log.d(LOG_TAG, "Inizializzo receiver stato ble");
	}

	@Override
	public String getName() {
		return "BleManager";
	}

	private BluetoothAdapter getBluetoothAdapter() {
		if (bluetoothAdapter == null) {
			BluetoothManager manager = (BluetoothManager) context.getSystemService(Context.BLUETOOTH_SERVICE);
			Log.d(LOG_TAG, "Manager preso");
			bluetoothAdapter = manager.getAdapter();
		}
		return bluetoothAdapter;
	}

	private void sendEvent(String eventName,
						   @Nullable WritableMap params) {
		getReactApplicationContext()
				.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
				.emit(eventName, params);
	}

	@ReactMethod
	public void scan(ReadableArray serviceUUIDs, final int scanSeconds, Callback successCallback) {
		Log.d(LOG_TAG, "scan");
		if (!getBluetoothAdapter().isEnabled())
			return;

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
			for (Iterator<Map.Entry<String, Peripheral>> iterator = peripherals.entrySet().iterator(); iterator.hasNext(); ) {
				Map.Entry<String, Peripheral> entry = iterator.next();
				if (!entry.getValue().isConnected()) {
					iterator.remove();
				}
			}

			if (serviceUUIDs.size() > 0) {
				UUID[] services = new UUID[serviceUUIDs.size()];
				for(int i = 0; i < serviceUUIDs.size(); i++){
					services[i] = UUIDHelper.uuidFromString(serviceUUIDs.getString(i));
					Log.d(LOG_TAG, "scan su service: " + serviceUUIDs.getString(i));
				}

				//getBluetoothAdapter().startLeScan(services, mLeScanCallback);
				getBluetoothAdapter().startLeScan(mLeScanCallback);
			} else {
				getBluetoothAdapter().startLeScan(mLeScanCallback);
			}

			if (scanSeconds > 0) {
				Thread thread = new Thread() {

					@Override
					public void run() {

						try {
							Thread.sleep(scanSeconds * 1000);
						} catch (InterruptedException e) {
						}

						runOnUiThread(new Runnable() {
							@Override
							public void run() {
								getBluetoothAdapter().stopLeScan(mLeScanCallback);
								WritableMap map = Arguments.createMap();
								sendEvent("BluetoothManagerStopScan", map);
							}
						});

					}

				};
				thread.start();
			}
		}
		successCallback.invoke();
	}

	@ReactMethod
	public void connect(String peripheralUUID, Callback successCallback, Callback failCallback) {
		Log.d(LOG_TAG, "connect: " + peripheralUUID );

		Peripheral peripheral = peripherals.get(peripheralUUID);
		if (peripheral != null){
			peripheral.connect(successCallback, failCallback, activity);
		} else
			failCallback.invoke();
	}

	@ReactMethod
	public void disconnect(String peripheralUUID, Callback successCallback, Callback failCallback) {
		Log.d(LOG_TAG, "disconnect: " + peripheralUUID);

		Peripheral peripheral = peripherals.get(peripheralUUID);
		if (peripheral != null){
			peripheral.disconnect();
			successCallback.invoke();
		} else
			failCallback.invoke();
	}

	@ReactMethod
	public void startNotification(String deviceUUID, String serviceUUID, String characteristicUUID, Callback successCallback, Callback failCallback) {
		Log.d(LOG_TAG, "startNotification");

		Peripheral peripheral = peripherals.get(deviceUUID);
		if (peripheral != null){
			peripheral.registerNotify(UUID.fromString(serviceUUID), UUID.fromString(characteristicUUID), successCallback, failCallback);
		} else
			failCallback.invoke();
	}


	@ReactMethod
	public void write(String deviceUUID, String serviceUUID, String characteristicUUID, String message, Callback successCallback, Callback failCallback) {
		Log.d(LOG_TAG, "write su periferica: " + deviceUUID);

		Peripheral peripheral = peripherals.get(deviceUUID);
		if (peripheral != null){
			byte[] decoded = Base64.decode(message.getBytes(), Base64.DEFAULT);
			Log.d(LOG_TAG, "Message(" + decoded.length + "): " + bytesToHex(decoded) + " su " + deviceUUID);
			peripheral.write(UUID.fromString(serviceUUID), UUID.fromString(characteristicUUID), decoded, successCallback, failCallback, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT);
		} else
			failCallback.invoke();
	}

	private BluetoothAdapter.LeScanCallback mLeScanCallback =
			new BluetoothAdapter.LeScanCallback() {


				@Override
				public void onLeScan(final BluetoothDevice device, final int rssi,
									 final byte[] scanRecord) {
					runOnUiThread(new Runnable() {
						@Override
						public void run() {
							Log.i(LOG_TAG, "DiscoverPeripheral: " + device.getName());
							String address = device.getAddress();

							if (!peripherals.containsKey(address)) {

								Peripheral peripheral = new Peripheral(device, rssi, scanRecord, reactContext);
								peripherals.put(device.getAddress(), peripheral);

								BundleJSONConverter bjc = new BundleJSONConverter();
								try {
									Bundle bundle = bjc.convertToBundle(peripheral.asJSONObject());
									WritableMap map = Arguments.fromBundle(bundle);
									sendEvent("BluetoothManagerDiscoverPeripheral", map);
								} catch (JSONException e) {

								}


							} else {
								// this isn't necessary
								Peripheral peripheral = peripherals.get(address);
								peripheral.updateRssi(rssi);
							}
						}
					});
				}


			};

	@ReactMethod
	public void checkState(){
		Log.d(LOG_TAG, "checkState");

		BluetoothAdapter adapter = getBluetoothAdapter();
		String state = "off";
		switch (adapter.getState()){
			case BluetoothAdapter.STATE_ON:
				state = "on";
				break;
			case BluetoothAdapter.STATE_OFF:
				state = "off";
		}

		WritableMap map = Arguments.createMap();
		map.putString("state", state);
		Log.d(LOG_TAG, "state:" + state);
		sendEvent("BluetoothManagerDidUpdateState", map);
	}

	private final BroadcastReceiver mReceiver = new BroadcastReceiver() {
		@Override
		public void onReceive(Context context, Intent intent) {
			Log.d(LOG_TAG, "onReceive");
			final String action = intent.getAction();

			String stringState = "";
			if (action.equals(BluetoothAdapter.ACTION_STATE_CHANGED)) {
				final int state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE,
						BluetoothAdapter.ERROR);
				switch (state) {
					case BluetoothAdapter.STATE_OFF:
						stringState = "off";
						break;
					case BluetoothAdapter.STATE_TURNING_OFF:
						stringState = "turning_off";
						break;
					case BluetoothAdapter.STATE_ON:
						stringState = "on";
						break;
					case BluetoothAdapter.STATE_TURNING_ON:
						stringState = "turning_on";
						break;
				}
			}

			WritableMap map = Arguments.createMap();
			map.putString("state", stringState);
			Log.d(LOG_TAG, "state: " + stringState);
			sendEvent("BluetoothManagerDidUpdateState", map);
		}
	};




	final protected static char[] hexArray = "0123456789ABCDEF".toCharArray();

	public static String bytesToHex(byte[] bytes) {
		char[] hexChars = new char[bytes.length * 2];
		for (int j = 0; j < bytes.length; j++) {
			int v = bytes[j] & 0xFF;
			hexChars[j * 2] = hexArray[v >>> 4];
			hexChars[j * 2 + 1] = hexArray[v & 0x0F];
		}
		return new String(hexChars);
	}

}
