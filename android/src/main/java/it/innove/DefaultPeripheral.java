package it.innove;

import static it.innove.BleManager.LOG_TAG;

import android.bluetooth.BluetoothDevice;
import android.bluetooth.le.ScanRecord;
import android.bluetooth.le.ScanResult;
import android.os.Build;
import android.os.ParcelUuid;
import android.annotation.SuppressLint;
import android.util.Log;
import android.util.SparseArray;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;

import java.nio.ByteBuffer;
import java.util.Map;
import java.util.Objects;

@SuppressLint("MissingPermission")
public class DefaultPeripheral extends Peripheral {

    private ScanRecord advertisingData;
    private ScanResult scanResult;

    public DefaultPeripheral(BleManager bleManager, ScanResult result) {
        super(result.getDevice(), result.getRssi(), Objects.requireNonNull(result.getScanRecord()).getBytes(), bleManager);
        this.advertisingData = result.getScanRecord();
        this.scanResult = result;
    }

    public DefaultPeripheral(BluetoothDevice device, BleManager bleManager) {
        super(device, bleManager);
    }

    @Override
    public WritableMap asWritableMap() {
        WritableMap map = super.asWritableMap();
        WritableMap advertising = Arguments.createMap();

        try {
            String name = getSafeDeviceName();
            if (name == null && scanResult != null && scanResult.getScanRecord() != null) {
                name = scanResult.getScanRecord().getDeviceName();
            }
            map.putString("name", name);
            map.putString("id", device.getAddress()); // mac address
            map.putInt("rssi", advertisingRSSI);

            advertising.putMap("rawData", byteArrayToWritableMap(advertisingDataBytes));

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // We can check if peripheral is connectable using the scanresult
                if (this.scanResult != null) {
                    advertising.putBoolean("isConnectable", scanResult.isConnectable());
                }
            } else {
                // We can't check if peripheral is connectable
                advertising.putBoolean("isConnectable", true);
            }

            if (advertisingData != null) {
                String deviceName = advertisingData.getDeviceName();
                if (deviceName != null)
                    advertising.putString("localName", deviceName.replace("\0", ""));

                WritableArray serviceUuids = Arguments.createArray();
                if (advertisingData.getServiceUuids() != null && !advertisingData.getServiceUuids().isEmpty()) {
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

                WritableMap manufacturerData = Arguments.createMap();
                SparseArray<byte[]> manufacturerRawData = advertisingData.getManufacturerSpecificData();
                byte[] manufacturerRawBytes = new byte[0];
                if (manufacturerRawData != null && manufacturerRawData.size() > 0) {
                    int key = manufacturerRawData.keyAt(0);
                    byte[] data = manufacturerRawData.valueAt(0);
                    manufacturerData.putMap(String.format("%04x", key), byteArrayToWritableMap(data));

                    ByteBuffer keyBuffer = ByteBuffer.allocate(Integer.SIZE / Byte.SIZE);
                    keyBuffer.putInt(key);
                    byte[] keyBytes = keyBuffer.array();
                    manufacturerRawBytes = new byte[keyBytes.length + data.length];
                    System.arraycopy(keyBytes, 0, manufacturerRawBytes, 0, keyBytes.length);
                    System.arraycopy(data, 0, manufacturerRawBytes, keyBytes.length, data.length);
                }
                advertising.putMap("manufacturerData", manufacturerData);
                advertising.putMap("manufacturerRawData", byteArrayToWritableMap(manufacturerRawBytes));

                advertising.putInt("txPowerLevel", advertisingData.getTxPowerLevel());
            }

            map.putMap("advertising", advertising);
        } catch (Exception e) { // this shouldn't happen
            Log.e(LOG_TAG, "asWritableMap error", e);
        }

        return map;
    }

    public void updateData(ScanResult result) {
        scanResult = result;
        advertisingData = result.getScanRecord();
        advertisingDataBytes = advertisingData != null ? advertisingData.getBytes() : null;
    }
}
