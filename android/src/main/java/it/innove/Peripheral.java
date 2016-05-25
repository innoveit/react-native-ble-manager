package it.innove;

import android.app.Activity;
import android.bluetooth.*;
import android.support.annotation.Nullable;
import android.util.Base64;
import android.util.Log;
import com.facebook.react.bridge.*;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;

/**
 * Peripheral wraps the BluetoothDevice and provides methods to convert to JSON.
 */
public class Peripheral extends BluetoothGattCallback {

	private static final String CHARACTERISTIC_NOTIFICATION_CONFIG = "00002902-0000-1000-8000-00805f9b34fb";
	public static final String LOG_TAG = "logs";

	private BluetoothDevice device;
	private byte[] advertisingData;
	private int advertisingRSSI;
	private boolean connected = false;
	private ReactContext reactContext;

	private BluetoothGatt gatt;

	private Callback connectCallback;
	private Callback connectFailCallback;
	private Callback readCallback;
	private Callback writeCallback;

	private List<byte[]> writeQueue = new ArrayList<>();

	public Peripheral(BluetoothDevice device, int advertisingRSSI, byte[] scanRecord, ReactContext reactContext) {

		this.device = device;
		this.advertisingRSSI = advertisingRSSI;
		this.advertisingData = scanRecord;
		this.reactContext = reactContext;

	}

	private void sendEvent(String eventName, @Nullable WritableMap params) {
		reactContext
				.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
				.emit(eventName, params);
	}


	public void connect(Callback connectCallback, Callback failCallback, Activity activity) {
		if (!connected) {
			BluetoothDevice device = getDevice();
			this.connectCallback = connectCallback;
			this.connectFailCallback = failCallback;
			gatt = device.connectGatt(activity, false, this);
		}else{
			connectCallback.invoke();
		}
	}

	public void disconnect() {
		connectCallback = null;
		connected = false;
		if (gatt != null) {
			gatt.close();
			gatt = null;
			Log.d(LOG_TAG, "disconnesso");
			WritableMap map = Arguments.createMap();
			map.putString("peripheral", device.getAddress());
			sendEvent("BluetoothManagerDisconnectPeripheral", map);
			Log.d(LOG_TAG, "Forzo BluetoothManagerDisconnectPeripheral peripheral:" + device.getAddress());
		}else
			Log.d(LOG_TAG, "non disconnesso gatt a null");
	}

	public JSONObject asJSONObject() {

		JSONObject json = new JSONObject();

		try {
			json.put("name", device.getName());
			json.put("id", device.getAddress()); // mac address
			json.put("advertising", byteArrayToJSON(advertisingData));
			// TODO real RSSI if we have it, else
			json.put("rssi", advertisingRSSI);
		} catch (JSONException e) { // this shouldn't happen
			e.printStackTrace();
		}

		return json;
	}

