/**
 * Sample BLE React Native App
 */

import { useNavigation } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import React, { useState, useEffect } from 'react';
import {
  StyleSheet,
  View,
  Text,
  StatusBar,
  Platform,
  PermissionsAndroid,
  FlatList,
  TouchableHighlight,
  Pressable,
} from 'react-native';
import BleManager, {
  BleDisconnectPeripheralEvent,
  BleManagerDidUpdateValueForCharacteristicEvent,
  BleScanCallbackType,
  BleScanMatchMode,
  BleScanMode,
  Peripheral,
  PeripheralInfo,
} from 'react-native-ble-manager';
import { SafeAreaView } from 'react-native-safe-area-context';

import { RootStackParamList } from '../types/navigation';

const SECONDS_TO_SCAN_FOR = 3;
const SERVICE_UUIDS: string[] = [];
const ALLOW_DUPLICATES = true;

declare module 'react-native-ble-manager' {
  // enrich local contract with custom state properties needed by App.tsx
  interface Peripheral {
    connected?: boolean;
    connecting?: boolean;
  }
}

const ScanDevicesScreen = () => {
  const navigation =
    useNavigation<
      NativeStackNavigationProp<RootStackParamList, 'ScanDevices'>
    >();

  const [isScanning, setIsScanning] = useState(false);
  const [peripherals, setPeripherals] = useState(
    new Map<Peripheral['id'], Peripheral>()
  );

  //console.debug('peripherals map updated', [...peripherals.entries()]);

  const startScan = () => {
    if (!isScanning) {
      // reset found peripherals before scan
      setPeripherals(new Map<Peripheral['id'], Peripheral>());

      try {
        console.debug('[startScan] starting scan...');
        setIsScanning(true);
        BleManager.scan({
          serviceUUIDs: SERVICE_UUIDS,
          seconds: SECONDS_TO_SCAN_FOR,
          allowDuplicates: ALLOW_DUPLICATES,
          matchMode: BleScanMatchMode.Sticky,
          scanMode: BleScanMode.LowLatency,
          callbackType: BleScanCallbackType.AllMatches,
        })
          .then(() => {
            console.debug('[startScan] scan promise returned successfully.');
          })
          .catch((err: any) => {
            console.error('[startScan] ble scan returned in error', err);
          });
      } catch (error) {
        console.error('[startScan] ble scan error thrown', error);
      }
    }
  };

  const startCompanionScan = () => {
    setPeripherals(new Map<Peripheral['id'], Peripheral>());
    try {
      console.debug('[startCompanionScan] starting companion scan...');
      BleManager.companionScan(SERVICE_UUIDS, { single: false })
        .then((peripheral: Peripheral | null) => {
          console.debug(
            '[startCompanionScan] scan promise returned successfully.',
            peripheral
          );
          if (peripheral != null) {
            setPeripherals((map) => {
              return new Map(map.set(peripheral.id, peripheral));
            });
          }
        })
        .catch((err: any) => {
          console.debug('[startCompanionScan] ble scan cancel', err);
        });
    } catch (error) {
      console.error('[startCompanionScan] ble scan error thrown', error);
    }
  };

  const enableBluetooth = async () => {
    try {
      console.debug('[enableBluetooth]');
      await BleManager.enableBluetooth();
    } catch (error) {
      console.error('[enableBluetooth] thrown', error);
    }
  };

  const handleStopScan = () => {
    setIsScanning(false);
    console.debug('[handleStopScan] scan is stopped.');
  };

  const handleDisconnectedPeripheral = (
    event: BleDisconnectPeripheralEvent
  ) => {
    console.debug(
      `[handleDisconnectedPeripheral][${event.peripheral}] disconnected.`
    );
    setPeripherals((map) => {
      const p = map.get(event.peripheral);
      if (p) {
        p.connected = false;
        return new Map(map.set(event.peripheral, p));
      }
      return map;
    });
  };

  const handleConnectPeripheral = (event: any) => {
    console.log(`[handleConnectPeripheral][${event.peripheral}] connected.`);
  };

  const handleUpdateValueForCharacteristic = (
    data: BleManagerDidUpdateValueForCharacteristicEvent
  ) => {
    console.debug(
      `[handleUpdateValueForCharacteristic] received data from '${data.peripheral}' with characteristic='${data.characteristic}' and value='${data.value}'`
    );
  };

  const handleDiscoverPeripheral = (peripheral: Peripheral) => {
    console.debug('[handleDiscoverPeripheral] new BLE peripheral=', peripheral);
    if (!peripheral.name) {
      peripheral.name = 'NO NAME';
    }
    setPeripherals((map) => {
      return new Map(map.set(peripheral.id, peripheral));
    });
  };

  const togglePeripheralConnection = async (peripheral: Peripheral) => {
    if (peripheral && peripheral.connected) {
      try {
        console.log('Disconnect peripheral');
        await BleManager.disconnect(peripheral.id);
      } catch (error) {
        console.error(
          `[togglePeripheralConnection][${peripheral.id}] error when trying to disconnect device.`,
          error
        );
      }
    } else {
      await connectPeripheral(peripheral);
    }
  };

  const retrieveConnected = async () => {
    try {
      const connectedPeripherals = await BleManager.getConnectedPeripherals();
      if (connectedPeripherals.length === 0) {
        console.warn('[retrieveConnected] No connected peripherals found.');
        return;
      }

      console.debug(
        '[retrieveConnected]',
        connectedPeripherals.length,
        'connectedPeripherals',
        connectedPeripherals
      );

      for (const peripheral of connectedPeripherals) {
        setPeripherals((map) => {
          const p = map.get(peripheral.id);
          if (p) {
            p.connected = true;
            return new Map(map.set(p.id, p));
          }
          return map;
        });
      }
    } catch (error) {
      console.error(
        '[retrieveConnected] unable to retrieve connected peripherals.',
        error
      );
    }
  };

  const retrieveServices = async () => {
    const peripheralInfos: PeripheralInfo[] = [];
    for (const [peripheralId, peripheral] of peripherals) {
      if (peripheral.connected) {
        const newPeripheralInfo =
          await BleManager.retrieveServices(peripheralId);
        peripheralInfos.push(newPeripheralInfo);
      }
    }
    return peripheralInfos;
  };

  const readCharacteristics = async () => {
    const services = await retrieveServices();

    for (const peripheralInfo of services) {
      peripheralInfo.characteristics?.forEach(async (c) => {
        try {
          const value = await BleManager.read(
            peripheralInfo.id,
            c.service,
            c.characteristic
          );
          console.log(
            '[readCharacteristics]',
            'peripheralId',
            peripheralInfo.id,
            'service',
            c.service,
            'char',
            c.characteristic,
            '\n\tvalue',
            value
          );
        } catch (error) {
          console.error(
            '[readCharacteristics]',
            'Error reading characteristic',
            error
          );
        }
      });
    }
  };

  const getAssociatedPeripherals = async () => {
    try {
      const associatedPeripherals = await BleManager.getAssociatedPeripherals();
      console.debug(
        '[getAssociatedPeripherals] associatedPeripherals',
        associatedPeripherals
      );

      for (const peripheral of associatedPeripherals) {
        setPeripherals((map) => {
          return new Map(map.set(peripheral.id, peripheral));
        });
      }
    } catch (error) {
      console.error(
        '[getAssociatedPeripherals] unable to retrieve associated peripherals.',
        error
      );
    }
  };

  const connectPeripheral = async (peripheral: Peripheral) => {
    try {
      if (peripheral) {
        setPeripherals((map) => {
          const p = map.get(peripheral.id);
          if (p) {
            p.connecting = true;
            return new Map(map.set(p.id, p));
          }
          return map;
        });

        await BleManager.connect(peripheral.id);
        console.debug(`[connectPeripheral][${peripheral.id}] connected.`);

        setPeripherals((map) => {
          const p = map.get(peripheral.id);
          if (p) {
            p.connecting = false;
            p.connected = true;
            return new Map(map.set(p.id, p));
          }
          return map;
        });

        // before retrieving services, it is often a good idea to let bonding & connection finish properly
        await sleep(900);

        /* Test read current RSSI value, retrieve services first */
        const peripheralData = await BleManager.retrieveServices(peripheral.id);
        console.debug(
          `[connectPeripheral][${peripheral.id}] retrieved peripheral services`,
          peripheralData
        );

        setPeripherals((map) => {
          const p = map.get(peripheral.id);
          if (p) {
            return new Map(map.set(p.id, p));
          }
          return map;
        });

        const rssi = await BleManager.readRSSI(peripheral.id);
        console.debug(
          `[connectPeripheral][${peripheral.id}] retrieved current RSSI value: ${rssi}.`
        );

        if (peripheralData.characteristics) {
          for (const characteristic of peripheralData.characteristics) {
            if (characteristic.descriptors) {
              for (const descriptor of characteristic.descriptors) {
                try {
                  const data = await BleManager.readDescriptor(
                    peripheral.id,
                    characteristic.service,
                    characteristic.characteristic,
                    descriptor.uuid
                  );
                  console.debug(
                    `[connectPeripheral][${peripheral.id}] ${characteristic.service} ${characteristic.characteristic} ${descriptor.uuid} descriptor read as:`,
                    data
                  );
                } catch (error) {
                  console.error(
                    `[connectPeripheral][${peripheral.id}] failed to retrieve descriptor ${descriptor} for characteristic ${characteristic}:`,
                    error
                  );
                }
              }
            }
          }
        }

        setPeripherals((map) => {
          const p = map.get(peripheral.id);
          if (p) {
            p.rssi = rssi;
            return new Map(map.set(p.id, p));
          }
          return map;
        });

        navigation.navigate('PeripheralDetails', {
          peripheralData,
        });
      }
    } catch (error) {
      console.error(
        `[connectPeripheral][${peripheral.id}] connectPeripheral error`,
        error
      );
    }
  };

  const checkIsStarted = async () => {
    try {
      const isStarted = await BleManager.isStarted();
      console.debug('[checkIsStarted] isStarted:', isStarted);
    } catch (error) {
      console.error('[checkIsStarted] error checking isStarted:', error);
    }
  };

  function sleep(ms: number) {
    return new Promise<void>((resolve) => setTimeout(resolve, ms));
  }

  useEffect(() => {
    try {
      BleManager.start({ showAlert: false })
        .then(() => console.debug('BleManager started.'))
        .catch((error: any) =>
          console.error('BeManager could not be started.', error)
        );
    } catch (error) {
      console.error('unexpected error starting BleManager.', error);
      return;
    }

    const listeners: any[] = [
      BleManager.onDiscoverPeripheral(handleDiscoverPeripheral),
      BleManager.onStopScan(handleStopScan),
      BleManager.onConnectPeripheral(handleConnectPeripheral),
      BleManager.onDidUpdateValueForCharacteristic(
        handleUpdateValueForCharacteristic
      ),
      BleManager.onDisconnectPeripheral(handleDisconnectedPeripheral),
    ];

    handleAndroidPermissions();

    return () => {
      console.debug('[app] main component unmounting. Removing listeners...');
      for (const listener of listeners) {
        listener.remove();
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleAndroidPermissions = () => {
    if (Platform.OS === 'android' && Platform.Version >= 31) {
      PermissionsAndroid.requestMultiple([
        PermissionsAndroid.PERMISSIONS.BLUETOOTH_SCAN,
        PermissionsAndroid.PERMISSIONS.BLUETOOTH_CONNECT,
      ]).then((result) => {
        if (result) {
          console.debug(
            '[handleAndroidPermissions] User accepts runtime permissions android 12+'
          );
        } else {
          console.error(
            '[handleAndroidPermissions] User refuses runtime permissions android 12+'
          );
        }
      });
    } else if (Platform.OS === 'android' && Platform.Version >= 23) {
      PermissionsAndroid.check(
        PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION
      ).then((checkResult) => {
        if (checkResult) {
          console.debug(
            '[handleAndroidPermissions] runtime permission Android <12 already OK'
          );
        } else {
          PermissionsAndroid.request(
            PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION
          ).then((requestResult) => {
            if (requestResult) {
              console.debug(
                '[handleAndroidPermissions] User accepts runtime permission android <12'
              );
            } else {
              console.error(
                '[handleAndroidPermissions] User refuses runtime permission android <12'
              );
            }
          });
        }
      });
    }
  };

  const renderItem = ({ item }: { item: Peripheral }) => {
    const backgroundColor = item.connected ? '#069400' : 'white';
    return (
      <TouchableHighlight
        underlayColor="#0082FC"
        onPress={() => togglePeripheralConnection(item)}
      >
        <View style={[styles.row, { backgroundColor }]}>
          <Text style={styles.peripheralName}>
            {/* completeLocalName (item.name) & shortAdvertisingName (advertising.localName) may not always be the same */}
            {item.name} - {item?.advertising?.localName}
            {item.connecting && ' - Connecting...'}
          </Text>
          <Text style={styles.rssi}>RSSI: {item.rssi}</Text>
          <Text style={styles.peripheralId}>{item.id}</Text>
        </View>
      </TouchableHighlight>
    );
  };

  return (
    <>
      <StatusBar />
      <SafeAreaView style={styles.body}>
        <View style={styles.buttonGroup}>
          <Pressable style={styles.scanButton} onPress={startScan}>
            <Text style={styles.scanButtonText}>
              {isScanning ? 'Scanning...' : 'Scan Bluetooth'}
            </Text>
          </Pressable>

          <Pressable style={styles.scanButton} onPress={retrieveConnected}>
            <Text style={styles.scanButtonText} lineBreakMode="middle">
              Retrieve connected peripherals
            </Text>
          </Pressable>
        </View>

        <View style={styles.buttonGroup}>
          <Pressable style={styles.scanButton} onPress={readCharacteristics}>
            <Text style={styles.scanButtonText}>Read characteristics</Text>
          </Pressable>
          <Pressable style={styles.scanButton} onPress={checkIsStarted}>
            <Text style={styles.scanButtonText}>Check isStarted</Text>
          </Pressable>
        </View>

        {Platform.OS === 'android' && (
          <>
            <View style={styles.buttonGroup}>
              <Pressable style={styles.scanButton} onPress={startCompanionScan}>
                <Text style={styles.scanButtonText}>Scan Companion</Text>
              </Pressable>

              <Pressable
                style={styles.scanButton}
                onPress={getAssociatedPeripherals}
              >
                <Text style={styles.scanButtonText}>
                  Get Associated Peripherals
                </Text>
              </Pressable>
            </View>

            <View style={styles.buttonGroup}>
              <Pressable style={styles.scanButton} onPress={enableBluetooth}>
                <Text style={styles.scanButtonText}>Enable Bluetooth</Text>
              </Pressable>
            </View>
          </>
        )}

        {Array.from(peripherals.values()).length === 0 && (
          <View style={styles.row}>
            <Text style={styles.noPeripherals}>
              No Peripherals, press "Scan Bluetooth" above.
            </Text>
          </View>
        )}

        <FlatList
          data={Array.from(peripherals.values())}
          contentContainerStyle={{ rowGap: 12 }}
          renderItem={renderItem}
          keyExtractor={(item) => item.id}
        />
      </SafeAreaView>
    </>
  );
};

const boxShadow = {
  shadowColor: '#000',
  shadowOffset: {
    width: 0,
    height: 2,
  },
  shadowOpacity: 0.25,
  shadowRadius: 3.84,
  elevation: 5,
};

const styles = StyleSheet.create({
  engine: {
    position: 'absolute',
    right: 10,
    bottom: 0,
    color: 'black',
  },
  buttonGroup: {
    flexDirection: 'row',
    width: '100%',
  },
  scanButton: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 16,
    paddingHorizontal: 16,
    backgroundColor: '#0a398a',
    margin: 10,
    borderRadius: 12,
    flex: 1,
    ...boxShadow,
  },
  scanButtonText: {
    fontSize: 16,
    letterSpacing: 0.25,
    color: 'white',
  },
  body: {
    backgroundColor: '#0082FC',
    flex: 1,
  },
  sectionContainer: {
    marginTop: 32,
    paddingHorizontal: 24,
  },
  sectionTitle: {
    fontSize: 24,
    fontWeight: '600',
    color: 'black',
  },
  sectionDescription: {
    marginTop: 8,
    fontSize: 18,
    fontWeight: '400',
    color: 'dark',
  },
  highlight: {
    fontWeight: '700',
  },
  footer: {
    color: 'dark',
    fontSize: 12,
    fontWeight: '600',
    padding: 4,
    paddingRight: 12,
    textAlign: 'right',
  },
  peripheralName: {
    fontSize: 16,
    textAlign: 'center',
    padding: 10,
  },
  rssi: {
    fontSize: 12,
    textAlign: 'center',
    padding: 2,
  },
  peripheralId: {
    fontSize: 12,
    textAlign: 'center',
    padding: 2,
    paddingBottom: 20,
  },
  row: {
    marginLeft: 10,
    marginRight: 10,
    borderRadius: 20,
    ...boxShadow,
  },
  noPeripherals: {
    margin: 10,
    textAlign: 'center',
    color: 'white',
  },
});

export default ScanDevicesScreen;
