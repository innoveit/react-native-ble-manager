#import "RCTBridgeModule.h"
#import "RCTEventEmitter.h"
#import <CoreBluetooth/CoreBluetooth.h>


@interface BleManager : NSObject <RCTBridgeModule, CBCentralManagerDelegate, CBPeripheralDelegate>{
    NSString* discoverPeripherialCallbackId;
    NSMutableDictionary* connectCallbacks;
    NSMutableDictionary *readCallbacks;
    NSMutableDictionary *writeCallbacks;
    NSMutableArray *writeQueue;
    NSMutableDictionary *notificationCallbacks;
    NSMutableDictionary *stopNotificationCallbacks;
    NSMutableDictionary *connectCallbackLatches;
}

@property (strong, nonatomic) NSMutableSet *peripherals;
@property (strong, nonatomic) CBCentralManager *manager;


@end
