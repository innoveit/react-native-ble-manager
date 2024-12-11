package it.innove;


import static com.facebook.react.bridge.UiThreadUtil.runOnUiThread;

import android.Manifest;
import android.annotation.SuppressLint;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanFilter;
import android.bluetooth.le.ScanRecord;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanSettings;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.ParcelUuid;
import android.util.Log;

import androidx.core.app.ActivityCompat;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

@SuppressLint("MissingPermission")
public class DefaultScanManager extends ScanManager {

    private boolean isScanning = false;

    public DefaultScanManager(ReactApplicationContext reactContext, BleManager bleManager) {
        super(reactContext, bleManager);
    }


    @Override
    public void stopScan(Callback callback) {
        // update scanSessionId to prevent stopping next scan by running timeout thread
        scanSessionId.incrementAndGet();

        final BluetoothLeScanner scanner = getBluetoothAdapter().getBluetoothLeScanner();
        if (scanner != null)
            scanner.stopScan(mScanCallback);
        isScanning = false;
        callback.invoke();
    }

    @Override
    public void scan(ReadableArray serviceUUIDs, final int scanSeconds, ReadableMap options, Callback callback) {
        ScanSettings.Builder scanSettingsBuilder = new ScanSettings.Builder();
        List<ScanFilter> filters = new ArrayList<>();

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && options.hasKey("legacy")) {
            scanSettingsBuilder.setLegacy(options.getBoolean("legacy"));
        }

        if (options.hasKey("scanMode")) {
            scanSettingsBuilder.setScanMode(options.getInt("scanMode"));
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (options.hasKey("numberOfMatches")) {
                scanSettingsBuilder.setNumOfMatches(options.getInt("numberOfMatches"));
            }
            if (options.hasKey("matchMode")) {
                scanSettingsBuilder.setMatchMode(options.getInt("matchMode"));
            }
            if (options.hasKey("callbackType")) {
                scanSettingsBuilder.setCallbackType(options.getInt("callbackType"));
            }
        }

        if (options.hasKey("reportDelay")) {
            scanSettingsBuilder.setReportDelay(options.getInt("reportDelay"));
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && options.hasKey("phy")) {
            int phy = options.getInt("phy");
            if (phy == BluetoothDevice.PHY_LE_CODED && getBluetoothAdapter().isLeCodedPhySupported()) {
                scanSettingsBuilder.setPhy(BluetoothDevice.PHY_LE_CODED);
            }
            if (phy == BluetoothDevice.PHY_LE_2M && getBluetoothAdapter().isLe2MPhySupported()) {
                scanSettingsBuilder.setPhy(BluetoothDevice.PHY_LE_2M);
            }
        }

        if (serviceUUIDs.size() > 0) {
            for (int i = 0; i < serviceUUIDs.size(); i++) {
                ScanFilter filter = new ScanFilter.Builder().setServiceUuid(new ParcelUuid(UUIDHelper.uuidFromString(serviceUUIDs.getString(i)))).build();
                filters.add(filter);
                Log.d(BleManager.LOG_TAG, "Filter service: " + serviceUUIDs.getString(i));
            }
        }


        if (options.hasKey("exactAdvertisingName")) {
            ArrayList<Object> expectedNames = options.getArray("exactAdvertisingName").toArrayList();
            Log.d(BleManager.LOG_TAG, "Filter on advertising names:" + expectedNames);
            for (Object name : expectedNames) {
                ScanFilter filter = new ScanFilter.Builder().setDeviceName(name.toString()).build();
                filters.add(filter);
            }
        }

