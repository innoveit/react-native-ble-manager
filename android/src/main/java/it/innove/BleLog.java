package it.innove;

import android.util.Log;

/**
 * Native logging gated by the {@code logLevel} start() option.
 * <ul>
 *   <li>none: nothing is logged</li>
 *   <li>normal: regular messages, warnings and errors, without data payloads</li>
 *   <li>verbose: everything, including data payloads (bytes/values)</li>
 * </ul>
 */
final class BleLog {
    static final int NONE = 0;
    static final int NORMAL = 1;
    static final int VERBOSE = 2;

    private static volatile int level = NORMAL;

    private BleLog() {
    }

    static void setLevel(int newLevel) {
        level = newLevel;
    }

    static boolean isVerbose() {
        return level >= VERBOSE;
    }

    static int parseLevel(String value) {
        if ("none".equals(value)) {
            return NONE;
        }
        if ("verbose".equals(value)) {
            return VERBOSE;
        }
        return NORMAL;
    }

    /** Regular message, shown in normal and verbose. */
    static void d(String tag, String msg) {
        if (level >= NORMAL) {
            Log.d(tag, msg);
        }
    }

    /** Message that prints data (bytes/values), shown only in verbose. */
    static void data(String tag, String msg) {
        if (level >= VERBOSE) {
            Log.d(tag, msg);
        }
    }

    static void w(String tag, String msg) {
        if (level > NONE) {
            Log.w(tag, msg);
        }
    }

    static void wtf(String tag, String msg) {
        if (level > NONE) {
            Log.wtf(tag, msg);
        }
    }

    static void e(String tag, String msg) {
        if (level > NONE) {
            Log.e(tag, msg);
        }
    }

    static void e(String tag, String msg, Throwable tr) {
        if (level > NONE) {
            Log.e(tag, msg, tr);
        }
    }
}
