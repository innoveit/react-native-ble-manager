package it.innove;


import static com.facebook.react.bridge.UiThreadUtil.runOnUiThread;

import android.Manifest;
import android.annotation.SuppressLint;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanFilter;
import android.bluetooth.le.ScanRecord;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanSettings;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.ParcelUuid;
import android.util.Log;

import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Objects;

@SuppressLint("MissingPermission")
public class DefaultScanManager extends ScanManager {

    private boolean isScanning = false;
    private PendingIntent scanPendingIntent;
    private BroadcastReceiver scanReceiver;
    private boolean scanReceiverRegistered = false;
    private boolean scanningWithIntent = false;
    private static final String ACTION_SCAN_RESULT = "it.innove.BleManager.ACTION_SCAN_RESULT";
    private static final String EXTRA_LIST_SCAN_RESULT = "android.bluetooth.le.extra.LIST_SCAN_RESULT";
    private static final String EXTRA_SCAN_RESULT = "android.bluetooth.le.extra.SCAN_RESULT";
    private static final String EXTRA_ERROR_CODE = "android.bluetooth.le.extra.ERROR_CODE";

    public DefaultScanManager(ReactApplicationContext reactContext, BleManager bleManager) {
        super(reactContext, bleManager);
    }


    @Override
    public void stopScan(Callback callback) {
        // update scanSessionId to prevent stopping next scan by running timeout thread
        scanSessionId.incrementAndGet();

        stopActiveScan();
        callback.invoke();
    }

    @Override
    public void scan(ReadableMap options, Callback callback) {
        ScanSettings.Builder scanSettingsBuilder = new ScanSettings.Builder();
        List<ScanFilter> filters = new ArrayList<>();

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && options.hasKey("legacy")) {
            scanSettingsBuilder.setLegacy(options.getBoolean("legacy"));
        }

        if (options.hasKey("scanMode")) {
            scanSettingsBuilder.setScanMode(options.getInt("scanMode"));
        }

