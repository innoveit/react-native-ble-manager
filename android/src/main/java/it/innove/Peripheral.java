package it.innove;

import static com.facebook.react.common.ReactConstants.TAG;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothProfile;
import android.content.Context;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Base64;
import android.util.Log;

import androidx.annotation.Nullable;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.RCTNativeAppEventEmitter;

import org.json.JSONException;

import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Queue;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedQueue;

/**
 * Peripheral wraps the BluetoothDevice and provides methods to convert to JSON.
 */
@SuppressLint("MissingPermission")
public class Peripheral extends BluetoothGattCallback {

    private static final String CHARACTERISTIC_NOTIFICATION_CONFIG = "00002902-0000-1000-8000-00805f9b34fb";
    public static final int GATT_INSUFFICIENT_AUTHENTICATION = 5;
    public static final int GATT_AUTH_FAIL = 137;

    protected final BluetoothDevice device;
    private final Map<String, NotifyBufferContainer> bufferedCharacteristics;
    protected volatile byte[] advertisingDataBytes = new byte[0];
    protected volatile int advertisingRSSI;
    private volatile boolean connected = false;
    private volatile boolean connecting = false;
    private ReactContext reactContext;

    private BluetoothGatt gatt;

    private LinkedList<Callback> connectCallbacks = new LinkedList<>();
    private LinkedList<Callback> retrieveServicesCallbacks = new LinkedList<>();
    private LinkedList<Callback> readCallbacks = new LinkedList<>();
    private LinkedList<Callback> readDescriptorCallbacks = new LinkedList<>();
    private LinkedList<Callback> readRSSICallbacks = new LinkedList<>();
    private LinkedList<Callback> writeCallbacks = new LinkedList<>();
    private LinkedList<Callback> registerNotifyCallbacks = new LinkedList<>();
    private LinkedList<Callback> requestMTUCallbacks = new LinkedList<>();

    private final Queue<Runnable> commandQueue = new ConcurrentLinkedQueue<>();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private Runnable discoverServicesRunnable;
    private boolean commandQueueBusy = false;

    private List<byte[]> writeQueue = new ArrayList<>();

    public Peripheral(BluetoothDevice device, int advertisingRSSI, byte[] scanRecord, ReactContext reactContext) {
        this.device = device;
        this.bufferedCharacteristics = new ConcurrentHashMap<String, NotifyBufferContainer>();
        this.advertisingRSSI = advertisingRSSI;
        this.advertisingDataBytes = scanRecord;
        this.reactContext = reactContext;
    }

    public Peripheral(BluetoothDevice device, ReactContext reactContext) {
        this.device = device;
        this.bufferedCharacteristics = new ConcurrentHashMap<String, NotifyBufferContainer>();
        this.reactContext = reactContext;
    }

    private void sendEvent(String eventName, @Nullable WritableMap params) {
        synchronized (reactContext) {
            reactContext.getJSModule(RCTNativeAppEventEmitter.class).emit(eventName, params);
        }
    }

    private void sendConnectionEvent(BluetoothDevice device, String eventName, int status) {
        WritableMap map = Arguments.createMap();
        map.putString("peripheral", device.getAddress());
        if (status != -1) {
            map.putInt("status", status);
        }
        sendEvent(eventName, map);
        Log.d(BleManager.LOG_TAG, "Peripheral event (" + eventName + "):" + device.getAddress());
    }

