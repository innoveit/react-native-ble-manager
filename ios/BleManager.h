#import "React/RCTBridgeModule.h"
#import "React/RCTEventEmitter.h"
#import <CoreBluetooth/CoreBluetooth.h>

#ifdef RCT_NEW_ARCH_ENABLED
#import "RNBleManagerSpec.h"
#endif

#ifdef RCT_NEW_ARCH_ENABLED

@interface RCT_EXTERN_MODULE(BleManager, NSObject)
NS_ASSUME_NONNULL_BEGIN
@interface BleManager() <RNBleManagerSpec.h>
NS_ASSUME_NONNULL_END

@end
#endif

