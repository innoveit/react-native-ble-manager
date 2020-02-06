package it.innove;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothManager;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.os.IBinder;
import android.os.ResultReceiver;
import android.preference.PreferenceManager;
import android.telecom.Call;
import android.util.Log;

import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Random;
import java.util.TimeZone;
import java.util.UUID;

import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;
import androidx.core.app.NotificationCompat;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;

public class PeripheralService extends Service {
    public Map<String, Peripheral> peripherals = new LinkedHashMap<>();
    private BluetoothAdapter bluetoothAdapter;
    public ResultReceiver broadcastReciever;

    private static final String LOCK_STATUS_CHARACTERISTIC = "00001524-e513-11e5-9260-0002a5d5c51b";
    private String lastUUID;
    private String lastWrittenMessage;
    public static final MediaType JSON = MediaType.get("application/json; charset=utf-8");

    public PeripheralService() {
        super();
    }

    private static final String getConfirmTemplockURL(String networkUrl, String lockuid) {
        return networkUrl + "/mobile/v2/member/smartlocks/" + lockuid + "/confirm-temp-lock";
    }

    private static final String getLockReturnURL(String networkUrl, String lockuid) {
        return networkUrl + "/mobile/v2/member/smartlocks/" + lockuid + "/event/return";
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        Log.d("ReactNativeBleManager", "bind attempt");
        return null;
    }

    @RequiresApi(api = Build.VERSION_CODES.O)
    @Override
    public void onCreate() {
        super.onCreate();
        String CHANNEL_ID = "my_channel_01";
        NotificationChannel channel = new NotificationChannel(CHANNEL_ID,
                "Channel human readable title",
                NotificationManager.IMPORTANCE_DEFAULT);

        ((NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE)).createNotificationChannel(channel);

        Notification notification = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Interacting with smartlock")
                .setContentText("").build();

        startForeground(1, notification);
    }

    private BluetoothAdapter getBluetoothAdapter() {
        if (bluetoothAdapter == null) {
            BluetoothManager manager = (BluetoothManager) this.getSystemService(Context.BLUETOOTH_SERVICE);
            bluetoothAdapter = manager.getAdapter();
        }
        return bluetoothAdapter;
    }