        if (options.hasKey("numberOfMatches")) {
            scanSettingsBuilder.setNumOfMatches(options.getInt("numberOfMatches"));
        }
        if (options.hasKey("matchMode")) {
            scanSettingsBuilder.setMatchMode(options.getInt("matchMode"));
        }
        if (options.hasKey("callbackType")) {
            scanSettingsBuilder.setCallbackType(options.getInt("callbackType"));
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

        ReadableArray serviceUUIDs = options.getArray("serviceUUIDs");
        if (serviceUUIDs != null && serviceUUIDs.size() > 0) {
            for (int i = 0; i < serviceUUIDs.size(); i++) {
                ScanFilter filter = new ScanFilter.Builder().setServiceUuid(new ParcelUuid(UUIDHelper.uuidFromString(Objects.requireNonNull(serviceUUIDs.getString(i))))).build();
                filters.add(filter);
                Log.d(BleManager.LOG_TAG, "Filter service: " + serviceUUIDs.getString(i));
            }
        }


        if (options.hasKey("exactAdvertisingName")) {
            ReadableArray exactAdvertisingNameArray = options.getArray("exactAdvertisingName");
            if (exactAdvertisingNameArray == null) {
                Log.w(BleManager.LOG_TAG, "exactAdvertisingName key present but array is null");
            }
            if (exactAdvertisingNameArray != null) {
                ArrayList<Object> expectedNames = exactAdvertisingNameArray.toArrayList();
                Log.d(BleManager.LOG_TAG, "Filter on advertising names:" + expectedNames);
                for (Object name : expectedNames) {
                    ScanFilter filter = new ScanFilter.Builder().setDeviceName(name.toString()).build();
                    filters.add(filter);
                }
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

        boolean useScanIntent = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                && options.hasKey("useScanIntent")
                && options.getBoolean("useScanIntent");

        if (useScanIntent && Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            callback.invoke("useScanIntent requires Android O (API 26) or higher");
            return;
        }

        if (isScanning) {
            scanSessionId.incrementAndGet();
            stopActiveScan();
        }

        BluetoothLeScanner scanner = getBluetoothAdapter().getBluetoothLeScanner();
        if (scanner == null) {
            callback.invoke("No BLE scanner available");
            return;
        }

        try {
            if (useScanIntent) {
                Log.i(BleManager.LOG_TAG, "Scan with intent");
                ensureScanReceiver();
                Intent intent = new Intent(ACTION_SCAN_RESULT);
                intent.setPackage(context.getPackageName());
                int flags = PendingIntent.FLAG_UPDATE_CURRENT;
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    flags |= PendingIntent.FLAG_MUTABLE;
                }
                scanPendingIntent = PendingIntent.getBroadcast(context, 0, intent, flags);
                scanner.startScan(filters, scanSettingsBuilder.build(), scanPendingIntent);
                scanningWithIntent = true;
            } else {
                scanner.startScan(filters, scanSettingsBuilder.build(), mScanCallback);
                scanningWithIntent = false;
            }
        } catch (Exception e) {
            if (useScanIntent) {
                if (scanPendingIntent != null) {
                    scanPendingIntent.cancel();
                    scanPendingIntent = null;
                }
                unregisterScanReceiver();
            }
            callback.invoke("Failed to start scan: " + e.getMessage());
            return;
        }

        isScanning = true;

        long scanSeconds = (long) options.getDouble("seconds");
        if (scanSeconds > 0) {
            Thread thread = new Thread() {
                private final int currentScanSession = scanSessionId.incrementAndGet();

                @Override
                public void run() {

                    try {
                        Thread.sleep(scanSeconds * 1000L);
                    } catch (InterruptedException ignored) {
                    }

                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            BluetoothAdapter btAdapter = getBluetoothAdapter();

                            // check current scan session was not stopped
                            if (scanSessionId.intValue() == currentScanSession) {
                                if (btAdapter.getState() == BluetoothAdapter.STATE_ON) {
                                    stopActiveScan();
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

    private void stopActiveScan() {
        BluetoothLeScanner scanner = getBluetoothAdapter() != null ? getBluetoothAdapter().getBluetoothLeScanner() : null;
        if (scanner != null) {
            try {
                if (scanningWithIntent && scanPendingIntent != null) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        scanner.stopScan(scanPendingIntent);
                    }
                } else {
                    scanner.stopScan(mScanCallback);
                }
            } catch (IllegalArgumentException | IllegalStateException ignored) {
                Log.w(BleManager.LOG_TAG, "stopScan ignored error: " + ignored.getMessage());
            }
        }
        if (scanPendingIntent != null) {
            scanPendingIntent.cancel();
            scanPendingIntent = null;
        }
        unregisterScanReceiver();
        scanningWithIntent = false;
        isScanning = false;
    }

    private void ensureScanReceiver() {
        if (scanReceiver == null) {
            scanReceiver = new BroadcastReceiver() {
                @Override
                public void onReceive(Context context, Intent intent) {
                    if (!ACTION_SCAN_RESULT.equals(intent.getAction())) {
                        return;
                    }

                    if (intent.hasExtra(EXTRA_ERROR_CODE)) {
                        final int errorCode = intent.getIntExtra(EXTRA_ERROR_CODE, ScanCallback.SCAN_FAILED_INTERNAL_ERROR);
                        runOnUiThread(new Runnable() {
                            @Override
                            public void run() {
                                stopActiveScan();
                                WritableMap map = Arguments.createMap();
                                map.putInt("status", errorCode);
                                bleManager.emitOnStopScan(map);
                            }
                        });
                        return;
                    }

                    final ArrayList<ScanResult> results = intent.getParcelableArrayListExtra(EXTRA_LIST_SCAN_RESULT);
                    final ScanResult singleResult = intent.getParcelableExtra(EXTRA_SCAN_RESULT);

                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            if (results != null) {
                                for (ScanResult result : results) {
                                    onDiscoveredPeripheral(result);
                                }
                            } else if (singleResult != null) {
                                onDiscoveredPeripheral(singleResult);
                            }
                        }
                    });
                }
            };
        }

        if (!scanReceiverRegistered) {
            IntentFilter intentFilter = new IntentFilter(ACTION_SCAN_RESULT);
            ContextCompat.registerReceiver(context, scanReceiver, intentFilter, ContextCompat.RECEIVER_NOT_EXPORTED);
            scanReceiverRegistered = true;
        }
    }

    private void unregisterScanReceiver() {
        if (scanReceiverRegistered) {
            try {
                context.unregisterReceiver(scanReceiver);
            } catch (IllegalArgumentException ignored) {
            }
            scanReceiverRegistered = false;
        }
    }
}
