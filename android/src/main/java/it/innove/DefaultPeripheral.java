package it.innove;

import static it.innove.BleManager.LOG_TAG;

import android.bluetooth.BluetoothDevice;
import android.bluetooth.le.ScanRecord;
import android.bluetooth.le.ScanResult;
import android.os.Build;
import android.os.ParcelUuid;
import android.annotation.SuppressLint;
import android.util.SparseArray;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;

import java.io.ByteArrayOutputStream;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;

@SuppressLint("MissingPermission")
public class DefaultPeripheral extends Peripheral {

    private static final int MANUFACTURER_SPECIFIC_DATA = 0xFF;

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
                byte[] manufacturerRawBytes = new byte[0];
                Map<Integer, byte[]> manufacturerPayloads = advertisingDataBytes != null
                        ? parseManufacturerData(advertisingDataBytes)
                        : getManufacturerData(advertisingData);
                for (Map.Entry<Integer, byte[]> entry : manufacturerPayloads.entrySet()) {
                    int companyId = entry.getKey();
                    byte[] data = entry.getValue();
                    manufacturerData.putMap(String.format("%04x", companyId), byteArrayToWritableMap(data));

                    if (manufacturerRawBytes.length == 0) {
                        // Same layout as iOS: 2-byte little-endian company ID followed by the data
                        manufacturerRawBytes = new byte[2 + data.length];
                        manufacturerRawBytes[0] = (byte) (companyId & 0xFF);
                        manufacturerRawBytes[1] = (byte) ((companyId >> 8) & 0xFF);
                        System.arraycopy(data, 0, manufacturerRawBytes, 2, data.length);
                    }
                }
                advertising.putMap("manufacturerData", manufacturerData);
                advertising.putMap("manufacturerRawData", byteArrayToWritableMap(manufacturerRawBytes));

                advertising.putInt("txPowerLevel", advertisingData.getTxPowerLevel());
            }

            map.putMap("advertising", advertising);
        } catch (Exception e) { // this shouldn't happen
            BleLog.e(LOG_TAG, "asWritableMap error", e);
        }

        return map;
    }

    /**
     * Parses the manufacturer specific data (AD type 0xFF) from the raw advertising bytes, which
     * hold the advertising packet followed by the scan response. Data with the same company ID is
     * concatenated in the order it appears, like iOS does.
     */
    private static Map<Integer, byte[]> parseManufacturerData(byte[] scanRecord) {
        Map<Integer, ByteArrayOutputStream> merged = new LinkedHashMap<>();
        int index = 0;
        while (index < scanRecord.length) {
            int length = scanRecord[index] & 0xFF;
            // length 0 marks the end of the significant part, and a record must fit in the array
            if (length == 0 || index + length >= scanRecord.length) {
                break;
            }
            int type = scanRecord[index + 1] & 0xFF;
            // length covers the type byte, then at least the 2-byte company ID
            if (type == MANUFACTURER_SPECIFIC_DATA && length >= 3) {
                int companyId = (scanRecord[index + 2] & 0xFF) | ((scanRecord[index + 3] & 0xFF) << 8);
                ByteArrayOutputStream data = merged.get(companyId);
                if (data == null) {
                    data = new ByteArrayOutputStream();
                    merged.put(companyId, data);
                }
                data.write(scanRecord, index + 4, length - 3);
            }
            index += length + 1;
        }

        Map<Integer, byte[]> result = new LinkedHashMap<>();
        for (Map.Entry<Integer, ByteArrayOutputStream> entry : merged.entrySet()) {
            result.put(entry.getKey(), entry.getValue().toByteArray());
        }
        return result;
    }

    private static Map<Integer, byte[]> getManufacturerData(ScanRecord scanRecord) {
        Map<Integer, byte[]> result = new LinkedHashMap<>();
        SparseArray<byte[]> data = scanRecord.getManufacturerSpecificData();
        if (data != null) {
            for (int i = 0; i < data.size(); i++) {
                if (data.valueAt(i) != null) {
                    result.put(data.keyAt(i), data.valueAt(i));
                }
            }
        }
        return result;
    }

    public void updateData(ScanResult result) {
        scanResult = result;
        advertisingData = result.getScanRecord();
        advertisingDataBytes = advertisingData != null ? advertisingData.getBytes() : null;
    }
}
