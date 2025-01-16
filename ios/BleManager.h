#import <CoreBluetooth/CoreBluetooth.h>
#import <Foundation/Foundation.h>

#ifdef RCT_NEW_ARCH_ENABLED

#import <BleManagerSpec/BleManagerSpec.h>
@class SwiftBleManager;

@interface BleManager : NativeBleManagerSpecBase <NativeBleManagerSpec>
- (void)emitOnDiscoverPeripheral:(NSDictionary *)value;
- (void)emitOnStopScan:(NSDictionary *)value;
- (void)emitOnDidUpdateState:(NSDictionary *)value;
- (void)emitOnDidUpdateValueForCharacteristic:(NSDictionary *)value;
- (void)emitOnConnectPeripheral:(NSDictionary *)value;
- (void)emitOnDisconnectPeripheral:(NSDictionary *)value;
- (void)emitOnPeripheralDidBond:(NSDictionary *)value;
- (void)emitOnCentralManagerWillRestoreState:(NSDictionary *)value;
- (void)emitOnDidUpdateNotificationStateFor:(NSDictionary *)value;
- (void)emitOnCompanionPeripheral:(NSDictionary *)value;
- (void)emitOnCompanionFailure:(NSDictionary *)value;
+ (nullable CBCentralManager *)getCentralManager;
+ (nullable SwiftBleManager *)getInstance;
@end

#else

@interface BleManager : NSObject
- (void)emitOnDiscoverPeripheral:(NSDictionary *)value;
- (void)emitOnStopScan:(NSDictionary *)value;
- (void)emitOnDidUpdateState:(NSDictionary *)value;
- (void)emitOnDidUpdateValueForCharacteristic:(NSDictionary *)value;
- (void)emitOnConnectPeripheral:(NSDictionary *)value;
- (void)emitOnDisconnectPeripheral:(NSDictionary *)value;
- (void)emitOnPeripheralDidBond:(NSDictionary *)value;
- (void)emitOnCentralManagerWillRestoreState:(NSDictionary *)value;
- (void)emitOnDidUpdateNotificationStateFor:(NSDictionary *)value;
- (void)emitOnCompanionPeripheral:(NSDictionary *)value;
- (void)emitOnCompanionFailure:(NSDictionary *)value;
@end

#endif

@interface SpecChecker : NSObject
+ (BOOL)isSpecAvailable;
@end
