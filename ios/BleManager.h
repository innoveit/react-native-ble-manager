#import "React/RCTBridgeModule.h"
#import "React/RCTEventEmitter.h"
#import <CoreBluetooth/CoreBluetooth.h>


@interface BleManager : RCTEventEmitter <RCTBridgeModule, CBCentralManagerDelegate, CBPeripheralDelegate>{
    NSString* discoverPeripherialCallbackId;
    NSMutableDictionary* connectCallbacks;
    NSMutableDictionary *readCallbacks;
    NSMutableDictionary *writeCallbacks;
    NSMutableDictionary *readRSSICallbacks;
    NSMutableDictionary *retrieveServicesCallbacks;
    NSMutableArray *writeQueue;
    NSMutableDictionary *notificationCallbacks;
    NSMutableDictionary *stopNotificationCallbacks;
    NSMutableDictionary *retrieveServicesLatches;
}

@property (strong, nonatomic) NSMutableSet *peripherals;
@property (strong, nonatomic) CBCentralManager *manager;
@property (weak, nonatomic) NSTimer *scanTimer;


@end
