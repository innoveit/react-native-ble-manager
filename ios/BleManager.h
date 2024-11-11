#import <CoreBluetooth/CoreBluetooth.h>
#import "React/RCTEventEmitter.h"

/**
This strategy assumes that all apps are new arch by default as described on docs of 0.76 release.
And enables old bridge just if user sets RCT_NEW_ARCH_ENABLED=0 on env.
*/

#ifdef RCT_NEW_ARCH_ENABLED

#import "RNBleManagerSpec.h"
@interface BleManager: NSObject <NativeBleManagerSpec>
@end

#else

#import <React/RCTBridgeModule.h>
@interface BleManager: NSObject <RCTBridgeModule>
@end

#endif

