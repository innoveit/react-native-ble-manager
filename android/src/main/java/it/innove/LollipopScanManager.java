package it.innove;


import android.annotation.TargetApi;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanFilter;
import android.bluetooth.le.ScanRecord;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanSettings;
import android.os.Build;
import android.os.Bundle;
import android.os.ParcelUuid;
import android.util.Log;
import com.facebook.react.bridge.*;
import org.json.JSONException;

import java.util.ArrayList;
import java.util.List;

import static com.facebook.react.bridge.UiThreadUtil.runOnUiThread;

@TargetApi(Build.VERSION_CODES.LOLLIPOP)
public class LollipopScanManager extends ScanManager {

	public LollipopScanManager(ReactApplicationContext reactContext, BleManager bleManager) {
		super(reactContext, bleManager);
	}

	@Override
	public void stopScan(Callback callback) {
		// update scanSessionId to prevent stopping next scan by running timeout thread
		scanSessionId.incrementAndGet();

		getBluetoothAdapter().getBluetoothLeScanner().stopScan(mScanCallback);
		callback.invoke();
	}

    @Override
    public void scan(ReadableArray serviceUUIDs, final int scanSeconds, ReadableMap options,  Callback callback) {
        ScanSettings.Builder scanSettingsBuilder = new ScanSettings.Builder();
        List<ScanFilter> filters = new ArrayList<>();
        
        scanSettingsBuilder.setScanMode(options.getInt("scanMode"));
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            scanSettingsBuilder.setNumOfMatches(options.getInt("numberOfMatches"));
            scanSettingsBuilder.setMatchMode(options.getInt("matchMode"));
        }
        
        if (serviceUUIDs.size() > 0) {
            for(int i = 0; i < serviceUUIDs.size(); i++){
				ScanFilter filter = new ScanFilter.Builder().setServiceUuid(new ParcelUuid(UUIDHelper.uuidFromString(serviceUUIDs.getString(i)))).build();
                filters.add(filter);
                Log.d(bleManager.LOG_TAG, "Filter service: " + serviceUUIDs.getString(i));
            }
        }
        
        getBluetoothAdapter().getBluetoothLeScanner().startScan(filters, scanSettingsBuilder.build(), mScanCallback);
        if (scanSeconds > 0) {
            Thread thread = new Thread() {
                private int currentScanSession = scanSessionId.incrementAndGet();
                
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
                                if(btAdapter.getState() == BluetoothAdapter.STATE_ON) {
                                    btAdapter.getBluetoothLeScanner().stopScan(mScanCallback);
                                }
                                WritableMap map = Arguments.createMap();
                                bleManager.sendEvent("BleManagerStopScan", map);
                            }
                        }
                    });
                    
                }
                
            };
            thread.start();
        }
        callback.invoke();
    }

	private ScanCallback mScanCallback = new ScanCallback() {
		@Override
		public void onScanResult(final int callbackType, final ScanResult result) {

			runOnUiThread(new Runnable() {
				@Override
				public void run() {
					Log.i(bleManager.LOG_TAG, "DiscoverPeripheral: " + result.getDevice().getName());
					String address = result.getDevice().getAddress();
                    Peripheral peripheral = null;

                    ScanRecord scanRecord = result.getScanRecord();

                    if (scanRecord == null) {
                        Log.i(bleManager.LOG_TAG, "Empty ScanRecord, skipping");
                        return;
                    }

					if (!bleManager.peripherals.containsKey(address)) {
						peripheral = new Peripheral(result.getDevice(), result.getRssi(), scanRecord.getBytes(), reactContext);
						bleManager.peripherals.put(address, peripheral);
					} else {
						peripheral = bleManager.peripherals.get(address);
						peripheral.updateRssi(result.getRssi());
						peripheral.updateData(scanRecord.getBytes());
					}

					WritableMap map = peripheral.asWritableMap();
					bleManager.sendEvent("BleManagerDiscoverPeripheral", map);
				}
			});
		}

		@Override
		public void onBatchScanResults(final List<ScanResult> results) {
		}

		@Override
		public void onScanFailed(final int errorCode) {
            WritableMap map = Arguments.createMap();
            bleManager.sendEvent("BleManagerStopScan", map);
		}
	};
}
