package it.innove;

import android.bluetooth.BluetoothDevice;
import android.bluetooth.le.ScanRecord;
import android.os.Build;
import android.os.ParcelUuid;
import android.support.annotation.RequiresApi;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;

import java.util.Map;

@RequiresApi(Build.VERSION_CODES.LOLLIPOP)
public class LollipopPeripheral extends Peripheral {

	private ScanRecord advertisingData;

	public LollipopPeripheral(BluetoothDevice device, int advertisingRSSI, ScanRecord scanRecord, ReactContext reactContext) {
		super(device, advertisingRSSI, scanRecord.getBytes(), reactContext);
		this.advertisingData = scanRecord;
	}

	public LollipopPeripheral(BluetoothDevice device, ReactApplicationContext reactContext) {
		super(device, reactContext);
	}

	@Override
	public WritableMap asWritableMap() {
		WritableMap map = super.asWritableMap();
		WritableMap advertising = Arguments.createMap();

		try {
			advertising.putMap("manufacturerData", byteArrayToWritableMap(advertisingDataBytes));
			advertising.putBoolean("isConnectable", true);

			if (advertisingData != null) {
				String deviceName = advertisingData.getDeviceName();
				if (deviceName != null)
					advertising.putString("localName", deviceName.replace("\0", ""));

				WritableArray serviceUuids = Arguments.createArray();
				if (advertisingData.getServiceUuids() != null && advertisingData.getServiceUuids().size() != 0) {
					for (ParcelUuid uuid : advertisingData.getServiceUuids()) {
						serviceUuids.pushString(UUIDHelper.uuidToString(uuid.getUuid()));
					}
				}
				advertising.putArray("serviceUUIDs", serviceUuids);

				WritableMap serviceData = Arguments.createMap();
				if (advertisingData.getServiceData() != null) {
					for (Map.Entry<ParcelUuid, byte[]> entry : advertisingData.getServiceData().entrySet()) {
						if (entry.getValue() != null) {
							serviceData.putMap(UUIDHelper.uuidToString((entry.getKey()).getUuid()), byteArrayToWritableMap(entry.getValue()));
						}
					}
				}

                advertising.putMap("serviceData", serviceData);
				advertising.putInt("txPowerLevel", advertisingData.getTxPowerLevel());
			}

			map.putMap("advertising", advertising);
		} catch (Exception e) { // this shouldn't happen
			e.printStackTrace();
		}

		return map;
	}

	public void updateData(ScanRecord scanRecord) {
		advertisingData = scanRecord;
		advertisingDataBytes = scanRecord.getBytes();
	}


}
