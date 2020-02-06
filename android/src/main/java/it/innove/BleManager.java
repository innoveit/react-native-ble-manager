package it.innove;

import android.app.Activity;
import android.app.PendingIntent;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import androidx.annotation.Nullable;

import android.os.Bundle;
import android.os.Handler;
import android.os.ResultReceiver;
import android.preference.PreferenceManager;
import android.util.Log;
import com.facebook.react.bridge.*;
import com.facebook.react.modules.core.RCTNativeAppEventEmitter;
import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.lang.reflect.Method;
import java.util.*;

import static android.app.Activity.RESULT_OK;
import static android.bluetooth.BluetoothProfile.GATT;
import static android.os.Build.VERSION_CODES.LOLLIPOP;
import static com.facebook.react.bridge.UiThreadUtil.runOnUiThread;


class BleManager extends ReactContextBaseJavaModule implements ActivityEventListener {

	public static final String LOG_TAG = "ReactNativeBleManager";
	private static final int ENABLE_REQUEST = 539;

	private class BondRequest {
		private String uuid;
		private Callback callback;

		BondRequest(String _uuid, Callback _callback) {
			uuid = _uuid;
			callback = _callback;
		}
	}

	private BluetoothAdapter bluetoothAdapter;
	private BluetoothManager bluetoothManager;
	private Context context;
	private ReactApplicationContext reactContext;
	private Callback enableBluetoothCallback;
	private ScanManager scanManager;
	private BondRequest bondRequest;
	private BondRequest removeBondRequest;


	private ResultReceiver getReceiver(final Callback callback) {
		return new ResultReceiver(new Handler()) {
			protected void onReceiveResult(int resultCode, Bundle resultData) {
				Log.d("ReactNativeBleManager", "Callback Invoked");
				ArrayList args = (ArrayList) new Gson().fromJson(resultData.getString("ARGS"), Object.class);
				if(args != null) {
					callback.invoke(args.toArray(new Object[args.size()]));
				} else {
					callback.invoke();
				}

			}
		};
	}

	private ResultReceiver getEventReciever() {
		return new ResultReceiver(new Handler()) {
			protected void onReceiveResult(int resultCode, Bundle resultData) {
				String eventName = resultData.getString("EVENTNAME");
				String paramsStr = resultData.getString("PARAMS");
				WritableMap params = null;

				if(paramsStr != null) {
					JSONObject paramsObject = null;
					try {
						paramsObject = new JSONObject(paramsStr);
						params = convertJsonToMap(paramsObject);
					} catch (JSONException e) {
						e.printStackTrace();
						return;
					}
				}
				sendEvent(eventName, params);
			}
		};
	}
	// key is the MAC Address
	public Map<String, Peripheral> peripherals = new LinkedHashMap<>();
	// scan session id


	public BleManager(ReactApplicationContext reactContext) {
		super(reactContext);
		context = reactContext;
		this.reactContext = reactContext;
		reactContext.addActivityEventListener(this);
		Log.d(LOG_TAG, "BleManager created");
	}

	@Override
	public String getName() {
		return "BleManager";
	}

	private BluetoothAdapter getBluetoothAdapter() {
		if (bluetoothAdapter == null) {
			BluetoothManager manager = (BluetoothManager) context.getSystemService(Context.BLUETOOTH_SERVICE);
			bluetoothAdapter = manager.getAdapter();
		}
		return bluetoothAdapter;
	}

	private BluetoothManager getBluetoothManager() {
		if (bluetoothManager == null) {
			bluetoothManager = (BluetoothManager) context.getSystemService(Context.BLUETOOTH_SERVICE);
		}
		return bluetoothManager;
	}

	public void sendEvent(String eventName,
						  @Nullable WritableMap params) {
		getReactApplicationContext()
				.getJSModule(RCTNativeAppEventEmitter.class)
				.emit(eventName, params);
	}