	public JSONObject asJSONObject(BluetoothGatt gatt) {

		JSONObject json = asJSONObject();

		try {
			JSONArray servicesArray = new JSONArray();
			JSONArray characteristicsArray = new JSONArray();
			json.put("services", servicesArray);
			json.put("characteristics", characteristicsArray);

			if (connected && gatt != null) {
				for (BluetoothGattService service : gatt.getServices()) {
					servicesArray.put(UUIDHelper.uuidToString(service.getUuid()));

					for (BluetoothGattCharacteristic characteristic : service.getCharacteristics()) {
						JSONObject characteristicsJSON = new JSONObject();
						characteristicsArray.put(characteristicsJSON);

						characteristicsJSON.put("service", UUIDHelper.uuidToString(service.getUuid()));
						characteristicsJSON.put("characteristic", UUIDHelper.uuidToString(characteristic.getUuid()));
						//characteristicsJSON.put("instanceId", characteristic.getInstanceId());

						characteristicsJSON.put("properties", Helper.decodeProperties(characteristic));
						// characteristicsJSON.put("propertiesValue", characteristic.getProperties());

						if (characteristic.getPermissions() > 0) {
							characteristicsJSON.put("permissions", Helper.decodePermissions(characteristic));
							// characteristicsJSON.put("permissionsValue", characteristic.getPermissions());
						}

						JSONArray descriptorsArray = new JSONArray();

						for (BluetoothGattDescriptor descriptor : characteristic.getDescriptors()) {
							JSONObject descriptorJSON = new JSONObject();
							descriptorJSON.put("uuid", UUIDHelper.uuidToString(descriptor.getUuid()));
							descriptorJSON.put("value", descriptor.getValue()); // always blank

							if (descriptor.getPermissions() > 0) {
								descriptorJSON.put("permissions", Helper.decodePermissions(descriptor));
								// descriptorJSON.put("permissionsValue", descriptor.getPermissions());
							}
							descriptorsArray.put(descriptorJSON);
						}
						if (descriptorsArray.length() > 0) {
							characteristicsJSON.put("descriptors", descriptorsArray);
						}
					}
				}
			}
		} catch (JSONException e) { // TODO better error handling
			e.printStackTrace();
		}

		return json;
	}

	static JSONObject byteArrayToJSON(byte[] bytes) throws JSONException {
		JSONObject object = new JSONObject();
		object.put("CDVType", "ArrayBuffer");
		object.put("data", Base64.encodeToString(bytes, Base64.NO_WRAP));
		return object;
	}

	public boolean isConnected() {
		return connected;
	}

	public BluetoothDevice getDevice() {
		return device;
	}

	@Override
	public void onServicesDiscovered(BluetoothGatt gatt, int status) {
		super.onServicesDiscovered(gatt, status);
		connectCallback.invoke();
		connectCallback = null;
		connectFailCallback = null;
	}

	@Override
	public void onConnectionStateChange(BluetoothGatt gatt, int status, int newState) {

		Log.d(LOG_TAG, "onConnectionStateChange da " + status + " a "+ newState + " peripheral:" + device.getAddress());

		this.gatt = gatt;

		if (newState == BluetoothGatt.STATE_CONNECTED) {

			connected = true;
			gatt.discoverServices();

		} else if (newState == BluetoothGatt.STATE_DISCONNECTED){

			if (connected) {
				connected = false;

				if (gatt != null) {
					gatt.close();
					gatt = null;
				}

				WritableMap map = Arguments.createMap();
				map.putString("peripheral", device.getAddress());
				sendEvent("BluetoothManagerDisconnectPeripheral", map);
				Log.d(LOG_TAG, "BluetoothManagerDisconnectPeripheral peripheral:" + device.getAddress());
			}
			if (connectFailCallback != null) {
				connectFailCallback.invoke();
				connectFailCallback = null;
				connectCallback = null;
			}

		}

	}

	public void updateRssi(int rssi) {
		advertisingRSSI = rssi;
	}

	public int unsignedToBytes(byte b) {
		return b & 0xFF;
	}

