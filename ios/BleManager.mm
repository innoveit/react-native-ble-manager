#import <BleManager.h>
#if __has_include("RNBleManager-Swift.h")
#import <RNBleManager-Swift.h>
#else
#import <RNBleManager/RNBleManager-Swift.h>
#endif

@implementation SpecChecker

+ (BOOL)isSpecAvailable {
#ifdef RCT_NEW_ARCH_ENABLED
    return YES;
#else
    return NO;
#endif
}

@end

@implementation BleManager {
    SwiftBleManager *_swBleManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _swBleManager = [[SwiftBleManager alloc] initWithBleManager:self];
    }
    return self;
}

- (SwiftBleManager *)swiftManager {
    return _swBleManager;
}

RCT_EXPORT_MODULE()

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params {
    return std::make_shared<facebook::react::NativeBleManagerSpecJSI>(params);
}

- (void)checkState:(RCTResponseSenderBlock)callback {
    [_swBleManager checkState:callback];
}

- (void)companionScan:(NSArray *)serviceUUIDs
               option:(NSDictionary *)option
             callback:(RCTResponseSenderBlock)callback {
    [_swBleManager companionScan:serviceUUIDs option:option callback:callback];
}

- (void)connect:(NSString *)peripheralUUID
        options:(NSDictionary *)options
       callback:(RCTResponseSenderBlock)callback {
    [_swBleManager connect:peripheralUUID options:options callback:callback];
}

- (void)createBond:(NSString *)peripheralUUID
         devicePin:(NSString *)devicePin
          callback:(RCTResponseSenderBlock)callback {
    [_swBleManager createBond:peripheralUUID
                    devicePin:devicePin
                     callback:callback];
}

- (void)disconnect:(NSString *)peripheralUUID
             force:(BOOL)force
          callback:(RCTResponseSenderBlock)callback {
    [_swBleManager disconnect:peripheralUUID force:force callback:callback];
}

- (void)enableBluetooth:(RCTResponseSenderBlock)callback {
    [_swBleManager enableBluetooth:callback];
}

- (void)getAssociatedPeripherals:(RCTResponseSenderBlock)callback {
    [_swBleManager getAssociatedPeripherals:callback];
}

- (void)getBondedPeripherals:(RCTResponseSenderBlock)callback {
    [_swBleManager getBondedPeripherals:callback];
}

- (void)getConnectedPeripherals:(NSArray *)serviceUUIDStrings
                       callback:(RCTResponseSenderBlock)callback {
    [_swBleManager getConnectedPeripherals:serviceUUIDStrings
                                  callback:callback];
}

- (void)getDiscoveredPeripherals:(RCTResponseSenderBlock)callback {
    [_swBleManager getDiscoveredPeripherals:callback];
}

- (void)getMaximumWriteValueLengthForWithResponse:(NSString *)deviceUUID
                                         callback:
                                             (RCTResponseSenderBlock)callback {
    [_swBleManager getMaximumWriteValueLengthForWithResponse:deviceUUID
                                                    callback:callback];
}

- (void)getMaximumWriteValueLengthForWithoutResponse:(NSString *)peripheralUUID
                                            callback:(RCTResponseSenderBlock)
                                                         callback {
    [_swBleManager getMaximumWriteValueLengthForWithoutResponse:peripheralUUID
                                                       callback:callback];
}

- (void)isPeripheralConnected:(NSString *)peripheralUUID
                     callback:(RCTResponseSenderBlock)callback {
    [_swBleManager isPeripheralConnected:peripheralUUID callback:callback];
}

- (void)isScanning:(RCTResponseSenderBlock)callback {
    [_swBleManager isScanning:callback];
}

- (void)read:(NSString *)peripheralUUID
           serviceUUID:(NSString *)serviceUUID
    characteristicUUID:(NSString *)characteristicUUID
              callback:(RCTResponseSenderBlock)callback {
    [_swBleManager read:peripheralUUID
               serviceUUID:serviceUUID
        characteristicUUID:characteristicUUID
                  callback:callback];
}

- (void)readDescriptor:(NSString *)peripheralUUID
           serviceUUID:(NSString *)serviceUUID
    characteristicUUID:(NSString *)characteristicUUID
        descriptorUUID:(NSString *)descriptorUUID
              callback:(RCTResponseSenderBlock)callback {
    [_swBleManager readDescriptor:peripheralUUID
                      serviceUUID:serviceUUID
               characteristicUUID:characteristicUUID
                   descriptorUUID:descriptorUUID
                         callback:callback];
}

- (void)readRSSI:(NSString *)peripheralUUID
        callback:(RCTResponseSenderBlock)callback {
    [_swBleManager readRSSI:peripheralUUID callback:callback];
}

- (void)refreshCache:(NSString *)peripheralUUID
            callback:(RCTResponseSenderBlock)callback {
    [_swBleManager refreshCache:peripheralUUID callback:callback];
}

- (void)removeAssociatedPeripheral:(NSString *)peripheralUUID
                          callback:(RCTResponseSenderBlock)callback {
    [_swBleManager removeAssociatedPeripheral:peripheralUUID callback:callback];
}

