package it.innove;

import java.util.UUID;

class BLECommand {
	// Types
	public static int READ = 10000;
	public static int REGISTER_NOTIFY = 10001;
	public static int REMOVE_NOTIFY = 10002;
	// BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
	// BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT

	private UUID serviceUUID;
	private UUID characteristicUUID;
	private byte[] data;
	private int type;


	public BLECommand(UUID serviceUUID, UUID characteristicUUID, int type) {
		this.serviceUUID = serviceUUID;
		this.characteristicUUID = characteristicUUID;
		this.type = type;
	}

	public BLECommand(UUID serviceUUID, UUID characteristicUUID, byte[] data, int type) {
		this.serviceUUID = serviceUUID;
		this.characteristicUUID = characteristicUUID;
		this.data = data;
		this.type = type;
	}

	public int getType() {
		return type;
	}

	public UUID getServiceUUID() {
		return serviceUUID;
	}

	public UUID getCharacteristicUUID() {
		return characteristicUUID;
	}

	public byte[] getData() {
		return data;
	}
}