    public void stopService() {

        //stop foreground effectively (remove icon notification on status bar)
        stopForeground(true);
        stopSelf();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        final Peripheral peripheral = retrieveOrCreatePeripheral(intent.getStringExtra("UUID"));
        final String action = intent.getStringExtra("ACTION");
        final ResultReceiver reciever = intent.getParcelableExtra("resultReciever");
        this.broadcastReciever = intent.getParcelableExtra("eventReciever");
        this.lastUUID = intent.getStringExtra("UUID");

        Log.d("ReactNativeBleManager", "Service started");
        Log.d("ReactNativeBleManager", action);


        if(action.equals("CONNECT")) {
            Log.d("ReactNativeBleManager", "Service connect");
            peripheral.connect(new Callback() {
                @Override
                public void invoke(Object... args) {
                    Log.d("ReactNativeBleManager", args.toString());
                    Log.d("ReactNativeBleManager", "Callback Called");
                    Bundle bundle = new Bundle();
                    bundle.putString("ARGS", new Gson().toJson(args));
                    reciever.send(0, bundle);
                }
            }, this);

        }

        if(action.equals("DISCONNECT")) {
            peripheral.disconnect();
            Bundle bundle = new Bundle();
            reciever.send(0, bundle);
        }

        if(action.equals("STARTNOTIFICATION")) {
            UUID serviceUUID = UUIDHelper.uuidFromString(intent.getStringExtra("SERVICEUUID"));
            UUID characteristicUUID = UUIDHelper.uuidFromString(intent.getStringExtra("CHARACTERISTICUUID"));
            peripheral.registerNotify(serviceUUID, characteristicUUID, new Callback() {
                @Override
                public void invoke(Object... args) {
                    Log.d("ReactNativeBleManager", args.toString());
                    Log.d("ReactNativeBleManager", "Callback Called");
                    Bundle bundle = new Bundle();
                    bundle.putString("ARGS", new Gson().toJson(args));
                    reciever.send(0, bundle);
                }
            });
        }

        if(action.equals("STOPNOTIFICATION")) {
            UUID serviceUUID = UUIDHelper.uuidFromString(intent.getStringExtra("SERVICEUUID"));
            UUID characteristicUUID = UUIDHelper.uuidFromString(intent.getStringExtra("CHARACTERISTICUUID"));
            peripheral.removeNotify(serviceUUID, characteristicUUID, new Callback() {
                @Override
                public void invoke(Object... args) {
                    Log.d("ReactNativeBleManager", args.toString());
                    Log.d("ReactNativeBleManager", "Callback Called");
                    Bundle bundle = new Bundle();
                    bundle.putString("ARGS", new Gson().toJson(args));
                    reciever.send(0, bundle);
                }
            });
        }

        if(action.equals("WRITE")) {
            UUID serviceUUID = UUIDHelper.uuidFromString(intent.getStringExtra("SERVICEUUID"));
            UUID characteristicUUID = UUIDHelper.uuidFromString(intent.getStringExtra("CHARACTERISTICUUID"));
            final String strMessage = intent.getStringExtra("MESSAGE");
            peripheral.write(serviceUUID, characteristicUUID, intent.getByteArrayExtra("DECODED"), intent.getIntExtra("MAXBYTESIZE", 20), null, new Callback() {
                @Override
                public void invoke(Object... args) {
                    Log.d("ReactNativeBleManager", args.toString());
                    Log.d("ReactNativeBleManager", "Callback Called");
                    Bundle bundle = new Bundle();
                    bundle.putString("ARGS", new Gson().toJson(args));
                    lastWrittenMessage = strMessage;
                    reciever.send(0, bundle);
                }
            }, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT);
        }

        if(action.equals("WRITEWITHOUTRESPONSE")) {
            UUID serviceUUID = UUIDHelper.uuidFromString(intent.getStringExtra("SERVICEUUID"));
            UUID characteristicUUID = UUIDHelper.uuidFromString(intent.getStringExtra("CHARACTERISTICUUID"));
            peripheral.write(serviceUUID, characteristicUUID, intent.getByteArrayExtra("DECODED"), intent.getIntExtra("MAXBYTESIZE", 20), null, new Callback() {
                @Override
                public void invoke(Object... args) {
                    Log.d("ReactNativeBleManager", args.toString());
                    Log.d("ReactNativeBleManager", "Callback Called");
                    Bundle bundle = new Bundle();
                    bundle.putString("ARGS", new Gson().toJson(args));
                    reciever.send(0, bundle);
                }
            }, BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE);
        }

        if(action.equals("READ")) {
            UUID serviceUUID = UUIDHelper.uuidFromString(intent.getStringExtra("SERVICEUUID"));
            UUID characteristicUUID = UUIDHelper.uuidFromString(intent.getStringExtra("CHARACTERISTICUUID"));
            peripheral.read(serviceUUID, characteristicUUID, new Callback() {
                @Override
                public void invoke(Object... args) {
                    Log.d("ReactNativeBleManager", args.toString());
                    Log.d("ReactNativeBleManager", "Callback Called");
                    Bundle bundle = new Bundle();

                    if(args.length > 1 && args[1] != null) {
                        WritableArray map = (WritableArray) args[1];
                        ArrayList<String> nargs = new ArrayList<String>();
                        nargs.add(args[0] != null ? (String) args[0] : null);
                        bundle.putString("ARGS", new Gson().toJson(nargs));
                        bundle.putString("MAP", new JSONArray(map.toArrayList()).toString());
                    } else {
                        bundle.putString("ARGS", new Gson().toJson(args));
                    }
                    reciever.send(0, bundle);
                }
            });
        }

        if(action.equals("RETRIEVESERVICES")) {
            peripheral.retrieveServices(new Callback() {
                @Override
                public void invoke(Object... args) {
                    Log.d("ReactNativeBleManager", args.toString());
                    Log.d("ReactNativeBleManager", "Callback Called");
                    Bundle bundle = new Bundle();
                    bundle.putString("ARGS", new Gson().toJson(args[0]));
                    if(args.length > 1 && args[1] != null) {
                        WritableMap map = (WritableMap) args[1];
                        ArrayList<String> nargs = new ArrayList<String>();
                        nargs.add(args[0] != null ? (String) args[0] : null);
                        bundle.putString("ARGS", new Gson().toJson(nargs));
                        bundle.putString("MAP", new JSONObject(map.toHashMap()).toString());
                    } else {
                        bundle.putString("ARGS", new Gson().toJson(args));
                    }
                    reciever.send(0, bundle);
                }
            });
        }

        if(action.equals("REFRESHCACHE")) {
            peripheral.refreshCache(new Callback() {
                @Override
                public void invoke(Object... args) {
                    Log.d("ReactNativeBleManager", args.toString());
                    Log.d("ReactNativeBleManager", "Callback Called");
                    Bundle bundle = new Bundle();
                    bundle.putString("ARGS", new Gson().toJson(args));
                    reciever.send(0, bundle);
                }
            });
        }

        if(action.equals("READRSSI")) {
            peripheral.readRSSI(new Callback() {
                @Override
                public void invoke(Object... args) {
                    Log.d("ReactNativeBleManager", args.toString());
                    Log.d("ReactNativeBleManager", "Callback Called");
                    Bundle bundle = new Bundle();
                    bundle.putString("ARGS", new Gson().toJson(args));
                    reciever.send(0, bundle);
                }
            });
        }

        if(action.equals("REQUESTCONNECTIONPRIORITY")) {
            int connectionPriority = intent.getIntExtra("CONNECTIONPRIORITY", 0);
            peripheral.requestConnectionPriority(connectionPriority, new Callback() {
                @Override
                public void invoke(Object... args) {
                    Log.d("ReactNativeBleManager", args.toString());
                    Log.d("ReactNativeBleManager", "Callback Called");
                    Bundle bundle = new Bundle();
                    bundle.putString("ARGS", new Gson().toJson(args));
                    reciever.send(0, bundle);
                }
            });
        }

        if(action.equals("REQUESTMTU")) {
            int mtu = intent.getIntExtra("MTU", 0);
            peripheral.requestMTU(mtu, new Callback() {
                @Override
                public void invoke(Object... args) {
                    Log.d("ReactNativeBleManager", args.toString());
                    Log.d("ReactNativeBleManager", "Callback Called");
                    Bundle bundle = new Bundle();
                    bundle.putString("ARGS", new Gson().toJson(args));
                    reciever.send(0, bundle);
                }
            });
        }

        return 0;
    }

