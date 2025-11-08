import { PeripheralInfo } from 'react-native-ble-manager';

export type RootStackParamList = {
  ScanDevices: undefined;
  PeripheralDetails: {
    peripheralData: PeripheralInfo;
  };
};
