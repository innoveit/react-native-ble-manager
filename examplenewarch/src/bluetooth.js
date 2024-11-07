import BleManager from 'react-native-ble-manager'

BleManager.start({ showAlert: false })
    .then(() => {
        console.log("Module initialized");
    }).catch(console.error);
