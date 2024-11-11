import BleManager from 'react-native-ble-manager';
import {useCallback} from 'react';

let isReady = false;
BleManager.start({showAlert: false})
  .then(() => {
    console.log('Module initialized');
    isReady = true;
  })
  .catch(console.error);

export function useStartScan() {
  return useCallback(function () {
    BleManager.scan([], 60, false);
  }, []);
}