	@ReactMethod
	public void start(ReadableMap options, Callback callback) {
		Log.d(LOG_TAG, "start");
		if (getBluetoothAdapter() == null) {
			Log.d(LOG_TAG, "No bluetooth support");
			callback.invoke("No bluetooth support");
			return;
		}
		boolean forceLegacy = false;
		if (options.hasKey("forceLegacy")) {
			forceLegacy = options.getBoolean("forceLegacy");
		}

		if (Build.VERSION.SDK_INT >= LOLLIPOP && !forceLegacy) {
			scanManager = new LollipopScanManager(reactContext, this);
		} else {
			scanManager = new LegacyScanManager(reactContext, this);
		}

		IntentFilter filter = new IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED);
		filter.addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED);
		context.registerReceiver(mReceiver, filter);
		callback.invoke();
		Log.d(LOG_TAG, "BleManager initialized");
	}

	@ReactMethod
	public void enableBluetooth(Callback callback) {
		if (getBluetoothAdapter() == null) {
			Log.d(LOG_TAG, "No bluetooth support");
			callback.invoke("No bluetooth support");
			return;
		}
		if (!getBluetoothAdapter().isEnabled()) {
			enableBluetoothCallback = callback;
			Intent intentEnable = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);
			if (getCurrentActivity() == null)
				callback.invoke("Current activity not available");
			else
				getCurrentActivity().startActivityForResult(intentEnable, ENABLE_REQUEST);
		} else
			callback.invoke();
	}

	@ReactMethod
	public void scan(ReadableArray serviceUUIDs, final int scanSeconds, boolean allowDuplicates, ReadableMap options, Callback callback) {
		Log.d(LOG_TAG, "scan");
		if (getBluetoothAdapter() == null) {
			Log.d(LOG_TAG, "No bluetooth support");
			callback.invoke("No bluetooth support");
			return;
		}
		if (!getBluetoothAdapter().isEnabled()) {
			return;
		}

		for (Iterator<Map.Entry<String, Peripheral>> iterator = peripherals.entrySet().iterator(); iterator.hasNext(); ) {
			Map.Entry<String, Peripheral> entry = iterator.next();
			if (!entry.getValue().isConnected()) {
				iterator.remove();
			}
		}

		scanManager.scan(serviceUUIDs, scanSeconds, options, callback);
	}

	@ReactMethod
	public void stopScan(Callback callback) {
		Log.d(LOG_TAG, "Stop scan");
		if (getBluetoothAdapter() == null) {
			Log.d(LOG_TAG, "No bluetooth support");
			callback.invoke("No bluetooth support");
			return;
		}
		if (!getBluetoothAdapter().isEnabled()) {
			callback.invoke();
			return;
		}
		scanManager.stopScan(callback);
	}

	@ReactMethod
	public void createBond(String peripheralUUID, Callback callback) {
		Log.d(LOG_TAG, "Request bond to: " + peripheralUUID);

		Set<BluetoothDevice> deviceSet = getBluetoothAdapter().getBondedDevices();
		for (BluetoothDevice device : deviceSet) {
			if (peripheralUUID.equalsIgnoreCase(device.getAddress())) {
				callback.invoke();
				return;
			}
		}

		Peripheral peripheral = retrieveOrCreatePeripheral(peripheralUUID);
		if (peripheral == null) {
			callback.invoke("Invalid peripheral uuid");
		} else if (bondRequest != null) {
			callback.invoke("Only allow one bond request at a time");
		} else if (peripheral.getDevice().createBond()) {
			bondRequest = new BondRequest(peripheralUUID, callback); // request bond success, waiting for boradcast
			return;
		}

		callback.invoke("Create bond request fail");
	}

	@ReactMethod
	private void removeBond(String peripheralUUID, Callback callback) {
		Log.d(LOG_TAG, "Remove bond to: " + peripheralUUID);

		Peripheral peripheral = retrieveOrCreatePeripheral(peripheralUUID);
		if (peripheral == null) {
			callback.invoke("Invalid peripheral uuid");
			return;
		} else {
			try {
				Method m = peripheral.getDevice().getClass().getMethod("removeBond", (Class[]) null);
				m.invoke(peripheral.getDevice(), (Object[]) null);
				removeBondRequest = new BondRequest(peripheralUUID, callback);
				return;
			} catch (Exception e) {
				Log.d(LOG_TAG, "Error in remove bond: " + peripheralUUID, e);
				callback.invoke("Remove bond request fail");
			}
		}

	}

	@ReactMethod
	public void connect(String peripheralUUID, final Callback callback) {
		Log.d(LOG_TAG, "Connect to: " + peripheralUUID);

		Peripheral peripheral = retrieveOrCreatePeripheral(peripheralUUID);

		if (peripheral == null) {
			callback.invoke("Invalid peripheral uuid");
			return;
		}


		Intent serviceIntent = new Intent(getReactApplicationContext(), PeripheralService.class)
				.putExtra("UUID", peripheralUUID)
				.putExtra("ACTION", "CONNECT")
				.putExtra("resultReciever", getReceiver(callback))
				.putExtra("eventReciever", getEventReciever());

		getReactApplicationContext().startService(serviceIntent);

	}

	@ReactMethod
	public void disconnect(String peripheralUUID, Callback callback) {
		Log.d(LOG_TAG, "Disconnect from: " + peripheralUUID);

		Peripheral peripheral = peripherals.get(peripheralUUID);
		if (peripheral != null) {
			Intent serviceIntent = new Intent(getReactApplicationContext(), PeripheralService.class)
					.putExtra("UUID", peripheralUUID)
					.putExtra("ACTION", "DISCONNECT")
					.putExtra("resultReciever", getReceiver(callback))
					.putExtra("eventReciever", getEventReciever());

			getReactApplicationContext().startService(serviceIntent);
		} else
			callback.invoke("Peripheral not found");
	}

	@ReactMethod
	public void startNotification(String deviceUUID, String serviceUUID, String characteristicUUID, Callback callback) {
		Log.d(LOG_TAG, "startNotification");

		Peripheral peripheral = peripherals.get(deviceUUID);
		if (peripheral != null) {
			Intent serviceIntent = new Intent(getReactApplicationContext(), PeripheralService.class)
					.putExtra("UUID", deviceUUID)
					.putExtra("SERVICEUUID", serviceUUID)
					.putExtra("CHARACTERISTICUUID", characteristicUUID)
					.putExtra("ACTION", "STARTNOTIFICATION")
					.putExtra("resultReciever", getReceiver(callback))
					.putExtra("eventReciever", getEventReciever());

			getReactApplicationContext().startService(serviceIntent);
		} else
			callback.invoke("Peripheral not found");
	}

	@ReactMethod
	public void stopNotification(String deviceUUID, String serviceUUID, String characteristicUUID, Callback callback) {
		Log.d(LOG_TAG, "stopNotification");

		Peripheral peripheral = peripherals.get(deviceUUID);
		if (peripheral != null) {
			Intent serviceIntent = new Intent(getReactApplicationContext(), PeripheralService.class)
					.putExtra("UUID", deviceUUID)
					.putExtra("SERVICEUUID", serviceUUID)
					.putExtra("CHARACTERISTICUUID", characteristicUUID)
					.putExtra("ACTION", "STOPNOTIFICATION")
					.putExtra("resultReciever", getReceiver(callback))
					.putExtra("eventReciever", getEventReciever());

			getReactApplicationContext().startService(serviceIntent);
		} else
			callback.invoke("Peripheral not found");
	}

	@ReactMethod
	public void setServiceRecoveryData(ReadableMap data, Callback callback) {
		// sets last ble usage for recovery by service

		if(data != null) {
			try {
				PreferenceManager.getDefaultSharedPreferences(getReactApplicationContext()).edit().putString("serviceRecoveryData", convertMapToJson(data).toString()).commit();
			} catch (JSONException e) {
				callback.invoke("Write service recovery data failed due to JSONException");
				e.printStackTrace();
			}
		} else {
			PreferenceManager.getDefaultSharedPreferences(getReactApplicationContext()).edit().putString("serviceRecoveryData", new JsonObject().toString()).commit();
		}

		callback.invoke();
	}


	@ReactMethod
	public void write(String deviceUUID, String serviceUUID, String characteristicUUID, ReadableArray message, Integer maxByteSize, Callback callback) {
		Log.d(LOG_TAG, "Write to: " + deviceUUID);

		Peripheral peripheral = peripherals.get(deviceUUID);
		if (peripheral != null) {
			byte[] decoded = new byte[message.size()];
			for (int i = 0; i < message.size(); i++) {
				decoded[i] = new Integer(message.getInt(i)).byteValue();
			}

			String strMessage =  bytesToHex(decoded);
			Log.d(LOG_TAG, "Message(" + decoded.length + "): " + strMessage);

			Intent serviceIntent = new Intent(getReactApplicationContext(), PeripheralService.class)
					.putExtra("UUID", deviceUUID)
					.putExtra("SERVICEUUID", serviceUUID)
					.putExtra("DECODED", decoded)
					.putExtra("MESSAGE", strMessage)
					.putExtra("MAXBYTESIZE", maxByteSize)
					.putExtra("CHARACTERISTICUUID", characteristicUUID)
					.putExtra("ACTION", "WRITE")
					.putExtra("resultReciever", getReceiver(callback))
					.putExtra("eventReciever", getEventReciever());

			getReactApplicationContext().startService(serviceIntent);
		} else
			callback.invoke("Peripheral not found");
	}

	@ReactMethod
	public void writeWithoutResponse(String deviceUUID, String serviceUUID, String characteristicUUID, ReadableArray message, Integer maxByteSize, Integer queueSleepTime, Callback callback) {
		Log.d(LOG_TAG, "Write without response to: " + deviceUUID);

		Peripheral peripheral = peripherals.get(deviceUUID);
		if (peripheral != null) {
			byte[] decoded = new byte[message.size()];
			for (int i = 0; i < message.size(); i++) {
				decoded[i] = new Integer(message.getInt(i)).byteValue();
			}
			Log.d(LOG_TAG, "Message(" + decoded.length + "): " + bytesToHex(decoded));
			Intent serviceIntent = new Intent(getReactApplicationContext(), PeripheralService.class)
					.putExtra("UUID", deviceUUID)
					.putExtra("SERVICEUUID", serviceUUID)
					.putExtra("DECODED", decoded)
					.putExtra("MAXBYTESIZE", maxByteSize)
					.putExtra("CHARACTERISTICUUID", characteristicUUID)
					.putExtra("ACTION", "WRITEWITHOUTRESPONSE")
					.putExtra("resultReciever", getReceiver(callback))
					.putExtra("eventReciever", getEventReciever());

			getReactApplicationContext().startService(serviceIntent);
		} else
			callback.invoke("Peripheral not found");
	}

	@ReactMethod
	public void read(String deviceUUID, String serviceUUID, String characteristicUUID, final Callback callback) {
		Log.d(LOG_TAG, "Read from: " + deviceUUID);
		ResultReceiver reciever = new ResultReceiver(new Handler()) {
			protected void onReceiveResult(int resultCode, Bundle resultData) {
				Log.d("ReactNativeBleManager", "Callback Invoked");
				ArrayList args = (ArrayList) new Gson().fromJson(resultData.getString("ARGS"), Object.class);
				String paramsStr = resultData.getString("MAP");
				WritableArray params = null;

				if(paramsStr != null) {
					JSONArray paramsObject = null;
					try {
						paramsObject = new JSONArray(paramsStr);
						params = convertJsonToArray(paramsObject);
					} catch (JSONException e) {
						e.printStackTrace();
						callback.invoke();
						return;
					}
					if(args != null) {
						args.add(params);
					} else {
						args = new ArrayList();
						args.add(null);
						args.add(params);
					}
				}
				if(args != null) {
					callback.invoke(args.toArray(new Object[args.size()]));
				} else {
					callback.invoke();
				}

			}
		};
		Peripheral peripheral = peripherals.get(deviceUUID);
		if (peripheral != null) {
			Intent serviceIntent = new Intent(getReactApplicationContext(), PeripheralService.class)
					.putExtra("UUID", deviceUUID)
					.putExtra("SERVICEUUID", serviceUUID)
					.putExtra("CHARACTERISTICUUID", characteristicUUID)
					.putExtra("ACTION", "READ")
					.putExtra("resultReciever", reciever)
					.putExtra("eventReciever", getEventReciever());

			getReactApplicationContext().startService(serviceIntent);
		} else
			callback.invoke("Peripheral not found", null);
	}

	@ReactMethod
	public void retrieveServices(String deviceUUID, final Callback callback) {
		Log.d(LOG_TAG, "Retrieve services from: " + deviceUUID);
		ResultReceiver reciever = new ResultReceiver(new Handler()) {
				protected void onReceiveResult(int resultCode, Bundle resultData) {
					Log.d("ReactNativeBleManager", "Callback Invoked");
					ArrayList args = (ArrayList) new Gson().fromJson(resultData.getString("ARGS"), Object.class);
					String paramsStr = resultData.getString("MAP");
					WritableMap params = null;

					if(paramsStr != null) {
						JSONObject paramsObject = null;
						try {
							paramsObject = new JSONObject(paramsStr);
							params = convertJsonToMap(paramsObject);
						} catch (JSONException e) {
							callback.invoke();
							return;
						}
						if(args != null) {
							args.add(params);
						} else {
							args = new ArrayList();
							args.add(null);
							args.add(params);
						}
					}
					if(args != null) {
						callback.invoke(args.toArray(new Object[args.size()]));
					} else {
						callback.invoke();
					}

				}
			};
		Peripheral peripheral = peripherals.get(deviceUUID);
		if (peripheral != null) {
			Intent serviceIntent = new Intent(getReactApplicationContext(), PeripheralService.class)
					.putExtra("UUID", deviceUUID)
					.putExtra("ACTION", "RETRIEVESERVICES")
					.putExtra("resultReciever", reciever)
					.putExtra("eventReciever", getEventReciever());

			getReactApplicationContext().startService(serviceIntent);
		} else
			callback.invoke("Peripheral not found", null);
	}

	private static WritableMap convertJsonToMap(JSONObject jsonObject) throws JSONException {
		WritableMap map = new WritableNativeMap();

		Iterator<String> iterator = jsonObject.keys();
		while (iterator.hasNext()) {
			String key = iterator.next();
			Object value = jsonObject.get(key);
			if (value instanceof JSONObject) {
				map.putMap(key, convertJsonToMap((JSONObject) value));
			} else if (value instanceof JSONArray) {
				map.putArray(key, convertJsonToArray((JSONArray) value));
			} else if (value instanceof  Boolean) {
				map.putBoolean(key, (Boolean) value);
			} else if (value instanceof  Integer) {
				map.putInt(key, (Integer) value);
			} else if (value instanceof  Double) {
				map.putDouble(key, (Double) value);
			} else if (value instanceof String)  {
				map.putString(key, (String) value);
			} else {
				map.putString(key, value.toString());
			}
		}
		return map;
	}

	private static WritableArray convertJsonToArray(JSONArray jsonArray) throws JSONException {
		WritableArray array = new WritableNativeArray();

		for (int i = 0; i < jsonArray.length(); i++) {
			Object value = jsonArray.get(i);
			if (value instanceof JSONObject) {
				array.pushMap(convertJsonToMap((JSONObject) value));
			} else if (value instanceof  JSONArray) {
				array.pushArray(convertJsonToArray((JSONArray) value));
			} else if (value instanceof  Boolean) {
				array.pushBoolean((Boolean) value);
			} else if (value instanceof  Integer) {
				array.pushInt((Integer) value);
			} else if (value instanceof  Double) {
				array.pushDouble((Double) value);
			} else if (value instanceof String)  {
				array.pushString((String) value);
			} else {
				array.pushString(value.toString());
			}
		}
		return array;
	}


	@ReactMethod
	public void refreshCache(String deviceUUID, Callback callback) {
		Log.d(LOG_TAG, "Refershing cache for: " + deviceUUID);
		Peripheral peripheral = peripherals.get(deviceUUID);
		if (peripheral != null) {
			Intent serviceIntent = new Intent(getReactApplicationContext(), PeripheralService.class)
					.putExtra("UUID", deviceUUID)
					.putExtra("ACTION", "REFRESHCACHE")
					.putExtra("resultReciever", getReceiver(callback))
					.putExtra("eventReciever", getEventReciever());

			getReactApplicationContext().startService(serviceIntent);
		} else
			callback.invoke("Peripheral not found");
	}

	@ReactMethod
	public void readRSSI(String deviceUUID, Callback callback) {
		Log.d(LOG_TAG, "Read RSSI from: " + deviceUUID);
		Peripheral peripheral = peripherals.get(deviceUUID);
		if (peripheral != null) {
			Intent serviceIntent = new Intent(getReactApplicationContext(), PeripheralService.class)
					.putExtra("UUID", deviceUUID)
					.putExtra("ACTION", "READRSSI")
					.putExtra("resultReciever", getReceiver(callback))
					.putExtra("eventReciever", getEventReciever());

			getReactApplicationContext().startService(serviceIntent);
		} else
			callback.invoke("Peripheral not found", null);
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
								WritableMap map = peripheral.asWritableMap();
								sendEvent("BleManagerDiscoverPeripheral", map);
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
	public void checkState() {
		Log.d(LOG_TAG, "checkState");

		BluetoothAdapter adapter = getBluetoothAdapter();
		String state = "off";
		if (adapter != null) {
			switch (adapter.getState()) {
				case BluetoothAdapter.STATE_ON:
					state = "on";
					break;
				case BluetoothAdapter.STATE_OFF:
					state = "off";
			}
		}

		WritableMap map = Arguments.createMap();
		map.putString("state", state);
		Log.d(LOG_TAG, "state:" + state);
		sendEvent("BleManagerDidUpdateState", map);
	}

	private final BroadcastReceiver mReceiver = new BroadcastReceiver() {
		@Override
		public void onReceive(Context context, Intent intent) {
			Log.d(LOG_TAG, "onReceive");
			final String action = intent.getAction();

			if (action.equals(BluetoothAdapter.ACTION_STATE_CHANGED)) {
				final int state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE,
						BluetoothAdapter.ERROR);
				String stringState = "";

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

				WritableMap map = Arguments.createMap();
				map.putString("state", stringState);
				Log.d(LOG_TAG, "state: " + stringState);
				sendEvent("BleManagerDidUpdateState", map);

			} else if (action.equals(BluetoothDevice.ACTION_BOND_STATE_CHANGED)) {
				final int bondState = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.ERROR);
				final int prevState    = intent.getIntExtra(BluetoothDevice.EXTRA_PREVIOUS_BOND_STATE, BluetoothDevice.ERROR);
				BluetoothDevice device = (BluetoothDevice) intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);

				String bondStateStr = "UNKNOWN";
				switch (bondState) {
					case BluetoothDevice.BOND_BONDED:
						bondStateStr = "BOND_BONDED";
						break;
					case BluetoothDevice.BOND_BONDING:
						bondStateStr = "BOND_BONDING";
						break;
					case BluetoothDevice.BOND_NONE:
						bondStateStr = "BOND_NONE";
						break;
				}
				Log.d(LOG_TAG, "bond state: " + bondStateStr);

				if (bondRequest != null && bondRequest.uuid.equals(device.getAddress())) {
					if (bondState == BluetoothDevice.BOND_BONDED) {
						bondRequest.callback.invoke();
						bondRequest = null;
					} else if (bondState == BluetoothDevice.BOND_NONE || bondState == BluetoothDevice.ERROR) {
						bondRequest.callback.invoke("Bond request has been denied");
						bondRequest = null;
					}
				}
				if (removeBondRequest != null && removeBondRequest.uuid.equals(device.getAddress()) && bondState == BluetoothDevice.BOND_NONE && prevState == BluetoothDevice.BOND_BONDED){
					removeBondRequest.callback.invoke();
					removeBondRequest = null;
				}
			}

		}
	};

	@ReactMethod
	public void getDiscoveredPeripherals(Callback callback) {
		Log.d(LOG_TAG, "Get discovered peripherals");
		WritableArray map = Arguments.createArray();
		Map<String, Peripheral> peripheralsCopy = new LinkedHashMap<>(peripherals);
		for (Map.Entry<String, Peripheral> entry : peripheralsCopy.entrySet()) {
			Peripheral peripheral = entry.getValue();
			WritableMap jsonBundle = peripheral.asWritableMap();
			map.pushMap(jsonBundle);
		}
		callback.invoke(null, map);
	}

	@ReactMethod
	public void getConnectedPeripherals(ReadableArray serviceUUIDs, Callback callback) {
		Log.d(LOG_TAG, "Get connected peripherals");
		WritableArray map = Arguments.createArray();

		List<BluetoothDevice> periperals = getBluetoothManager().getConnectedDevices(GATT);
		for (BluetoothDevice entry : periperals) {
			Peripheral peripheral = new Peripheral(entry, reactContext);
			WritableMap jsonBundle = peripheral.asWritableMap();
			map.pushMap(jsonBundle);
		}
		callback.invoke(null, map);
	}

	@ReactMethod
	public void getBondedPeripherals(Callback callback) {
		Log.d(LOG_TAG, "Get bonded peripherals");
		WritableArray map = Arguments.createArray();
		Set<BluetoothDevice> deviceSet = getBluetoothAdapter().getBondedDevices();
		for (BluetoothDevice device : deviceSet) {
			Peripheral peripheral = new Peripheral(device, reactContext);
			WritableMap jsonBundle = peripheral.asWritableMap();
			map.pushMap(jsonBundle);
		}
		callback.invoke(null, map);
	}

	@ReactMethod
	public void removePeripheral(String deviceUUID, Callback callback) {
		Log.d(LOG_TAG, "Removing from list: " + deviceUUID);
		Peripheral peripheral = peripherals.get(deviceUUID);
		if (peripheral != null) {
			if (peripheral.isConnected()) {
				callback.invoke("Peripheral can not be removed while connected");
			} else {
				peripherals.remove(deviceUUID);
				callback.invoke();
			}
		} else
			callback.invoke("Peripheral not found");
	}

	@ReactMethod
	public void requestConnectionPriority(String deviceUUID, int connectionPriority, Callback callback) {
		Log.d(LOG_TAG, "Request connection priority of " + connectionPriority + " from: " + deviceUUID);
		Peripheral peripheral = peripherals.get(deviceUUID);
		if (peripheral != null) {
			Intent serviceIntent = new Intent(getReactApplicationContext(), PeripheralService.class)
					.putExtra("UUID", deviceUUID)
					.putExtra("CONNECTIONPRIORITY", connectionPriority)
					.putExtra("ACTION", "REQUESTCONNECTIONPRIORITY")
					.putExtra("resultReciever", getReceiver(callback))
					.putExtra("eventReciever", getEventReciever());

			getReactApplicationContext().startService(serviceIntent);
		} else {
			callback.invoke("Peripheral not found", null);
		}
	}

	@ReactMethod
	public void requestMTU(String deviceUUID, int mtu, Callback callback) {
		Log.d(LOG_TAG, "Request MTU of " + mtu + " bytes from: " + deviceUUID);
		Peripheral peripheral = peripherals.get(deviceUUID);
		if (peripheral != null) {
			Intent serviceIntent = new Intent(getReactApplicationContext(), PeripheralService.class)
					.putExtra("UUID", deviceUUID)
					.putExtra("MTU", mtu)
					.putExtra("ACTION", "REQUESTMTU")
					.putExtra("resultReciever", getReceiver(callback))
					.putExtra("eventReciever", getEventReciever());

			getReactApplicationContext().startService(serviceIntent);

		} else {
			callback.invoke("Peripheral not found", null);
		}
	}

	private final static char[] hexArray = "0123456789ABCDEF".toCharArray();

	public static String bytesToHex(byte[] bytes) {
		char[] hexChars = new char[bytes.length * 2];
		for (int j = 0; j < bytes.length; j++) {
			int v = bytes[j] & 0xFF;
			hexChars[j * 2] = hexArray[v >>> 4];
			hexChars[j * 2 + 1] = hexArray[v & 0x0F];
		}
		return new String(hexChars);
	}

	public static WritableArray bytesToWritableArray(byte[] bytes) {
		WritableArray value = Arguments.createArray();
		for (int i = 0; i < bytes.length; i++)
			value.pushInt((bytes[i] & 0xFF));
		return value;
	}

	@Override
	public void onActivityResult(Activity activity, int requestCode, int resultCode, Intent data) {
		Log.d(LOG_TAG, "onActivityResult");
		if (requestCode == ENABLE_REQUEST && enableBluetoothCallback != null) {
			if (resultCode == RESULT_OK) {
				enableBluetoothCallback.invoke();
			} else {
				enableBluetoothCallback.invoke("User refused to enable");
			}
			enableBluetoothCallback = null;
		}
	}

	@Override
	public void onNewIntent(Intent intent) {

	}

	private Peripheral retrieveOrCreatePeripheral(String peripheralUUID) {
		Peripheral peripheral = peripherals.get(peripheralUUID);
		if (peripheral == null) {
			if (peripheralUUID != null) {
				peripheralUUID = peripheralUUID.toUpperCase();
			}
			if (BluetoothAdapter.checkBluetoothAddress(peripheralUUID)) {
				BluetoothDevice device = bluetoothAdapter.getRemoteDevice(peripheralUUID);
				peripheral = new Peripheral(device, reactContext);
				peripherals.put(peripheralUUID, peripheral);
			}
		}
		return peripheral;
	}

	private static JSONObject convertMapToJson(ReadableMap readableMap) throws JSONException {
		JSONObject object = new JSONObject();
		ReadableMapKeySetIterator iterator = readableMap.keySetIterator();
		while (iterator.hasNextKey()) {
			String key = iterator.nextKey();
			switch (readableMap.getType(key)) {
				case Null:
					object.put(key, JSONObject.NULL);
					break;
				case Boolean:
					object.put(key, readableMap.getBoolean(key));
					break;
				case Number:
					object.put(key, readableMap.getDouble(key));
					break;
				case String:
					object.put(key, readableMap.getString(key));
					break;
				case Map:
					object.put(key, convertMapToJson(readableMap.getMap(key)));
					break;
				case Array:
					object.put(key, convertArrayToJson(readableMap.getArray(key)));
					break;
			}
		}
		return object;
	}

	private static JSONArray convertArrayToJson(ReadableArray readableArray) throws JSONException {
		JSONArray array = new JSONArray();
		for (int i = 0; i < readableArray.size(); i++) {
			switch (readableArray.getType(i)) {
				case Null:
					break;
				case Boolean:
					array.put(readableArray.getBoolean(i));
					break;
				case Number:
					array.put(readableArray.getDouble(i));
					break;
				case String:
					array.put(readableArray.getString(i));
					break;
				case Map:
					array.put(convertMapToJson(readableArray.getMap(i)));
					break;
				case Array:
					array.put(convertArrayToJson(readableArray.getArray(i)));
					break;
			}
		}
		return array;
	}

}