    public void connect(final Callback callback, Activity activity, ReadableMap options) {
        mainHandler.post(() -> {
            if (!connected) {
                BluetoothDevice device = getDevice();
                this.connectCallbacks.addLast(callback);
                this.connecting = true;
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    Log.d(BleManager.LOG_TAG, " Is Or Greater than M $mBluetoothDevice");
                    boolean autoconnect = false;
                    if (options.hasKey("autoconnect")) {
                        autoconnect = options.getBoolean("autoconnect");
                    }
                    if (!autoconnect && options.hasKey("phy")) {
                        int phy = options.getInt("phy");
                        gatt = device.connectGatt(activity, false, this, BluetoothDevice.TRANSPORT_LE, phy);
                    } else {
                        gatt = device.connectGatt(activity, autoconnect, this, BluetoothDevice.TRANSPORT_LE);
                    }
                } else {
                    Log.d(BleManager.LOG_TAG, " Less than M");
                    try {
                        Log.d(BleManager.LOG_TAG, " Trying TRANPORT LE with reflection");
                        Method m = device.getClass().getDeclaredMethod("connectGatt", Context.class, Boolean.class,
                                BluetoothGattCallback.class, Integer.class);
                        m.setAccessible(true);
                        Integer transport = device.getClass().getDeclaredField("TRANSPORT_LE").getInt(null);
                        gatt = (BluetoothGatt) m.invoke(device, activity, false, this, transport);
                    } catch (Exception e) {
                        e.printStackTrace();
                        Log.d(TAG, " Catch to call normal connection");
                        gatt = device.connectGatt(activity, false, this);
                    }
                }
            } else {
                if (gatt != null) {
                    callback.invoke();
                } else {
                    callback.invoke("BluetoothGatt is null");
                }
            }
        });
    }
    // bt_btif : Register with GATT stack failed.

    public void disconnect(final Callback callback, final boolean force) {
        mainHandler.post(() -> {
            for (Callback connectCallback : connectCallbacks) {
                connectCallback.invoke("Disconnect called before connect callback invoked");
            }
            connectCallbacks.clear();
            connected = false;
            clearBuffers();
            commandQueue.clear();
            commandQueueBusy = false;

            if (gatt != null) {
                try {
                    gatt.disconnect();
                    if (force) {
                        gatt.close();
                        gatt = null;
                        sendConnectionEvent(device, "BleManagerDisconnectPeripheral", BluetoothGatt.GATT_SUCCESS);
                    }
                    Log.d(BleManager.LOG_TAG, "Disconnect");
                } catch (Exception e) {
                    sendConnectionEvent(device, "BleManagerDisconnectPeripheral", BluetoothGatt.GATT_FAILURE);
                    Log.d(BleManager.LOG_TAG, "Error on disconnect", e);
                }
            } else
                Log.d(BleManager.LOG_TAG, "GATT is null");
            if (callback != null)
                callback.invoke();
        });
    }

    public WritableMap asWritableMap() {
        WritableMap map = Arguments.createMap();
        WritableMap advertising = Arguments.createMap();

        try {
            map.putString("name", device.getName());
            map.putString("id", device.getAddress()); // mac address
            map.putInt("rssi", advertisingRSSI);

            String name = device.getName();
            if (name != null)
                advertising.putString("localName", name);

            advertising.putMap("manufacturerData", byteArrayToWritableMap(advertisingDataBytes));

            // No scanResult to access so we can't check if peripheral is connectable
            advertising.putBoolean("isConnectable", true);

            map.putMap("advertising", advertising);
        } catch (Exception e) { // this shouldn't happen
            e.printStackTrace();
        }

        return map;
    }

    public WritableMap asWritableMap(BluetoothGatt gatt) {

        WritableMap map = asWritableMap();

        WritableArray servicesArray = Arguments.createArray();
        WritableArray characteristicsArray = Arguments.createArray();

        if (connected && gatt != null) {
            for (Iterator<BluetoothGattService> it = gatt.getServices().iterator(); it.hasNext();) {
                BluetoothGattService service = it.next();
                WritableMap serviceMap = Arguments.createMap();
                serviceMap.putString("uuid", UUIDHelper.uuidToString(service.getUuid()));

                for (Iterator<BluetoothGattCharacteristic> itCharacteristic = service.getCharacteristics()
                        .iterator(); itCharacteristic.hasNext();) {
                    BluetoothGattCharacteristic characteristic = itCharacteristic.next();
                    WritableMap characteristicsMap = Arguments.createMap();

                    characteristicsMap.putString("service", UUIDHelper.uuidToString(service.getUuid()));
                    characteristicsMap.putString("characteristic", UUIDHelper.uuidToString(characteristic.getUuid()));

                    characteristicsMap.putMap("properties", Helper.decodeProperties(characteristic));

                    if (characteristic.getPermissions() > 0) {
                        characteristicsMap.putMap("permissions", Helper.decodePermissions(characteristic));
                    }

                    WritableArray descriptorsArray = Arguments.createArray();

                    for (BluetoothGattDescriptor descriptor : characteristic.getDescriptors()) {
                        WritableMap descriptorMap = Arguments.createMap();
                        descriptorMap.putString("uuid", UUIDHelper.uuidToString(descriptor.getUuid()));
                        if (descriptor.getValue() != null) {
                            descriptorMap.putString("value",
                                    Base64.encodeToString(descriptor.getValue(), Base64.NO_WRAP));
                        } else {
                            descriptorMap.putString("value", null);
                        }

                        if (descriptor.getPermissions() > 0) {
                            descriptorMap.putMap("permissions", Helper.decodePermissions(descriptor));
                        }
                        descriptorsArray.pushMap(descriptorMap);
                    }
                    if (descriptorsArray.size() > 0) {
                        characteristicsMap.putArray("descriptors", descriptorsArray);
                    }
                    characteristicsArray.pushMap(characteristicsMap);
                }
                servicesArray.pushMap(serviceMap);
            }
            map.putArray("services", servicesArray);
            map.putArray("characteristics", characteristicsArray);
        }

        return map;
    }

    static WritableMap byteArrayToWritableMap(byte[] bytes) throws JSONException {
        WritableMap object = Arguments.createMap();
        object.putString("CDVType", "ArrayBuffer");
        object.putString("data", bytes != null ? Base64.encodeToString(bytes, Base64.NO_WRAP) : null);
        object.putArray("bytes", bytes != null ? BleManager.bytesToWritableArray(bytes) : null);
        return object;
    }

    public boolean isConnected() {
        return connected;
    }

    public boolean isConnecting() {
        return connecting;
    }

    public BluetoothDevice getDevice() {
        return device;
    }

    @Override
    public void onServicesDiscovered(BluetoothGatt gatt, int status) {
        super.onServicesDiscovered(gatt, status);
        mainHandler.post(() -> {
            WritableMap map = this.asWritableMap(gatt);
            for (Callback retrieveServicesCallback : retrieveServicesCallbacks) {
                retrieveServicesCallback.invoke(null, map);
            }
            retrieveServicesCallbacks.clear();
            completedCommand();
        });
    }

    @Override
    public void onConnectionStateChange(BluetoothGatt gatta, int status, final int newState) {

        Log.d(BleManager.LOG_TAG, "onConnectionStateChange to " + newState + " on peripheral: " + device.getAddress()
                + " with status " + status);

        mainHandler.post(() -> {
            gatt = gatta;

            if (status != BluetoothGatt.GATT_SUCCESS) {
                gatt.close();
            }

            connecting = false;
            if (newState == BluetoothProfile.STATE_CONNECTED && status == BluetoothGatt.GATT_SUCCESS) {
                connected = true;

                discoverServicesRunnable = new Runnable() {
                    @Override
                    public void run() {
                        try {
                            gatt.discoverServices();
                        } catch (NullPointerException e) {
                            Log.d(BleManager.LOG_TAG,
                                    "onConnectionStateChange connected but gatt of Run method was null");
                        }
                        discoverServicesRunnable = null;
                    }
                };

                mainHandler.post(discoverServicesRunnable);

                sendConnectionEvent(device, "BleManagerConnectPeripheral", status);

                Log.d(BleManager.LOG_TAG, "Connected to: " + device.getAddress());
                for (Callback connectCallback : connectCallbacks) {
                    connectCallback.invoke();
                }
                connectCallbacks.clear();

            } else if (newState == BluetoothProfile.STATE_DISCONNECTED || status != BluetoothGatt.GATT_SUCCESS) {

                if (discoverServicesRunnable != null) {
                    mainHandler.removeCallbacks(discoverServicesRunnable);
                    discoverServicesRunnable = null;
                }

                for (Callback writeCallback : writeCallbacks) {
                    writeCallback.invoke("Device disconnected");
                }
                writeCallbacks.clear();

                for (Callback retrieveServicesCallback : retrieveServicesCallbacks) {
                    retrieveServicesCallback.invoke("Device disconnected");
                }
                retrieveServicesCallbacks.clear();

                for (Callback readRSSICallback : readRSSICallbacks) {
                    readRSSICallback.invoke("Device disconnected");
                }
                readRSSICallbacks.clear();

                for (Callback registerNotifyCallback : registerNotifyCallbacks) {
                    registerNotifyCallback.invoke("Device disconnected");
                }
                registerNotifyCallbacks.clear();

                for (Callback requestMTUCallback : requestMTUCallbacks) {
                    requestMTUCallback.invoke("Device disconnected");
                }
                requestMTUCallbacks.clear();

                for (Callback readCallback : readCallbacks) {
                    readCallback.invoke("Device disconnected");
                }
                readCallbacks.clear();

                for (Callback readDescriptorCallback : readDescriptorCallbacks) {
                    readDescriptorCallback.invoke("Device disconnected");
                }
                readDescriptorCallbacks.clear();

                for (Callback connectCallback : connectCallbacks) {
                    connectCallback.invoke("Connection error");
                }
                connectCallbacks.clear();

                writeQueue.clear();
                commandQueue.clear();
                commandQueueBusy = false;
                connected = false;
                clearBuffers();
                commandQueue.clear();
                commandQueueBusy = false;

                gatt.disconnect();
                gatt.close();
                gatt = null;
                sendConnectionEvent(device, "BleManagerDisconnectPeripheral", BluetoothGatt.GATT_SUCCESS);

            }

        });

    }

    public void updateRssi(int rssi) {
        advertisingRSSI = rssi;
    }

    public void updateData(byte[] data) {
        advertisingDataBytes = data;
    }

    public int unsignedToBytes(byte b) {
        return b & 0xFF;
    }

    //////

    @Override
    public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic) {
        super.onCharacteristicChanged(gatt, characteristic);
        try {
            String charString = characteristic.getUuid().toString();
            String service = characteristic.getService().getUuid().toString();
            NotifyBufferContainer buffer = this.bufferedCharacteristics
                    .get(this.bufferedCharacteristicsKey(service, charString));
            byte[] dataValue = characteristic.getValue();
            // If for some reason the value's length >= 2*buffer size this will be able to
            // handle it
            while (dataValue != null) {
                byte[] rest = null;
                if (buffer != null) {
                    rest = buffer.put(dataValue);
                    Log.d(BleManager.LOG_TAG, "onCharacteristicChanged-buffering: " +
                            buffer.size() + " from peripheral: " + device.getAddress());

                    if (buffer.isBufferFull()) {
                        Log.d(BleManager.LOG_TAG, "onCharacteristicChanged sending buffered data " + buffer.size());

                        // fetch and reset
                        dataValue = buffer.items.array();
                        buffer.resetBuffer();
                    } else {
                        return;
                    }
                }
                Log.d(BleManager.LOG_TAG, "onCharacteristicChanged: " + BleManager.bytesToHex(dataValue)
                        + " from peripheral: " + device.getAddress());
                WritableMap map = Arguments.createMap();
                map.putString("peripheral", device.getAddress());
                map.putString("characteristic", charString);
                map.putString("service", service);
                map.putArray("value", BleManager.bytesToWritableArray(dataValue));
                sendEvent("BleManagerDidUpdateValueForCharacteristic", map);

                // Check if rest exists. If so it needs to be added to the clean buffer
                dataValue = rest;
            }

        } catch (Exception e) {
            Log.d(BleManager.LOG_TAG, "onCharacteristicChanged ERROR: " + e);
        }
    }

    @Override
    public void onCharacteristicRead(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status) {
        super.onCharacteristicRead(gatt, characteristic, status);

        mainHandler.post(() -> {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                if (status == GATT_AUTH_FAIL || status == GATT_INSUFFICIENT_AUTHENTICATION) {
                    Log.d(BleManager.LOG_TAG, "Read needs bonding");
                }

                for (Callback readCallback : readCallbacks) {
                    readCallback.invoke(
                            "Error reading " + characteristic.getUuid() + " status=" + status,
                            null);
                }
                readCallbacks.clear();
            } else if (!readCallbacks.isEmpty()) {
                final byte[] dataValue = copyOf(characteristic.getValue());

                for (Callback readCallback : readCallbacks) {
                    readCallback.invoke(null, BleManager.bytesToWritableArray(dataValue));
                }
                readCallbacks.clear();
            }
            completedCommand();
        });

    }

    @Override
    public void onCharacteristicWrite(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status) {
        super.onCharacteristicWrite(gatt, characteristic, status);

        mainHandler.post(() -> {
            if (writeQueue.size() > 0) {
                byte[] data = writeQueue.get(0);
                writeQueue.remove(0);
                doWrite(characteristic, data, null);
            } else if (status != BluetoothGatt.GATT_SUCCESS) {
                if (status == GATT_AUTH_FAIL || status == GATT_INSUFFICIENT_AUTHENTICATION) {
                    Log.d(BleManager.LOG_TAG, "Write needs bonding");
                    // *not* doing completedCommand()
                    return;
                }
                for (Callback writeCallback : writeCallbacks) {
                    writeCallback.invoke("Error writing " + characteristic.getUuid() + " status=" + status, null);
                }
                writeCallbacks.clear();
            } else if (!writeCallbacks.isEmpty()) {
                for (Callback writeCallback : writeCallbacks) {
                    writeCallback.invoke();
                }
                writeCallbacks.clear();
            }
            completedCommand();
        });
    }

    @Override
    public void onDescriptorWrite(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status) {
        mainHandler.post(() -> {
            if (!registerNotifyCallbacks.isEmpty()) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    for (Callback registerNotifyCallback : registerNotifyCallbacks) {
                        registerNotifyCallback.invoke();
                    }
                    Log.d(BleManager.LOG_TAG, "onDescriptorWrite success");
                } else {
                    for (Callback registerNotifyCallback : registerNotifyCallbacks) {
                        registerNotifyCallback.invoke("Error writing descriptor status=" + status, null);
                    }
                    Log.e(BleManager.LOG_TAG, "Error writing descriptor status=" + status);
                }

                registerNotifyCallbacks.clear();
            } else {
                Log.e(BleManager.LOG_TAG, "onDescriptorWrite with no callback");
            }

            completedCommand();
        });
    }

    @Override
    public void onDescriptorRead(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status) {
        super.onDescriptorRead(gatt, descriptor, status);

        mainHandler.post(() -> {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                if (status == GATT_AUTH_FAIL || status == GATT_INSUFFICIENT_AUTHENTICATION) {
                    Log.d(BleManager.LOG_TAG, "Read needs bonding");
                }

                for (Callback readDescriptorCallback : readDescriptorCallbacks) {
                    readDescriptorCallback.invoke(
                            "Error reading descriptor " + descriptor.getUuid() + " status=" + status,
                            null);
                }
                readDescriptorCallbacks.clear();
            } else if (!readDescriptorCallbacks.isEmpty()) {
                final byte[] dataValue = copyOf(descriptor.getValue());

                for (Callback readDescriptorCallback : readDescriptorCallbacks) {
                    readDescriptorCallback.invoke(
                            null,
                            BleManager.bytesToWritableArray(dataValue));
                }

                readDescriptorCallbacks.clear();
            }
            completedCommand();
        });
    }

    @Override
    public void onReadRemoteRssi(BluetoothGatt gatt, int rssi, int status) {
        super.onReadRemoteRssi(gatt, rssi, status);

        mainHandler.post(() -> {
            if (!readRSSICallbacks.isEmpty()) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    updateRssi(rssi);
                    for (Callback readRSSICallback : readRSSICallbacks) {
                        readRSSICallback.invoke(null, rssi);
                    }
                } else {
                    for (Callback readRSSICallback : readRSSICallbacks) {
                        readRSSICallback.invoke("Error reading RSSI status=" + status, null);
                    }
                }

                readRSSICallbacks.clear();
            }

            completedCommand();
        });
    }

    private String bufferedCharacteristicsKey(String serviceUUID, String characteristicUUID) {
        return serviceUUID + "-" + characteristicUUID;
    }

    private void clearBuffers() {
        for (Map.Entry<String, NotifyBufferContainer> entry : this.bufferedCharacteristics.entrySet())
            entry.getValue().resetBuffer();
    }

    private void setNotify(UUID serviceUUID, UUID characteristicUUID, final Boolean notify, Callback callback) {
        if (!isConnected() || gatt == null) {
            callback.invoke("Device is not connected", null);
            completedCommand();
            return;
        }

        BluetoothGattService service = gatt.getService(serviceUUID);
        final BluetoothGattCharacteristic characteristic = findNotifyCharacteristic(service, characteristicUUID);

        if (characteristic == null) {
            callback.invoke("Characteristic " + characteristicUUID + " not found");
            completedCommand();
            return;
        }

        if (!gatt.setCharacteristicNotification(characteristic, notify)) {
            callback.invoke("Failed to register notification for " + characteristicUUID);
            completedCommand();
            return;
        }

        final BluetoothGattDescriptor descriptor = characteristic
                .getDescriptor(UUIDHelper.uuidFromString(CHARACTERISTIC_NOTIFICATION_CONFIG));
        if (descriptor == null) {
            callback.invoke("Set notification failed for " + characteristicUUID);
            completedCommand();
            return;
        }

        // Prefer notify over indicate
        byte[] value;
        if ((characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0) {
            Log.d(BleManager.LOG_TAG, "Characteristic " + characteristicUUID + " set NOTIFY");
            value = notify ? BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                    : BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE;
        } else if ((characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0) {
            Log.d(BleManager.LOG_TAG, "Characteristic " + characteristicUUID + " set INDICATE");
            value = notify ? BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
                    : BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE;
        } else {
            String msg = "Characteristic " + characteristicUUID + " does not have NOTIFY or INDICATE property set";
            Log.d(BleManager.LOG_TAG, msg);
            callback.invoke(msg);
            completedCommand();
            return;
        }
        final byte[] finalValue = notify ? value : BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE;

        boolean result = false;
        try {
            result = gatt.setCharacteristicNotification(characteristic, notify);
            // Then write to descriptor
            descriptor.setValue(finalValue);
            registerNotifyCallbacks.addLast(callback);
            result &= gatt.writeDescriptor(descriptor);
        } catch (Exception e) {
            Log.d(BleManager.LOG_TAG, "Exception in setNotify", e);
        }

        if (!result) {
            for (Callback registerNotifyCallback : registerNotifyCallbacks) {
                registerNotifyCallback.invoke("writeDescriptor failed for descriptor: " + descriptor.getUuid(), null);
            }
            registerNotifyCallbacks.clear();
            completedCommand();
        }
    }

    public void registerNotify(UUID serviceUUID, UUID characteristicUUID, Integer buffer, Callback callback) {
        if (!enqueue(() -> {
            Log.d(BleManager.LOG_TAG, "registerNotify");
            if (buffer > 1) {
                Log.d(BleManager.LOG_TAG, "registerNotify using buffer");
                String bufferKey = this.bufferedCharacteristicsKey(serviceUUID.toString(),
                        characteristicUUID.toString());
                this.bufferedCharacteristics.put(bufferKey, new NotifyBufferContainer(buffer));
            }
            this.setNotify(serviceUUID, characteristicUUID, true, callback);
        })) {
            Log.e(BleManager.LOG_TAG, "Could not enqueue setNotify command to register notify");
        }
    }

    public void removeNotify(UUID serviceUUID, UUID characteristicUUID, Callback callback) {
        if (!enqueue(() -> {
            Log.d(BleManager.LOG_TAG, "removeNotify");
            String bufferKey = this.bufferedCharacteristicsKey(serviceUUID.toString(), characteristicUUID.toString());
            if (this.bufferedCharacteristics.containsKey(bufferKey)) {
                NotifyBufferContainer buffer = this.bufferedCharacteristics.get(bufferKey);
                this.bufferedCharacteristics.remove(bufferKey);
            }
            this.setNotify(serviceUUID, characteristicUUID, false, callback);
        })) {
            Log.e(BleManager.LOG_TAG, "Could not enqueue setNotify command to remove notify");
        }
    }

    // Some devices reuse UUIDs across characteristics, so we can't use
    // service.getCharacteristic(characteristicUUID)
    // instead check the UUID and properties for each characteristic in the service
    // until we find the best match
    // This function prefers Notify over Indicate
    private BluetoothGattCharacteristic findNotifyCharacteristic(BluetoothGattService service,
            UUID characteristicUUID) {

        try {
            // Check for Notify first
            List<BluetoothGattCharacteristic> characteristics = service.getCharacteristics();
            for (BluetoothGattCharacteristic characteristic : characteristics) {
                if ((characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0
                        && characteristicUUID.equals(characteristic.getUuid())) {
                    return characteristic;
                }
            }

            // If there wasn't Notify Characteristic, check for Indicate
            for (BluetoothGattCharacteristic characteristic : characteristics) {
                if ((characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0
                        && characteristicUUID.equals(characteristic.getUuid())) {
                    return characteristic;
                }
            }

            // As a last resort, try and find ANY characteristic with this UUID, even if it
            // doesn't have the correct properties
            return service.getCharacteristic(characteristicUUID);
        } catch (Exception e) {
            Log.e(BleManager.LOG_TAG, "Error retriving characteristic " + characteristicUUID, e);
            return null;
        }
    }

    public void read(UUID serviceUUID, UUID characteristicUUID, final Callback callback) {
        enqueue(() -> {
            if (!isConnected() || gatt == null) {
                callback.invoke("Device is not connected", null);
                completedCommand();
                return;
            }

            BluetoothGattService service = gatt.getService(serviceUUID);
            final BluetoothGattCharacteristic characteristic = findReadableCharacteristic(service, characteristicUUID);

            if (characteristic == null) {
                callback.invoke("Characteristic " + characteristicUUID + " not found.", null);
                completedCommand();
                return;
            }

            this.readCallbacks.addLast(callback);
            if (!gatt.readCharacteristic(characteristic)) {
                for (Callback readCallback : readCallbacks) {
                    readCallback.invoke("Read failed", null);
                }
                readCallbacks.clear();
                completedCommand();
            }
        });
    }

    public void readDescriptor(UUID serviceUUID, UUID characteristicUUID, UUID descriptorUUID,
            final Callback callback) {
        enqueue(() -> {
            if (!isConnected() || gatt == null) {
                callback.invoke("Device is not connected", null);
                completedCommand();
                return;
            }

            BluetoothGattService service = gatt.getService(serviceUUID);
            final BluetoothGattCharacteristic characteristic = findReadableCharacteristic(service, characteristicUUID);

            if (characteristic == null) {
                callback.invoke("Characteristic " + characteristicUUID + " not found.", null);
                completedCommand();
                return;
            }

            final BluetoothGattDescriptor descriptor = characteristic.getDescriptor(descriptorUUID);
            if (descriptor == null) {
                callback.invoke("Read descriptor failed for " + descriptorUUID, null);
                completedCommand();
                return;
            }

            final int readPermissionBitMask = BluetoothGattDescriptor.PERMISSION_READ
                    | BluetoothGattDescriptor.PERMISSION_READ_ENCRYPTED
                    | BluetoothGattDescriptor.PERMISSION_READ_ENCRYPTED_MITM;
            if ((descriptor.getPermissions() & readPermissionBitMask) != 0) {
                callback.invoke(
                        "Read descriptor failed for " + descriptorUUID + ": Descriptor is missing read permission",
                        null);
                completedCommand();
                return;
            }

            this.readDescriptorCallbacks.addLast(callback);
            if (!gatt.readDescriptor(descriptor)) {
                for (Callback readDescriptorCallback : readDescriptorCallbacks) {
                    readDescriptorCallback.invoke("Reading descriptor failed", null);
                }
                readDescriptorCallbacks.clear();
                completedCommand();
            }
        });
    }

    private byte[] copyOf(byte[] source) {
        if (source == null)
            return new byte[0];
        final int sourceLength = source.length;
        final byte[] copy = new byte[sourceLength];
        System.arraycopy(source, 0, copy, 0, sourceLength);
        return copy;
    }

    private boolean enqueue(Runnable command) {
        final boolean result = commandQueue.add(command);
        if (result) {
            nextCommand();
        } else {
            Log.d(BleManager.LOG_TAG, "could not enqueue command");
        }
        return result;
    }

    private void completedCommand() {
        commandQueue.poll();
        commandQueueBusy = false;
        nextCommand();
    }

    private void nextCommand() {
        synchronized (this) {
            if (commandQueueBusy) {
                Log.d(BleManager.LOG_TAG, "Command queue busy");
                return;
            }

            final Runnable nextCommand = commandQueue.peek();
            if (nextCommand == null) {
                Log.d(BleManager.LOG_TAG, "Command queue empty");
                return;
            }

            // Check if we still have a valid gatt object
            if (gatt == null) {
                Log.d(BleManager.LOG_TAG, "Error, gatt is null");
                commandQueue.clear();
                commandQueueBusy = false;
                return;
            }

            // Execute the next command in the queue
            commandQueueBusy = true;
            mainHandler.post(new Runnable() {
                @Override
                public void run() {
                    try {
                        nextCommand.run();
                    } catch (Exception ex) {
                        Log.d(BleManager.LOG_TAG, "Error, command exception");
                        completedCommand();
                    }
                }
            });
        }
    }

    public void readRSSI(final Callback callback) {
        if (!enqueue(() -> {
            if (!isConnected()) {
                callback.invoke("Device is not connected", null);
                completedCommand();
                return;
            } else if (gatt == null) {
                callback.invoke("BluetoothGatt is null", null);
                completedCommand();
                return;
            } else {
                readRSSICallbacks.addLast(callback);
                if (!gatt.readRemoteRssi()) {
                    for (Callback readRSSICallback : readRSSICallbacks) {
                        readRSSICallback.invoke("Read RSSI failed", null);
                    }
                    readRSSICallbacks.clear();
                    completedCommand();
                }
            }
        })) {
            Log.d(BleManager.LOG_TAG, "Could not queue readRemoteRssi command");
        }
    }

    public void refreshCache(Callback callback) {
        enqueue(() -> {
            try {
                Method localMethod = gatt.getClass().getMethod("refresh", new Class[0]);
                if (localMethod != null) {
                    boolean res = ((Boolean) localMethod.invoke(gatt, new Object[0])).booleanValue();
                    callback.invoke(null, res);
                } else {
                    callback.invoke("Could not refresh cache for device.");
                }
            } catch (Exception localException) {
                Log.e(TAG, "An exception occured while refreshing device");
                callback.invoke(localException.getMessage());
            } finally {
                completedCommand();
            }
        });
    }

    public void retrieveServices(Callback callback) {
        enqueue(() -> {
            if (!isConnected()) {
                callback.invoke("Device is not connected", null);
                completedCommand();
                return;
            } else if (gatt == null) {
                callback.invoke("BluetoothGatt is null", null);
                completedCommand();
                return;
            } else {
                this.retrieveServicesCallbacks.addLast(callback);
                gatt.discoverServices();
            }
        });
    }

    // Some peripherals re-use UUIDs for multiple characteristics so we need to
    // check the properties
    // and UUID of all characteristics instead of using
    // service.getCharacteristic(characteristicUUID)
    private BluetoothGattCharacteristic findReadableCharacteristic(BluetoothGattService service,
            UUID characteristicUUID) {

        if (service != null) {
            int read = BluetoothGattCharacteristic.PROPERTY_READ;

            List<BluetoothGattCharacteristic> characteristics = service.getCharacteristics();
            for (BluetoothGattCharacteristic characteristic : characteristics) {
                if ((characteristic.getProperties() & read) != 0
                        && characteristicUUID.equals(characteristic.getUuid())) {
                    return characteristic;
                }
            }

            // As a last resort, try and find ANY characteristic with this UUID, even if it
            // doesn't have the correct properties
            return service.getCharacteristic(characteristicUUID);
        }

        return null;
    }

    public boolean doWrite(final BluetoothGattCharacteristic characteristic, byte[] data, final Callback callback) {
        final byte[] copyOfData = copyOf(data);
        return enqueue(new Runnable() {
            @Override
            public void run() {
                characteristic.setValue(copyOfData);
                if (characteristic.getWriteType() == BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                        && callback != null) {
                    writeCallbacks.addLast(callback);
                }
                if (!gatt.writeCharacteristic(characteristic)) {
                    // write without response, caller will handle the callback
                    for (Callback writeCallback : writeCallbacks) {
                        writeCallback.invoke("Write failed", writeCallback);
                    }
                    writeCallbacks.clear();
                    completedCommand();
                }
            }
        });
    }

    public void write(UUID serviceUUID, UUID characteristicUUID, byte[] data, Integer maxByteSize,
            Integer queueSleepTime, Callback callback, int writeType) {
        enqueue(() -> {
            if (!isConnected() || gatt == null) {
                callback.invoke("Device is not connected", null);
                completedCommand();
                return;
            }

            BluetoothGattService service = gatt.getService(serviceUUID);
            BluetoothGattCharacteristic characteristic = findWritableCharacteristic(service, characteristicUUID,
                    writeType);

            if (characteristic == null) {
                callback.invoke("Characteristic " + characteristicUUID + " not found.");
                completedCommand();
                return;
            }

            characteristic.setWriteType(writeType);

            if (data.length <= maxByteSize) {
                if (!doWrite(characteristic, data, callback)) {
                    callback.invoke("Write failed");
                } else {
                    if (BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE == writeType) {
                        callback.invoke();
                    }
                }
            } else {
                int dataLength = data.length;
                int count = 0;
                byte[] firstMessage = null;
                List<byte[]> splittedMessage = new ArrayList<>();

                while (count < dataLength && (dataLength - count > maxByteSize)) {
                    if (count == 0) {
                        firstMessage = Arrays.copyOfRange(data, count, count + maxByteSize);
                    } else {
                        byte[] splitMessage = Arrays.copyOfRange(data, count, count + maxByteSize);
                        splittedMessage.add(splitMessage);
                    }
                    count += maxByteSize;
                }
                if (count < dataLength) {
                    // Other bytes in queue
                    byte[] splitMessage = Arrays.copyOfRange(data, count, data.length);
                    splittedMessage.add(splitMessage);
                }

                if (BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT == writeType) {
                    writeQueue.addAll(splittedMessage);
                    if (!doWrite(characteristic, firstMessage, callback)) {
                        writeQueue.clear();
                        callback.invoke("Write failed");
                    }
                } else {
                    try {
                        boolean writeError = false;
                        if (!doWrite(characteristic, firstMessage, callback)) {
                            writeError = true;
                            callback.invoke("Write failed");
                        }
                        if (!writeError) {
                            Thread.sleep(queueSleepTime);
                            for (byte[] message : splittedMessage) {
                                if (!doWrite(characteristic, message, callback)) {
                                    writeError = true;
                                    callback.invoke("Write failed");
                                    break;
                                }
                                Thread.sleep(queueSleepTime);
                            }
                            if (!writeError) {
                                callback.invoke();
                            }
                        }
                    } catch (InterruptedException e) {
                        callback.invoke("Error during writing");
                    }
                }
            }

            completedCommand();
        });
    }

    public void requestConnectionPriority(int connectionPriority, Callback callback) {
        enqueue(() -> {
            if (gatt != null) {
                boolean status = gatt.requestConnectionPriority(connectionPriority);
                callback.invoke(null, status);
            } else {
                callback.invoke("BluetoothGatt is null", null);
            }

            completedCommand();
        });
    }

    public void requestMTU(int mtu, Callback callback) {
        enqueue(() -> {
            if (!isConnected()) {
                callback.invoke("Device is not connected", null);
                completedCommand();
                return;
            }

            if (gatt == null) {
                callback.invoke("BluetoothGatt is null", null);
                completedCommand();
                return;
            }

            requestMTUCallbacks.addLast(callback);
            if (!gatt.requestMtu(mtu)) {
                for (Callback requestMTUCallback : requestMTUCallbacks) {
                    requestMTUCallback.invoke("Request MTU failed", null);
                }
                requestMTUCallbacks.clear();
                completedCommand();
            }
        });
    }

    @Override
    public void onMtuChanged(BluetoothGatt gatt, int mtu, int status) {
        super.onMtuChanged(gatt, mtu, status);
        mainHandler.post(() -> {
            if (!requestMTUCallbacks.isEmpty()) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    for (Callback requestMTUCallback : requestMTUCallbacks) {
                        requestMTUCallback.invoke(null, mtu);
                    }
                } else {
                    for (Callback requestMTUCallback : requestMTUCallbacks) {
                        requestMTUCallback.invoke("Error requesting MTU status = " + status, null);
                    }
                }

                requestMTUCallbacks.clear();
            }

            completedCommand();
        });
    }

    // Some peripherals re-use UUIDs for multiple characteristics so we need to
    // check the properties
    // and UUID of all characteristics instead of using
    // service.getCharacteristic(characteristicUUID)
    private BluetoothGattCharacteristic findWritableCharacteristic(BluetoothGattService service,
            UUID characteristicUUID, int writeType) {
        try {
            // get write property
            int writeProperty = BluetoothGattCharacteristic.PROPERTY_WRITE;
            if (writeType == BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE) {
                writeProperty = BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE;
            }

            List<BluetoothGattCharacteristic> characteristics = service.getCharacteristics();
            for (BluetoothGattCharacteristic characteristic : characteristics) {
                if ((characteristic.getProperties() & writeProperty) != 0
                        && characteristicUUID.equals(characteristic.getUuid())) {
                    return characteristic;
                }
            }

            // As a last resort, try and find ANY characteristic with this UUID, even if it
            // doesn't have the correct properties
            return service.getCharacteristic(characteristicUUID);
        } catch (Exception e) {
            Log.e(BleManager.LOG_TAG, "Error on findWritableCharacteristic", e);
            return null;
        }
    }

    private String generateHashKey(BluetoothGattCharacteristic characteristic) {
        return generateHashKey(characteristic.getService().getUuid(), characteristic);
    }

    private String generateHashKey(UUID serviceUUID, BluetoothGattCharacteristic characteristic) {
        return serviceUUID + "|" + characteristic.getUuid() + "|" + characteristic.getInstanceId();
    }

}