	@Override
	public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic) {
		super.onCharacteristicChanged(gatt, characteristic);

		//Log.d(LOG_TAG, "onCharacteristicChanged " + characteristic);
		byte[] dataValue = characteristic.getValue();
		Log.d(LOG_TAG, "Letto:" + BleManager.bytesToHex(dataValue) + " da:" + device.getAddress());

		WritableMap map = Arguments.createMap();
		map.putString("peripheral", device.getAddress());
		map.putString("characteristic", characteristic.getUuid().toString());
		map.putString("value", BleManager.bytesToHex(dataValue));
		sendEvent("BluetoothManagerDidUpdateValueForCharacteristic", map);
	}

	@Override
	public void onCharacteristicRead(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status) {
		super.onCharacteristicRead(gatt, characteristic, status);
		Log.d(LOG_TAG, "onCharacteristicRead " + characteristic);

		if (readCallback != null) {

			if (status == BluetoothGatt.GATT_SUCCESS) {
				byte[] dataValue = characteristic.getValue();
				String value = BleManager.bytesToHex(dataValue);

				if (readCallback != null) {
					readCallback.invoke(value);
					readCallback = null;
				}
			} else {
				//readCallback.error("Error reading " + characteristic.getUuid() + " status=" + status);
			}

			readCallback = null;

		}

	}

		@Override
	public void onCharacteristicWrite(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status) {
		super.onCharacteristicWrite(gatt, characteristic, status);
		//Log.d(LOG_TAG, "onCharacteristicWrite " + characteristic);

		if (writeCallback != null) {

			if (writeQueue.size() > 0){
				byte[] data = writeQueue.get(0);
				writeQueue.remove(0);
				//Log.d(LOG_TAG, "rimangono in coda: " + writeQueue.size());
				doWrite(characteristic, data);
			} else {

				if (status == BluetoothGatt.GATT_SUCCESS) {
					writeCallback.invoke();
					Log.e(LOG_TAG, "writeCallback invocato");
				} else {
					//writeCallback.error(status);
					Log.e(LOG_TAG, "errore onCharacteristicWrite:" + status);
				}

				writeCallback = null;
			}
		}else
			Log.e(LOG_TAG, "Nessun callback su write");
	}

	@Override
	public void onDescriptorWrite(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status) {
		super.onDescriptorWrite(gatt, descriptor, status);
		Log.d(LOG_TAG, "onDescriptorWrite " + descriptor);
	}



	// This seems way too complicated
	public void registerNotify(UUID serviceUUID, UUID characteristicUUID, Callback success, Callback fail) {

		Log.d(LOG_TAG, "registerNotify");

		if (gatt == null) {
			fail.invoke("BluetoothGatt is null");
			return;
		}

		BluetoothGattService service = gatt.getService(serviceUUID);
		BluetoothGattCharacteristic characteristic = findNotifyCharacteristic(service, characteristicUUID);
		//String key = generateHashKey(serviceUUID, characteristic);

		if (characteristic != null) {
			Log.d(LOG_TAG, "characteristic ok");

			if (gatt.setCharacteristicNotification(characteristic, true)) {

				BluetoothGattDescriptor descriptor = characteristic.getDescriptor(UUID.fromString(CHARACTERISTIC_NOTIFICATION_CONFIG));
				if (descriptor != null) {
					Log.d(LOG_TAG, "trovato descriptor");

					// prefer notify over indicate
					if ((characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0) {
						Log.d(LOG_TAG, "Characteristic " + characteristicUUID + " set NOTIFY");
						descriptor.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
					} else if ((characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0) {
						Log.d(LOG_TAG, "Characteristic " + characteristicUUID + " set INDICATE");
						descriptor.setValue(BluetoothGattDescriptor.ENABLE_INDICATION_VALUE);
					} else {
						Log.d(LOG_TAG, "Characteristic " + characteristicUUID + " does not have NOTIFY or INDICATE property set");
					}

					if (gatt.writeDescriptor(descriptor)) {
						// Tutto ok
						Log.d(LOG_TAG, "registerNotify completato");
						success.invoke();
					} else {
						fail.invoke("Failed to set client characteristic notification for " + characteristicUUID);
					}

				} else {
					fail.invoke("Set notification failed for " + characteristicUUID);
				}

			} else {
				fail.invoke("Failed to register notification for " + characteristicUUID);
			}

		} else {
			fail.invoke("Characteristic " + characteristicUUID + " not found");
		}

	}

	public void removeNotify(UUID serviceUUID, UUID characteristicUUID, Callback success, Callback fail) {

		Log.d(LOG_TAG, "removeNotify");

		if (gatt == null) {
			fail.invoke("BluetoothGatt is null");
			return;
		}

		BluetoothGattService service = gatt.getService(serviceUUID);
		BluetoothGattCharacteristic characteristic = findNotifyCharacteristic(service, characteristicUUID);
		//String key = generateHashKey(serviceUUID, characteristic);

		if (characteristic != null) {


			if (gatt.setCharacteristicNotification(characteristic, false)) {
				success.success();
			} else {
				// TODO we can probably ignore and return success anyway since we removed the notification callback
				success.error("Failed to stop notification for " + characteristicUUID);
			}

		} else {
			fail.invoke("Characteristic " + characteristicUUID + " not found");
		}


	}

	// Some devices reuse UUIDs across characteristics, so we can't use service.getCharacteristic(characteristicUUID)
	// instead check the UUID and properties for each characteristic in the service until we find the best match
	// This function prefers Notify over Indicate
	private BluetoothGattCharacteristic findNotifyCharacteristic(BluetoothGattService service, UUID characteristicUUID) {
		BluetoothGattCharacteristic characteristic = null;

		try {
			// Check for Notify first
			List<BluetoothGattCharacteristic> characteristics = service.getCharacteristics();
			for (BluetoothGattCharacteristic c : characteristics) {
				if ((c.getProperties() & BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0 && characteristicUUID.equals(c.getUuid())) {
					characteristic = c;
					break;
				}
			}

			if (characteristic != null) return characteristic;

			// If there wasn't Notify Characteristic, check for Indicate
			for (BluetoothGattCharacteristic c : characteristics) {
				if ((c.getProperties() & BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0 && characteristicUUID.equals(c.getUuid())) {
					characteristic = c;
					break;
				}
			}

			// As a last resort, try and find ANY characteristic with this UUID, even if it doesn't have the correct properties
			if (characteristic == null) {
				characteristic = service.getCharacteristic(characteristicUUID);
			}

			return characteristic;
		}catch (Exception e) {
			Log.e(LOG_TAG, "Errore su caratteristica " + characteristicUUID ,e);
			return null;
		}
	}
	/*

	private void readCharacteristic(CallbackContext callbackContext, UUID serviceUUID, UUID characteristicUUID) {

		boolean success = false;

		if (gatt == null) {
			callbackContext.error("BluetoothGatt is null");
			return;
		}

		BluetoothGattService service = gatt.getService(serviceUUID);
		BluetoothGattCharacteristic characteristic = findReadableCharacteristic(service, characteristicUUID);

		if (characteristic == null) {
			callbackContext.error("Characteristic " + characteristicUUID + " not found.");
		} else {
			readCallback = callbackContext;
			if (gatt.readCharacteristic(characteristic)) {
				success = true;
			} else {
				readCallback = null;
				callbackContext.error("Read failed");
			}
		}

		if (!success) {
			commandCompleted();
		}

	}

	// Some peripherals re-use UUIDs for multiple characteristics so we need to check the properties
	// and UUID of all characteristics instead of using service.getCharacteristic(characteristicUUID)
	private BluetoothGattCharacteristic findReadableCharacteristic(BluetoothGattService service, UUID characteristicUUID) {
		BluetoothGattCharacteristic characteristic = null;

		int read = BluetoothGattCharacteristic.PROPERTY_READ;

		List<BluetoothGattCharacteristic> characteristics = service.getCharacteristics();
		for (BluetoothGattCharacteristic c : characteristics) {
			if ((c.getProperties() & read) != 0 && characteristicUUID.equals(c.getUuid())) {
				characteristic = c;
				break;
			}
		}

		// As a last resort, try and find ANY characteristic with this UUID, even if it doesn't have the correct properties
		if (characteristic == null) {
			characteristic = service.getCharacteristic(characteristicUUID);
		}

		return characteristic;
	}
*/


	public void doWrite(BluetoothGattCharacteristic characteristic, byte[] data) {

		//Log.d(LOG_TAG, "doWrite");

		characteristic.setValue(data);

		if (gatt.writeCharacteristic(characteristic)) {
			//Log.d(LOG_TAG, "doWrite completato");
		} else {
			Log.d(LOG_TAG, "errore doWrite");
		}

	}

	public void write(UUID serviceUUID, UUID characteristicUUID, byte[] data, Callback successCallback, Callback failCallback, int writeType) {

		Log.d(LOG_TAG, "write interno peripheral");

		if (gatt == null) {
			failCallback.invoke("BluetoothGatt is null");

		}else {

			BluetoothGattService service = gatt.getService(serviceUUID);
			BluetoothGattCharacteristic characteristic = findWritableCharacteristic(service, characteristicUUID, writeType);
			characteristic.setWriteType(writeType);

			if (characteristic == null) {
				failCallback.invoke("Characteristic " + characteristicUUID + " not found.");
			} else {

				if (writeQueue.size() > 0) {
					failCallback.invoke("Scrittura con byte ancora in coda");
				}

				if ( writeCallback != null) {
					failCallback.invoke("Altra scrittura in corso");
				}

				if (writeQueue.size() == 0 && writeCallback == null) {

					if (BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT == writeType)
						writeCallback = successCallback;
					else
						successCallback.invoke();

					if (data.length > 20) {
						int dataLength = data.length;
						int count = 0;
						byte[] firstMessage = null;
						while (count < dataLength && (dataLength - count > 20)) {
							if (count == 0) {
								firstMessage = Arrays.copyOfRange(data, count, count + 20);
							} else {
								byte[] splitMessage = Arrays.copyOfRange(data, count, count + 20);
								writeQueue.add(splitMessage);
							}
							count += 20;
						}
						if (count < dataLength) {
							// Rimangono byte in coda
							byte[] splitMessage = Arrays.copyOfRange(data, count, data.length);
							Log.d(LOG_TAG, "Lunghezza ultimo messaggio: " + splitMessage.length);
							writeQueue.add(splitMessage);
						}

						Log.d(LOG_TAG, "Messaggi in coda: " + writeQueue.size());
						doWrite(characteristic, firstMessage);
					} else {
						characteristic.setValue(data);


						if (gatt.writeCharacteristic(characteristic)) {
							Log.d(LOG_TAG, "write completato");
						} else {
							writeCallback = null;
							failCallback.invoke("Write failed");
						}
					}
				}
			}
		}

	}

	// Some peripherals re-use UUIDs for multiple characteristics so we need to check the properties
	// and UUID of all characteristics instead of using service.getCharacteristic(characteristicUUID)
	private BluetoothGattCharacteristic findWritableCharacteristic(BluetoothGattService service, UUID characteristicUUID, int writeType) {
		try {
			BluetoothGattCharacteristic characteristic = null;

			// get write property
			int writeProperty = BluetoothGattCharacteristic.PROPERTY_WRITE;
			if (writeType == BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE) {
				writeProperty = BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE;
			}

			List<BluetoothGattCharacteristic> characteristics = service.getCharacteristics();
			for (BluetoothGattCharacteristic c : characteristics) {
				if ((c.getProperties() & writeProperty) != 0 && characteristicUUID.equals(c.getUuid())) {
					characteristic = c;
					break;
				}
			}

			// As a last resort, try and find ANY characteristic with this UUID, even if it doesn't have the correct properties
			if (characteristic == null) {
				characteristic = service.getCharacteristic(characteristicUUID);
			}

			return characteristic;
		}catch (Exception e) {
			Log.e(LOG_TAG, "Errore su findWritableCharacteristic", e);
			return null;
		}
	}

	private String generateHashKey(BluetoothGattCharacteristic characteristic) {
		return generateHashKey(characteristic.getService().getUuid(), characteristic);
	}

	private String generateHashKey(UUID serviceUUID, BluetoothGattCharacteristic characteristic) {
		return String.valueOf(serviceUUID) + "|" + characteristic.getUuid() + "|" + characteristic.getInstanceId();
	}

}