        if (options.hasKey("manufacturerData")) {
            ReadableMap manufacturerDataMap = options.getMap("manufacturerData");
            if (manufacturerDataMap != null && manufacturerDataMap.hasKey("manufacturerId")) {
                int manufacturerId = manufacturerDataMap.getInt("manufacturerId");
                ReadableArray manufacturerData = manufacturerDataMap.getArray("manufacturerData");
                ReadableArray manufacturerDataMask = manufacturerDataMap.getArray("manufacturerDataMask");
                byte[] manufacturerDataBytes = new byte[0];
                byte[] manufacturerDataMaskBytes = new byte[0];
                if (manufacturerData != null) {
                    manufacturerDataBytes = new byte[manufacturerData.size()];
                    for (int i = 0; i < manufacturerData.size(); i++) {
                        manufacturerDataBytes[i] = Integer.valueOf(manufacturerData.getInt(i)).byteValue();
                    }
                }
                if (manufacturerDataMask != null) {
                    manufacturerDataMaskBytes = new byte[manufacturerDataMask.size()];
                    for (int i = 0; i < manufacturerDataMask.size(); i++) {
                        manufacturerDataMaskBytes[i] = Integer.valueOf(manufacturerDataMask.getInt(i)).byteValue();
                    }
                }
                if (manufacturerDataBytes.length != manufacturerDataMaskBytes.length) {
                    callback.invoke("manufacturerData and manufacturerDataMask must have the same length");
                    return;
                }
                Log.d(
                        BleManager.LOG_TAG,
                        String.format(
                                "Filter on manufacturerId: %d; manufacturerData: %s; manufacturerDataMask: %s",
                                manufacturerId,
                                Arrays.toString(manufacturerDataBytes),
                                Arrays.toString(manufacturerDataMaskBytes)
                        )
                );
                ScanFilter filter = new ScanFilter.Builder()
                        .setManufacturerData(
                                manufacturerId,
                                manufacturerDataBytes,
                                manufacturerDataMaskBytes
                        ).build();
                filters.add(filter);
            }
        }

        getBluetoothAdapter().getBluetoothLeScanner().startScan(filters, scanSettingsBuilder.build(), mScanCallback);
        isScanning = true;

        if (scanSeconds > 0) {
            Thread thread = new Thread() {
                private final int currentScanSession = scanSessionId.incrementAndGet();

                @Override
                public void run() {

                    try {
                        Thread.sleep(scanSeconds * 1000);
                    } catch (InterruptedException ignored) {
                    }

                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            BluetoothAdapter btAdapter = getBluetoothAdapter();

                            // check current scan session was not stopped
                            if (scanSessionId.intValue() == currentScanSession) {
                                if (btAdapter.getState() == BluetoothAdapter.STATE_ON) {
                                    btAdapter.getBluetoothLeScanner().stopScan(mScanCallback);
                                    isScanning = false;
                                }

                                WritableMap map = Arguments.createMap();
                                map.putInt("status", 10);
                                bleManager.emitOnStopScan(map);
                            }
                        }
                    });

                }

            };
            thread.start();
        }
        callback.invoke();
    }

    private void onDiscoveredPeripheral(final ScanResult result) {
        String info;
        ScanRecord record = result.getScanRecord();

        if (record != null) {
            info = record.getDeviceName();
        } else if (ActivityCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED) {
            info = result.getDevice().getName();
        } else {
            info = result.toString();
        }

        Log.i(BleManager.LOG_TAG, "DiscoverPeripheral: " + info);

        DefaultPeripheral peripheral = (DefaultPeripheral) bleManager.getPeripheral(result.getDevice());
        if (peripheral == null) {
            peripheral = new DefaultPeripheral(bleManager, result);
        } else {
            peripheral.updateData(result);
            peripheral.updateRssi(result.getRssi());
        }
        bleManager.savePeripheral(peripheral);

        WritableMap map = peripheral.asWritableMap();
        bleManager.emitOnDiscoverPeripheral(map);
    }

    private final ScanCallback mScanCallback = new ScanCallback() {
        @Override
        public void onScanResult(final int callbackType, final ScanResult result) {
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    onDiscoveredPeripheral(result);
                }
            });
        }

        @Override
        public void onBatchScanResults(final List<ScanResult> results) {
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    if (results.isEmpty()) {
                        return;
                    }

                    for (ScanResult result : results) {
                        onDiscoveredPeripheral(result);
                    }
                }
            });
        }

        @Override
        public void onScanFailed(final int errorCode) {
            isScanning = false;
            WritableMap map = Arguments.createMap();
            map.putInt("status", errorCode);
            bleManager.emitOnStopScan(map);
        }
    };

    @Override
    public boolean isScanning() {
        return isScanning;
    }

    @Override
    public void setScanning(boolean scanning) {
        isScanning = scanning;
    }
}
