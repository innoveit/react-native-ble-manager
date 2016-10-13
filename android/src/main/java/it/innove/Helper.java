package it.innove;

import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.WritableMap;
import org.json.JSONArray;

public class Helper {

	public static WritableMap decodeProperties(BluetoothGattCharacteristic characteristic) {

		// NOTE: props strings need to be consistent across iOS and Android
		WritableMap props = Arguments.createMap();
		int properties = characteristic.getProperties();

		if ((properties & BluetoothGattCharacteristic.PROPERTY_BROADCAST) != 0x0 ) {
			props.putString("Broadcast", "Broadcast");
		}

		if ((properties & BluetoothGattCharacteristic.PROPERTY_READ) != 0x0 ) {
			props.putString("Read", "Read");
		}

		if ((properties & BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE) != 0x0 ) {
			props.putString("WriteWithoutResponse", "WriteWithoutResponse");
		}

		if ((properties & BluetoothGattCharacteristic.PROPERTY_WRITE) != 0x0 ) {
			props.putString("Write", "Write");
		}

		if ((properties & BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0x0 ) {
			props.putString("Notify", "Notify");
		}

		if ((properties & BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0x0 ) {
			props.putString("Indicate", "Indicate");
		}

		if ((properties & BluetoothGattCharacteristic.PROPERTY_SIGNED_WRITE) != 0x0 ) {
			// Android calls this "write with signature", using iOS name for now
			props.putString("AuthenticateSignedWrites", "AuthenticateSignedWrites");
		}

		if ((properties & BluetoothGattCharacteristic.PROPERTY_EXTENDED_PROPS) != 0x0 ) {
			props.putString("ExtendedProperties", "ExtendedProperties");
		}

//      iOS only?
//
//            if ((p & CBCharacteristicPropertyNotifyEncryptionRequired) != 0x0) {  // 0x100
//                [props addObject:@"NotifyEncryptionRequired"];
//            }
//
//            if ((p & CBCharacteristicPropertyIndicateEncryptionRequired) != 0x0) { // 0x200
//                [props addObject:@"IndicateEncryptionRequired"];
//            }

		return props;
	}

	public static WritableMap decodePermissions(BluetoothGattCharacteristic characteristic) {

		// NOTE: props strings need to be consistent across iOS and Android
		WritableMap props = Arguments.createMap();
		int permissions = characteristic.getPermissions();

		if ((permissions & BluetoothGattCharacteristic.PERMISSION_READ) != 0x0 ) {
			props.putString("Read", "Read");
		}

		if ((permissions & BluetoothGattCharacteristic.PERMISSION_WRITE) != 0x0 ) {
			props.putString("Write", "Write");
		}

		if ((permissions & BluetoothGattCharacteristic.PERMISSION_READ_ENCRYPTED) != 0x0 ) {
			props.putString("ReadEncrypted", "ReadEncrypted");
		}

		if ((permissions & BluetoothGattCharacteristic.PERMISSION_WRITE_ENCRYPTED) != 0x0 ) {
			props.putString("WriteEncrypted", "WriteEncrypted");
		}

		if ((permissions & BluetoothGattCharacteristic.PERMISSION_READ_ENCRYPTED_MITM) != 0x0 ) {
			props.putString("ReadEncryptedMITM", "ReadEncryptedMITM");
		}

		if ((permissions & BluetoothGattCharacteristic.PERMISSION_WRITE_ENCRYPTED_MITM) != 0x0 ) {
			props.putString("WriteEncryptedMITM", "WriteEncryptedMITM");
		}

		if ((permissions & BluetoothGattCharacteristic.PERMISSION_WRITE_SIGNED) != 0x0 ) {
			props.putString("WriteSigned", "WriteSigned");
		}

		if ((permissions & BluetoothGattCharacteristic.PERMISSION_WRITE_SIGNED_MITM) != 0x0 ) {
			props.putString("WriteSignedMITM", "WriteSignedMITM");
		}

		return props;
	}

	public static WritableMap decodePermissions(BluetoothGattDescriptor descriptor) {

		// NOTE: props strings need to be consistent across iOS and Android
		WritableMap props = Arguments.createMap();
		int permissions = descriptor.getPermissions();

		if ((permissions & BluetoothGattDescriptor.PERMISSION_READ) != 0x0 ) {
			props.putString("Read", "Read");
		}

		if ((permissions & BluetoothGattDescriptor.PERMISSION_WRITE) != 0x0 ) {
			props.putString("Write", "Write");
		}

		if ((permissions & BluetoothGattDescriptor.PERMISSION_READ_ENCRYPTED) != 0x0 ) {
			props.putString("ReadEncrypted", "ReadEncrypted");
		}

		if ((permissions & BluetoothGattDescriptor.PERMISSION_WRITE_ENCRYPTED) != 0x0 ) {
			props.putString("WriteEncrypted", "WriteEncrypted");
		}

		if ((permissions & BluetoothGattDescriptor.PERMISSION_READ_ENCRYPTED_MITM) != 0x0 ) {
			props.putString("ReadEncryptedMITM", "ReadEncryptedMITM");
		}

		if ((permissions & BluetoothGattDescriptor.PERMISSION_WRITE_ENCRYPTED_MITM) != 0x0 ) {
			props.putString("WriteEncryptedMITM", "WriteEncryptedMITM");
		}

		if ((permissions & BluetoothGattDescriptor.PERMISSION_WRITE_SIGNED) != 0x0 ) {
			props.putString("WriteSigned", "WriteSigned");
		}

		if ((permissions & BluetoothGattDescriptor.PERMISSION_WRITE_SIGNED_MITM) != 0x0 ) {
			props.putString("WriteSignedMITM", "WriteSignedMITM");
		}

		return props;
	}

}