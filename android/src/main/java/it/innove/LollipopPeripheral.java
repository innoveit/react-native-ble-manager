package it.innove;

import android.bluetooth.BluetoothDevice;
import android.bluetooth.le.ScanRecord;
import android.bluetooth.le.ScanResult;
import android.os.Build;
import android.os.ParcelUuid;
import androidx.annotation.RequiresApi;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;

import java.util.Map;

@RequiresApi(Build.VERSION_CODES.LOLLIPOP)
public class LollipopPeripheral extends Peripheral {

	private ScanRecord advertisingData;
	private ScanResult scanResult;

	public LollipopPeripheral(ReactContext reactContext, ScanResult result) {
		super(result.getDevice(), result.getRssi(), result.getScanRecord().getBytes(), reactContext);
		this.advertisingData = result.getScanRecord();
		this.scanResult = result;
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

			if (android.os.Build.VERSION.SDK_INT >= Build.VERSION_CODES.O){
				// We can check if peripheral is connectable using the scanresult
				if (this.scanResult != null) {
					advertising.putBoolean("isConnectable", scanResult.isConnectable());
				}
			} else{
				// We can't check if peripheral is connectable
				advertising.putBoolean("isConnectable", true);
			}


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

	public void updateData(ScanResult result) {
		advertisingData = result.getScanRecord();
		advertisingDataBytes = advertisingData.getBytes();
	}


}