- (void)removeBond:(NSString *)peripheralUUID
          callback:(RCTResponseSenderBlock)callback {
    [_swBleManager removeBond:peripheralUUID callback:callback];
}

- (void)removePeripheral:(NSString *)peripheralUUID
                callback:(RCTResponseSenderBlock)callback {
    [_swBleManager removePeripheral:peripheralUUID callback:callback];
}

- (void)requestConnectionPriority:(NSString *)peripheralUUID
               connectionPriority:(double)connectionPriority
                         callback:(RCTResponseSenderBlock)callback {
    [_swBleManager requestConnectionPriority:peripheralUUID
                          connectionPriority:connectionPriority
                                    callback:callback];
}

- (void)requestMTU:(NSString *)peripheralUUID
               mtu:(double)mtu
          callback:(RCTResponseSenderBlock)callback {
    [_swBleManager requestMTU:peripheralUUID mtu:mtu callback:callback];
}

- (void)retrieveServices:(NSString *)peripheralUUID
                services:(NSArray *)services
                callback:(RCTResponseSenderBlock)callback {
    [_swBleManager retrieveServices:peripheralUUID
                           services:services
                           callback:callback];
}

- (void)scan:(NSDictionary *)scanningOptions
    callback:(RCTResponseSenderBlock)callback {
    [_swBleManager scan:scanningOptions callback:callback];
}

- (void)setName:(NSString *)name {
    [_swBleManager setName:name];
}

- (void)start:(NSDictionary *)options
     callback:(RCTResponseSenderBlock)callback {
    [_swBleManager start:options callback:callback];
}

- (void)isStarted:(RCTResponseSenderBlock)callback {
    [_swBleManager isStarted:callback];
}

- (void)startNotificationWithBuffer:(NSString *)peripheralUUID
                        serviceUUID:(NSString *)serviceUUID
                 characteristicUUID:(NSString *)characteristicUUID
                       bufferLength:(double)bufferLength
                           callback:(RCTResponseSenderBlock)callback {
    [_swBleManager startNotificationWithBuffer:peripheralUUID
                                   serviceUUID:serviceUUID
                            characteristicUUID:characteristicUUID
                                  bufferLength:@(bufferLength)
                                      callback:callback];
}

- (void)startNotification:(NSString *)peripheralUUID
              serviceUUID:(NSString *)serviceUUID
       characteristicUUID:(NSString *)characteristicUUID
                 callback:(RCTResponseSenderBlock)callback {
    [_swBleManager startNotification:peripheralUUID
                         serviceUUID:serviceUUID
                  characteristicUUID:characteristicUUID
                            callback:callback];
}

- (void)stopNotification:(NSString *)peripheralUUID
             serviceUUID:(NSString *)serviceUUID
      characteristicUUID:(NSString *)characteristicUUID
                callback:(RCTResponseSenderBlock)callback {
    [_swBleManager stopNotification:peripheralUUID
                        serviceUUID:serviceUUID
                 characteristicUUID:characteristicUUID
                           callback:callback];
}

- (void)stopScan:(RCTResponseSenderBlock)callback {
    [_swBleManager stopScan:callback];
}

- (void)supportsCompanion:(RCTResponseSenderBlock)callback {
    [_swBleManager supportsCompanion:callback];
}

- (void)write:(NSString *)peripheralUUID
           serviceUUID:(NSString *)serviceUUID
    characteristicUUID:(NSString *)characteristicUUID
               message:(NSArray *)message
           maxByteSize:(double)maxByteSize
              callback:(RCTResponseSenderBlock)callback {
    [_swBleManager write:peripheralUUID
               serviceUUID:serviceUUID
        characteristicUUID:characteristicUUID
                   message:message
               maxByteSize:maxByteSize
                  callback:callback];
}

- (void)writeDescriptor:(NSString *)peripheralUUID
            serviceUUID:(NSString *)serviceUUID
     characteristicUUID:(NSString *)characteristicUUID
         descriptorUUID:(NSString *)descriptorUUID
                   data:(NSArray *)data
               callback:(RCTResponseSenderBlock)callback {
    [_swBleManager writeDescriptor:peripheralUUID
                       serviceUUID:serviceUUID
                characteristicUUID:characteristicUUID
                    descriptorUUID:descriptorUUID
                           message:data
                          callback:callback];
}

- (void)writeWithoutResponse:(NSString *)peripheralUUID
                 serviceUUID:(NSString *)serviceUUID
          characteristicUUID:(NSString *)characteristicUUID
                     message:(NSArray *)message
                 maxByteSize:(double)maxByteSize
              queueSleepTime:(double)queueSleepTime
                    callback:(RCTResponseSenderBlock)callback {
    [_swBleManager writeWithoutResponse:peripheralUUID
                            serviceUUID:serviceUUID
                     characteristicUUID:characteristicUUID
                                message:message
                            maxByteSize:maxByteSize
                         queueSleepTime:queueSleepTime
                               callback:callback];
}

+ (nullable CBCentralManager *)getCentralManager {
    return [SwiftBleManager getCentralManager];
}

+ (nullable SwiftBleManager *)getInstance {
    return [SwiftBleManager getInstance];
}

@end
