#import "React/RCTBridgeModule.h"
#import "React/RCTEventEmitter.h"
#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN

@interface BleManager : RCTEventEmitter <RCTBridgeModule, CBCentralManagerDelegate>

+ (nullable CBCentralManager *)getCentralManager;
+ (nullable BleManager *)getInstance;

@end

NS_ASSUME_NONNULL_END