package it.innove;

import static android.app.Activity.RESULT_OK;

import static com.facebook.react.bridge.UiThreadUtil.runOnUiThread;

import android.app.Activity;
import android.bluetooth.le.ScanFilter;
import android.bluetooth.le.ScanResult;
import android.companion.AssociationRequest;
import android.companion.BluetoothLeDeviceFilter;
import android.companion.CompanionDeviceManager;
import android.content.Intent;
import android.content.IntentSender;
import android.os.Build;
import android.os.ParcelUuid;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;

import com.facebook.react.bridge.ActivityEventListener;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.BaseActivityEventListener;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;

@RequiresApi(api = Build.VERSION_CODES.O)
public class CompanionScanner {

    private final BleManager bleManager;
    private final ReactContext reactContext;
    public static final String LOG_TAG = "CompationScanManager";
    private static final int SELECT_DEVICE_REQUEST_CODE = 540;

    private final ActivityEventListener mActivityEventListener = new BaseActivityEventListener() {
        @Override
        public void onActivityResult(Activity activity, int requestCode, int resultCode, Intent intent) {
            Log.d(LOG_TAG, "onActivityResult");
            if (requestCode != SELECT_DEVICE_REQUEST_CODE) {
                super.onActivityResult(activity, requestCode, resultCode, intent);
                return;
            }
            if (resultCode == RESULT_OK) {
                // Have device?
                Log.d(LOG_TAG, "Ok activity result");

                ScanResult result = intent.getParcelableExtra(CompanionDeviceManager.EXTRA_DEVICE);
                Peripheral peripheral = bleManager.savePeripheral(result.getDevice());

                bleManager.sendEvent("BleManagerCompanionPeripheral", peripheral.asWritableMap());
            } else {
                // No device, user cancelled?
                Log.d(LOG_TAG, "Non-ok activity result");
                bleManager.sendEvent("BleManagerCompanionPeripheral", null);
            }
        }
    };

    public CompanionScanner(ReactApplicationContext reactContext, BleManager bleManager) {
        this.reactContext = reactContext;
        this.bleManager = bleManager;
        reactContext.addActivityEventListener(mActivityEventListener);
    }

    public void scan(ReadableArray serviceUUIDs, ReadableMap options, Callback callback) {
        Log.d(LOG_TAG, "companion scan start");

        AssociationRequest.Builder builder = new AssociationRequest.Builder()
                .setSingleDevice(options.hasKey("single") && options.getBoolean("single")) ;

        for (int i = 0; i < serviceUUIDs.size(); i++) {
            final ParcelUuid uuid = new ParcelUuid(UUIDHelper.uuidFromString(serviceUUIDs.getString(i)));
            Log.d(LOG_TAG, "Filter service: " + uuid);

            builder = builder
                    // Add LE filter.
                    .addDeviceFilter(new BluetoothLeDeviceFilter.Builder()
                            .setScanFilter(new ScanFilter.Builder().setServiceUuid(uuid).build())
                            .build());
        }

        AssociationRequest pairingRequest = builder.build();

        bleManager.getCompanionDeviceManager().associate(pairingRequest, new CompanionDeviceManager.Callback() {
            @Override
            public void onFailure(@Nullable CharSequence charSequence) {
                Log.d(LOG_TAG, "companion failure: " + charSequence);
                WritableMap map = Arguments.createMap();
                map.putString("error", charSequence.toString());
                bleManager.sendEvent("BleManagerCompanionFailure", map);
            }

            @Override
            public void onDeviceFound(@NonNull IntentSender intentSender) {
                Log.d(LOG_TAG, "companion device found");
                try {
                    reactContext.getCurrentActivity().startIntentSenderForResult(
                            intentSender, SELECT_DEVICE_REQUEST_CODE, null, 0, 0, 0
                    );
                } catch (IntentSender.SendIntentException e) {
                    Log.e(LOG_TAG, "Failed to send intent: " + e.toString());
                    String msg = "Failed to send intent: " + e.toString();
                    WritableMap map = Arguments.createMap();
                    map.putString("error", msg);
                    bleManager.sendEvent("BleManagerCompanionFailure", map);
                }
            }
        }, null);

        callback.invoke();
    }
}
