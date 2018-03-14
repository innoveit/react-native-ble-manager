package it.innove;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.os.ParcelUuid;
import android.util.Log;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;

import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import static com.facebook.react.bridge.UiThreadUtil.runOnUiThread;

public class LegacyScanManager extends ScanManager {

	private Set<UUID> uuidFilters = new HashSet<>();

	public LegacyScanManager(ReactApplicationContext reactContext, BleManager bleManager) {
		super(reactContext, bleManager);
	}

	@Override
	public void stopScan(Callback callback) {
		// update scanSessionId to prevent stopping next scan by running timeout thread
		scanSessionId.incrementAndGet();

		getBluetoothAdapter().stopLeScan(mLeScanCallback);
		callback.invoke();
	}

	private BluetoothAdapter.LeScanCallback mLeScanCallback =
			new BluetoothAdapter.LeScanCallback() {


				@Override
				public void onLeScan(final BluetoothDevice device, final int rssi,
									 final byte[] scanRecord) {
					runOnUiThread(new Runnable() {
						@Override
						public void run() {
							Log.i(bleManager.LOG_TAG, "DiscoverPeripheral: " + device.getName());
							final ScanResult sr = ScanResult.parseFromBytes(scanRecord);
							List<ParcelUuid> pus = sr.getmServiceUuids();
							boolean isInsole = false;
							if (null != pus) {
								for (int i = 0; i < pus.size(); i++) {
									if (null != pus.get(i)) {
										UUID pusUUID = pus.get(i).getUuid();
										if (uuidFilters.contains(pusUUID)) {
											isInsole = true;
											break;
										}
									}
								}
							}
							if (isInsole) {
								String address = device.getAddress();
								Peripheral peripheral;

								if (!bleManager.peripherals.containsKey(address)) {
									peripheral = new Peripheral(device, rssi, scanRecord, reactContext);
									bleManager.peripherals.put(device.getAddress(), peripheral);
								} else {
									peripheral = bleManager.peripherals.get(address);
									peripheral.updateRssi(rssi);
									peripheral.updateData(scanRecord);
								}

								WritableMap map = peripheral.asWritableMap();
								bleManager.sendEvent("BleManagerDiscoverPeripheral", map);
							}
						}
					});
				}


			};

	@Override
	public void scan(ReadableArray serviceUUIDs, final int scanSeconds, ReadableMap options, Callback callback) {
		uuidFilters = new HashSet<>();
		if (serviceUUIDs.size() > 0) {
			for(int i = 0; i < serviceUUIDs.size(); i++){
				uuidFilters.add(UUID.fromString(serviceUUIDs.getString(i)));
			}
		}
		getBluetoothAdapter().startLeScan(mLeScanCallback);

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
								if (btAdapter.getState() == BluetoothAdapter.STATE_ON) {
									btAdapter.stopLeScan(mLeScanCallback);
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
}