    private String getRandomHexString(int numchars){
        Random r = new Random();
        StringBuffer sb = new StringBuffer();
        while(sb.length() < numchars){
            sb.append(Integer.toHexString(r.nextInt()));
        }

        return sb.toString().substring(0, numchars);
    }

    public void backupEventHandler(String eventName, JSONObject params) {
        if(eventName != "BleManagerDidUpdateValueForCharacteristic") {
            retrieveOrCreatePeripheral(lastUUID).disconnect();
            return;
        }
        try {
            Log.d(BleManager.LOG_TAG, eventName + " " + params.toString() );
            JSONObject serviceRecoveryData = new JSONObject(PreferenceManager.getDefaultSharedPreferences(this).getString("serviceRecoveryData", ""));
            String lastSmartlockUsage = serviceRecoveryData.getString("lastSmartlockUsage");
            String lockuid = serviceRecoveryData.getString("lockuid");
            Boolean lastUsageIsLocking = lastSmartlockUsage.equals("TEMPORARY_LOCK")  || lastSmartlockUsage.equals("RETURN");
            JSONArray value = params.getJSONArray("value");
            Boolean notificationIsForLocked =  value != null && value.length() > 0 && ((value.getInt(0) & 0x01) == 0x01);
            OkHttpClient client = new OkHttpClient();

            if(lastUsageIsLocking && params.getString("characteristic").equals(LOCK_STATUS_CHARACTERISTIC)  && notificationIsForLocked) {
                    if(lastSmartlockUsage.equals("TEMPORARY_LOCK") ) {
                        JSONObject requestBody = new JSONObject();
                        requestBody.put("otpKey", lastWrittenMessage);
                        String res = post(getConfirmTemplockURL(serviceRecoveryData.getString("url"), lockuid), requestBody.toString(), client, serviceRecoveryData.getString("apiKey"), serviceRecoveryData.getString("token"));
                        Log.d(BleManager.LOG_TAG, "tempLockConfirmed " + res);
                    } else if(lastSmartlockUsage.equals("RETURN")){
                        TimeZone tz = TimeZone.getTimeZone("UTC");
                        DateFormat df = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm'Z'");
                        df.setTimeZone(tz);
                        String timestamp = df.format(new Date());
                        JSONObject requestBody = new JSONObject();
                        requestBody.put("otpKey", lastWrittenMessage);
                        requestBody.put("stationId", serviceRecoveryData.getString("stationId"));
                        requestBody.put("sequence", getRandomHexString(10));
                        requestBody.put("timestamp", timestamp);
                        String res = post(getLockReturnURL(serviceRecoveryData.getString("url"), lockuid), requestBody.toString(), client, serviceRecoveryData.getString("apiKey"), serviceRecoveryData.getString("token"));
                        Log.d(BleManager.LOG_TAG, "returnDone " + res);
                    }
                    retrieveOrCreatePeripheral(lastUUID).disconnect();
            } else {
                retrieveOrCreatePeripheral(lastUUID).disconnect();
            }
        } catch (JSONException | IOException e) {
            retrieveOrCreatePeripheral(lastUUID).disconnect();
            e.printStackTrace();
        }
    }

    private String post(String url, String json, OkHttpClient client, String apiKey, String token) throws IOException {
        RequestBody body = RequestBody.create(JSON, json);
        Request request = new Request.Builder()
                .url(url)
                .addHeader("X-API-KEY", apiKey)
                .addHeader("X-AUTH-TOKEN", token)
                .post(body)
                .build();
        try (Response response = client.newCall(request).execute()) {
            return response.body().string();
        }
    }

    private Peripheral retrieveOrCreatePeripheral(String peripheralUUID) {
        BluetoothAdapter adapter = getBluetoothAdapter();
        Peripheral peripheral = peripherals.get(peripheralUUID);
        if (peripheral == null) {
            if (peripheralUUID != null) {
                peripheralUUID = peripheralUUID.toUpperCase();
            }
            if (BluetoothAdapter.checkBluetoothAddress(peripheralUUID)) {
                BluetoothDevice device = adapter.getRemoteDevice(peripheralUUID);
                peripheral = new Peripheral(device, this, this);
                peripherals.put(peripheralUUID, peripheral);
            }
        }
        return peripheral;
    }
}
