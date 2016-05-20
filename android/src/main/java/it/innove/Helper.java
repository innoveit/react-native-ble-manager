package it.innove;

import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import org.json.JSONArray;

public class Helper {

	public static JSONArray decodeProperties(BluetoothGattCharacteristic characteristic) {

		// NOTE: props strings need to be consistent across iOS and Android
		JSONArray props = new JSONArray();
		int properties = characteristic.getProperties();

		if ((properties & BluetoothGattCharacteristic.PROPERTY_BROADCAST) != 0x0 ) {
			props.put("Broadcast");
		}

		if ((properties & BluetoothGattCharacteristic.PROPERTY_READ) != 0x0 ) {
			props.put("Read");
		}

		if ((properties & BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE) != 0x0 ) {
			props.put("WriteWithoutResponse");
		}

		if ((properties & BluetoothGattCharacteristic.PROPERTY_WRITE) != 0x0 ) {
			props.put("Write");
		}

		if ((properties & BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0x0 ) {
			props.put("Notify");
		}

		if ((properties & BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0x0 ) {
			props.put("Indicate");
		}

		if ((properties & BluetoothGattCharacteristic.PROPERTY_SIGNED_WRITE) != 0x0 ) {
			// Android calls this "write with signature", using iOS name for now
			props.put("AuthenticateSignedWrites");
		}

		if ((properties & BluetoothGattCharacteristic.PROPERTY_EXTENDED_PROPS) != 0x0 ) {
			props.put("ExtendedProperties");
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

	public static JSONArray decodePermissions(BluetoothGattCharacteristic characteristic) {

		// NOTE: props strings need to be consistent across iOS and Android
		JSONArray props = new JSONArray();
		int permissions = characteristic.getPermissions();

		if ((permissions & BluetoothGattCharacteristic.PERMISSION_READ) != 0x0 ) {
			props.put("Read");
		}

		if ((permissions & BluetoothGattCharacteristic.PERMISSION_WRITE) != 0x0 ) {
			props.put("Write");
		}

		if ((permissions & BluetoothGattCharacteristic.PERMISSION_READ_ENCRYPTED) != 0x0 ) {
			props.put("ReadEncrypted");
		}

		if ((permissions & BluetoothGattCharacteristic.PERMISSION_WRITE_ENCRYPTED) != 0x0 ) {
			props.put("WriteEncrypted");
		}

		if ((permissions & BluetoothGattCharacteristic.PERMISSION_READ_ENCRYPTED_MITM) != 0x0 ) {
			props.put("ReadEncryptedMITM");
		}

		if ((permissions & BluetoothGattCharacteristic.PERMISSION_WRITE_ENCRYPTED_MITM) != 0x0 ) {
			props.put("WriteEncryptedMITM");
		}

		if ((permissions & BluetoothGattCharacteristic.PERMISSION_WRITE_SIGNED) != 0x0 ) {
			props.put("WriteSigned");
		}

		if ((permissions & BluetoothGattCharacteristic.PERMISSION_WRITE_SIGNED_MITM) != 0x0 ) {
			props.put("WriteSignedMITM");
		}

		return props;
	}

	public static JSONArray decodePermissions(BluetoothGattDescriptor descriptor) {

		// NOTE: props strings need to be consistent across iOS and Android
		JSONArray props = new JSONArray();
		int permissions = descriptor.getPermissions();

		if ((permissions & BluetoothGattDescriptor.PERMISSION_READ) != 0x0 ) {
			props.put("Read");
		}

		if ((permissions & BluetoothGattDescriptor.PERMISSION_WRITE) != 0x0 ) {
			props.put("Write");
		}

		if ((permissions & BluetoothGattDescriptor.PERMISSION_READ_ENCRYPTED) != 0x0 ) {
			props.put("ReadEncrypted");
		}

		if ((permissions & BluetoothGattDescriptor.PERMISSION_WRITE_ENCRYPTED) != 0x0 ) {
			props.put("WriteEncrypted");
		}

		if ((permissions & BluetoothGattDescriptor.PERMISSION_READ_ENCRYPTED_MITM) != 0x0 ) {
			props.put("ReadEncryptedMITM");
		}

		if ((permissions & BluetoothGattDescriptor.PERMISSION_WRITE_ENCRYPTED_MITM) != 0x0 ) {
			props.put("WriteEncryptedMITM");
		}

		if ((permissions & BluetoothGattDescriptor.PERMISSION_WRITE_SIGNED) != 0x0 ) {
			props.put("WriteSigned");
		}

		if ((permissions & BluetoothGattDescriptor.PERMISSION_WRITE_SIGNED_MITM) != 0x0 ) {
			props.put("WriteSignedMITM");
		}

		return props;
	}

}