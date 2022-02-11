package it.innove;

import android.util.Log;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.WritableMap;

import static it.innove.BleManager.LOG_TAG;

public class ErrorHelper {
    public static WritableMap makeAttError(String message, int code) {
        WritableMap map = Arguments.createMap();
        map.putString("mesasge", message);
        map.putInt("attCode", code);
        map.putInt("code", BleErrorCode.ATT_ERROR.getNumVal());
        Log.d(LOG_TAG, message);
        return map;
    }

    public static WritableMap makeCustomError(String message, BleErrorCode code) {
        WritableMap map = Arguments.createMap();
        map.putString("mesasge", message);
        map.putInt("code", code.getNumVal());
        Log.d(LOG_TAG, message);
        return map;
    }
}
