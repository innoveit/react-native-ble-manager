// Keep the mirrored Swift API guarded by SwiftHeaderPin.swift to avoid a target cycle.
#pragma once
#import <CoreBluetooth/CoreBluetooth.h>
#import <React/RCTBridgeModule.h>

@class BleManager;
NS_ASSUME_NONNULL_BEGIN
__attribute__((objc_runtime_name("_TtC12RNBleManager15SwiftBleManager")))
@interface SwiftBleManager : NSObject
- (instancetype)initWithBleManager:(BleManager *)bleManager;
- (void)start:(NSDictionary *)options callback:(RCTResponseSenderBlock)callback;
- (void)isStarted:(RCTResponseSenderBlock)callback;
- (void)scan:(NSDictionary *)scanningOptions callback:(RCTResponseSenderBlock)callback;
- (void)stopScan:(RCTResponseSenderBlock)callback;
- (void)connect:(NSString *)peripheralUUID options:(NSDictionary *)options callback:(RCTResponseSenderBlock)callback;
- (void)disconnect:(NSString *)peripheralUUID force:(BOOL)force callback:(RCTResponseSenderBlock)callback;
- (void)retrieveServices:(NSString *)peripheralUUID services:(NSArray<NSString *> *)services callback:(RCTResponseSenderBlock)callback;
- (void)readRSSI:(NSString *)peripheralUUID callback:(RCTResponseSenderBlock)callback;
- (void)readDescriptor:(NSString *)peripheralUUID serviceUUID:(NSString *)serviceUUID characteristicUUID:(NSString *)characteristicUUID descriptorUUID:(NSString *)descriptorUUID callback:(RCTResponseSenderBlock)callback;
- (void)writeDescriptor:(NSString *)peripheralUUID serviceUUID:(NSString *)serviceUUID characteristicUUID:(NSString *)characteristicUUID descriptorUUID:(NSString *)descriptorUUID message:(NSArray<NSNumber *> *)message callback:(RCTResponseSenderBlock)callback;
- (void)getDiscoveredPeripherals:(RCTResponseSenderBlock)callback;
- (void)getConnectedPeripherals:(NSArray<NSString *> *)serviceUUIDStrings callback:(RCTResponseSenderBlock)callback;
- (void)isPeripheralConnected:(NSString *)peripheralUUID callback:(RCTResponseSenderBlock)callback;
- (void)isScanning:(RCTResponseSenderBlock)callback;
- (void)checkState:(RCTResponseSenderBlock)callback;
- (void)write:(NSString *)peripheralUUID serviceUUID:(NSString *)serviceUUID characteristicUUID:(NSString *)characteristicUUID message:(NSArray<NSNumber *> *)message maxByteSize:(NSInteger)maxByteSize callback:(RCTResponseSenderBlock)callback;
- (void)writeWithoutResponse:(NSString *)peripheralUUID serviceUUID:(NSString *)serviceUUID characteristicUUID:(NSString *)characteristicUUID message:(NSArray<NSNumber *> *)message maxByteSize:(NSInteger)maxByteSize queueSleepTime:(NSInteger)queueSleepTime callback:(RCTResponseSenderBlock)callback;
- (void)read:(NSString *)peripheralUUID serviceUUID:(NSString *)serviceUUID characteristicUUID:(NSString *)characteristicUUID callback:(RCTResponseSenderBlock)callback;
- (void)startNotificationWithBuffer:(NSString *)peripheralUUID serviceUUID:(NSString *)serviceUUID characteristicUUID:(NSString *)characteristicUUID bufferLength:(NSNumber *)bufferLength callback:(RCTResponseSenderBlock)callback;
- (void)startNotification:(NSString *)peripheralUUID serviceUUID:(NSString *)serviceUUID characteristicUUID:(NSString *)characteristicUUID callback:(RCTResponseSenderBlock)callback;
- (void)stopNotification:(NSString *)peripheralUUID serviceUUID:(NSString *)serviceUUID characteristicUUID:(NSString *)characteristicUUID callback:(RCTResponseSenderBlock)callback;
- (void)getMaximumWriteValueLengthForWithoutResponse:(NSString *)peripheralUUID callback:(RCTResponseSenderBlock)callback;
- (void)getMaximumWriteValueLengthForWithResponse:(NSString *)peripheralUUID callback:(RCTResponseSenderBlock)callback;
+ (CBCentralManager * _Nullable)getCentralManager;
+ (SwiftBleManager * _Nullable)getInstance;
- (void)enableBluetooth:(RCTResponseSenderBlock)callback;
- (void)getBondedPeripherals:(RCTResponseSenderBlock)callback;
- (void)createBond:(NSString *)peripheralUUID devicePin:(NSString *)devicePin callback:(RCTResponseSenderBlock)callback;
- (void)removeBond:(NSString *)peripheralUUID callback:(RCTResponseSenderBlock)callback;
- (void)removePeripheral:(NSString *)peripheralUUID callback:(RCTResponseSenderBlock)callback;
- (void)requestMTU:(NSString *)peripheralUUID mtu:(NSInteger)mtu callback:(RCTResponseSenderBlock)callback;
- (void)requestConnectionPriority:(NSString *)peripheralUUID connectionPriority:(NSInteger)connectionPriority callback:(RCTResponseSenderBlock)callback;
- (void)refreshCache:(NSString *)peripheralUUID callback:(RCTResponseSenderBlock)callback;
- (void)setName:(NSString *)name;
- (void)getAssociatedPeripherals:(RCTResponseSenderBlock)callback;
- (void)removeAssociatedPeripheral:(NSString *)peripheralUUID callback:(RCTResponseSenderBlock)callback;
- (void)supportsCompanion:(RCTResponseSenderBlock)callback;
- (void)companionScan:(NSArray *)serviceUUIDs option:(NSDictionary *)option callback:(RCTResponseSenderBlock)callback;
@end
NS_ASSUME_NONNULL_END
