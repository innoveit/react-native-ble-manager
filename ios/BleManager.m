#import <Foundation/Foundation.h>
#import "React/RCTBridgeModule.h"
#import "React/RCTEventDispatcher.h"

@interface RCT_EXTERN_MODULE(BleManager, NSObject)

RCT_EXTERN_METHOD(start:
                  (NSDictionary *)options
                  callback:(RCTResponseSenderBlock) callback)

RCT_EXTERN_METHOD(scan:
                  (NSArray *)serviceUUIDStrings
                  timeoutSeconds:(nonnull NSNumber *)timeoutSeconds
                  allowDuplicates:(BOOL)allowDuplicates
                  scanningOptions:(nonnull NSDictionary*)scanningOptions
                  callback:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(stopScan:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(connect:
                  (NSString *)peripheralUUID
                  options:(NSDictionary *)options
                  callback:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(disconnect:
                  (NSString *)peripheralUUID 
                  force:(BOOL)force
                  callback:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(retrieveServices:
                  (NSString *)peripheralUUID
                  services:(NSArray<NSString *> *)services
                  callback:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(readRSSI:
                  (NSString *)peripheralUUID
                  callback:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(readDescriptor:
                  (NSString *)peripheralUUID
                  serviceUUID:(NSString*)serviceUUID
                  characteristicUUID:(NSString*)characteristicUUID
                  descriptorUUID:(NSString*)descriptorUUID
                  callback:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(writeDescriptor:
                  (NSString *)peripheralUUID
                  serviceUUID:(NSString*)serviceUUID
                  characteristicUUID:(NSString*)characteristicUUID
                  descriptorUUID:(NSString*)descriptorUUID
                  message:(NSArray*)message
                  callback:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(getDiscoveredPeripherals:
                  (nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(checkState:
                  (nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(write:
                  (NSString *)peripheralUUID
                  serviceUUID:(NSString*)serviceUUID
                  characteristicUUID:(NSString*)characteristicUUID
                  message:(NSArray*)message
                  maxByteSize:(NSInteger)maxByteSize
                  callback:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(writeWithoutResponse:
                  (NSString *)peripheralUUID
                  serviceUUID:(NSString*)serviceUUID
                  characteristicUUID:(NSString*)characteristicUUID
                  message:(NSArray*)message
                  maxByteSize:(NSInteger)maxByteSize
                  queueSleepTime:(NSInteger)queueSleepTime
                  callback:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(read:(NSString *)peripheralUUID
                  serviceUUID:(NSString*)serviceUUID
                  characteristicUUID:(NSString*)characteristicUUID
                  callback:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(startNotification:
                  (NSString *)peripheralUUID
                  serviceUUID:(NSString*)serviceUUID
                  characteristicUUID:(NSString*)characteristicUUID
                  callback:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(stopNotification:
                  (NSString *)peripheralUUID
                  serviceUUID:(NSString*)serviceUUID
                  characteristicUUID:(NSString*)characteristicUUID
                  callback:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(getConnectedPeripherals:(NSArray *)serviceUUIDStrings
                  callback:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(isPeripheralConnected:
                  (NSString *)peripheralUUID
                  callback:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(isScanning:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(getMaximumWriteValueLengthForWithoutResponse:
                  (NSString *)peripheralUUID
                  callback:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(getMaximumWriteValueLengthForWithResponse:
                  (NSString *)deviceUUID
                  callback:(nonnull RCTResponseSenderBlock)callback)

// Not supported
                  

RCT_EXTERN_METHOD(enableBluetooth:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(getBondedPeripherals:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(createBond:(NSString *)peripheralUUID
                  devicePin:(NSString *)devicePin
                  callback:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(removeBond:(NSString *)peripheralUUID
                  callback:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(removePeripheral:(NSString *)peripheralUUID
                  callback:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(requestMTU:(NSString *)peripheralUUID
                  mtu:(NSInteger)mtu
                  callback:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(requestConnectionPriority:(NSString *)peripheralUUID
                  connectionPriority:(NSInteger)connectionPriority
                  callback:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(refreshCache:(NSString *)peripheralUUID
                  callback:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(setName:(NSString *)name
                  callback:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(getAssociatedPeripherals:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(removeAssociatedPeripheral:(NSString *)peripheralUUID
                  callback:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(supportsCompanion:(nonnull RCTResponseSenderBlock)callback)

RCT_EXTERN_METHOD(companionScan:
                  (NSArray *)serviceUUIDs
                  callback:(nonnull RCTResponseSenderBlock)callback)

@end
