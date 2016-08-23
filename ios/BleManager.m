#import "BleManager.h"
#import "RCTBridge.h"
#import "RCTConvert.h"
#import "RCTEventDispatcher.h"
#import "NSData+Conversion.h"
#import "CBPeripheral+Extensions.h"
#import "BLECommandContext.h"


@implementation BleManager


RCT_EXPORT_MODULE();

@synthesize bridge = _bridge;

@synthesize manager;
@synthesize peripherals;

- (instancetype)init
{
    
    if (self = [super init]) {
        NSLog(@"BleManager initialized");
        peripherals = [NSMutableSet set];
        manager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
        
        connectCallbacks = [NSMutableDictionary new];
        connectCallbackLatches = [NSMutableDictionary new];
        readCallbacks = [NSMutableDictionary new];
        writeCallbacks = [NSMutableDictionary new];
        writeErrorCallbacks = [NSMutableDictionary new];
        writeQueue = [NSMutableArray array];
        notificationCallbacks = [NSMutableDictionary new];
        stopNotificationCallbacks = [NSMutableDictionary new];
    }
    
    return self;
}


- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error %@ :%@", characteristic.UUID, error);
        return;
    }
    NSLog(@"Read value [%@]: %@", characteristic.UUID, characteristic.value);
    
    NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
    RCTResponseSenderBlock readCallback = [readCallbacks objectForKey:key];
    
    NSString *stringFromData = [characteristic.value hexadecimalString];
    
    if (readCallback != NULL){
        readCallback(@[stringFromData]);
        [readCallbacks removeObjectForKey:key];
    } else {
        [self.bridge.eventDispatcher sendAppEventWithName:@"BleManagerDidUpdateValueForCharacteristic" body:@{@"peripheral": peripheral.uuidAsString, @"characteristic":characteristic.UUID.UUIDString, @"value": stringFromData}];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error in didUpdateNotificationStateForCharacteristic: %@", error);                
        return;
    }
    
    // Call didUpdateValueForCharacteristic only when we have a value.
    /*
     if (characteristic.value)
     {
     NSLog(@"Received value from notification: %@", characteristic.value);
     }*/
    
    NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
    
    if (characteristic.isNotifying) {
        NSLog(@"Notification began on %@", characteristic.UUID);
        RCTResponseSenderBlock notificationCallback = [notificationCallbacks objectForKey:key];
        notificationCallback(@[]);
        [notificationCallbacks removeObjectForKey:key];
    } else {
        // Notification has stopped
        NSLog(@"Notification ended on %@", characteristic.UUID);
        RCTResponseSenderBlock stopNotificationCallback = [stopNotificationCallbacks objectForKey:key];
        stopNotificationCallback(@[]);
        [stopNotificationCallbacks removeObjectForKey:key];
    }
}




- (NSString *) centralManagerStateToString: (int)state
{
    switch (state) {
        case CBCentralManagerStateUnknown:
            return @"unknown";
        case CBCentralManagerStateResetting:
            return @"resetting";
        case CBCentralManagerStateUnsupported:
            return @"unsupported";
        case CBCentralManagerStateUnauthorized:
            return @"unauthorized";
        case CBCentralManagerStatePoweredOff:
            return @"off";
        case CBCentralManagerStatePoweredOn:
            return @"on";
        default:
            return @"unknown";
    }
    
    return @"unknown";
}

- (NSString *) periphalStateToString: (int)state
{
    switch (state) {
        case CBPeripheralStateDisconnected:
            return @"disconnected";
        case CBPeripheralStateDisconnecting:
            return @"disconnecting";
        case CBPeripheralStateConnected:
            return @"connected";
        case CBPeripheralStateConnecting:
            return @"connecting";
        default:
            return @"unknown";
    }
    
    return @"unknown";
}

- (NSString *) periphalManagerStateToString: (int)state
{
    switch (state) {
        case CBPeripheralManagerStateUnknown:
            return @"Unknown";
        case CBPeripheralManagerStatePoweredOn:
            return @"PoweredOn";
        case CBPeripheralManagerStatePoweredOff:
            return @"PoweredOff";
        default:
            return @"unknown";
    }
    
    return @"unknown";
}

- (CBPeripheral*)findPeripheralByUUID:(NSString*)uuid {
    
    CBPeripheral *peripheral = nil;
    
    for (CBPeripheral *p in peripherals) {
        
        NSString* other = p.identifier.UUIDString;
        
        if ([uuid isEqualToString:other]) {
            peripheral = p;
            break;
        }
    }
    return peripheral;
}

-(CBService *) findServiceFromUUID:(CBUUID *)UUID p:(CBPeripheral *)p
{
    for(int i = 0; i < p.services.count; i++)
    {
        CBService *s = [p.services objectAtIndex:i];
        if ([self compareCBUUID:s.UUID UUID2:UUID])
            return s;
    }
    
    return nil; //Service not found on this peripheral
}

-(int) compareCBUUID:(CBUUID *) UUID1 UUID2:(CBUUID *)UUID2
{
    char b1[16];
    char b2[16];
    [UUID1.data getBytes:b1 length:16];
    [UUID2.data getBytes:b2 length:16];
    
    if (memcmp(b1, b2, UUID1.data.length) == 0)
        return 1;
    else
        return 0;
}

RCT_EXPORT_METHOD(getDiscoveredPeripheralsPeripherals:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"Get discovered peripherals");
    NSMutableArray *discoveredPeripherals = [NSMutableArray array];
    for(CBPeripheral *peripheral in peripherals){
        NSDictionary * obj = [peripheral asDictionary];
        [discoveredPeripherals addObject:obj];
    }
    callback(@[[NSNull null], [NSArray arrayWithArray:discoveredPeripherals]]);
}

RCT_EXPORT_METHOD(getConnectedPeripherals:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"Get connected peripherals");
    NSMutableArray *connectedPeripherals = [NSMutableArray array];
    for(CBPeripheral *peripheral in peripherals){
        //those peripherals will be exclude from scan, include them here
        if([peripheral state] == CBPeripheralStateConnected || [peripheral state] == CBPeripheralStateConnecting){
            NSDictionary * obj = [peripheral asDictionary];
            [connectedPeripherals addObject:obj];
        }
    }
    callback(@[[NSNull null], [NSArray arrayWithArray:connectedPeripherals]]);
}

RCT_EXPORT_METHOD(scan:(NSArray *)serviceUUIDStrings timeoutSeconds:(nonnull NSNumber *)timeoutSeconds allowDuplicates:(BOOL)allowDuplicates callback:(nonnull RCTResponseSenderBlock)successCallback)
{
    NSLog(@"scan with timeout %@", timeoutSeconds);
    NSArray * services = [RCTConvert NSArray:serviceUUIDStrings];
    NSMutableArray *serviceUUIDs = [NSMutableArray new];
    NSDictionary *options = nil;
    if (allowDuplicates){
        options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBCentralManagerScanOptionAllowDuplicatesKey];
    }
    
    for (int i = 0; i < [services count]; i++) {
        CBUUID *serviceUUID =[CBUUID UUIDWithString:[serviceUUIDStrings objectAtIndex: i]];
        [serviceUUIDs addObject:serviceUUID];
    }
    [manager scanForPeripheralsWithServices:serviceUUIDs options:options];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSTimer scheduledTimerWithTimeInterval:[timeoutSeconds floatValue] target:self selector:@selector(stopScanTimer:) userInfo: nil repeats:NO];
    });
    successCallback(@[]);
}

RCT_EXPORT_METHOD(stopScan:(nonnull RCTResponseSenderBlock)callback)
{
    [manager stopScan];
    callback(@[[NSNull null]]);
}


-(void)stopScanTimer:(NSTimer *)timer {
    NSLog(@"Stop scan");
    [manager stopScan];
    [self.bridge.eventDispatcher sendAppEventWithName:@"BleManagerStopScan" body:@{}];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
    [peripherals addObject:peripheral];
    [peripheral setAdvertisementData:advertisementData RSSI:RSSI];
    
    NSLog(@"Discover peripheral: %@", [peripheral name]);
    [self.bridge.eventDispatcher sendAppEventWithName:@"BleManagerDiscoverPeripheral" body:[peripheral asDictionary]];
    
}

RCT_EXPORT_METHOD(connect:(NSString *)peripheralUUID  successCallback:(nonnull RCTResponseSenderBlock)successCallback failCallback:(nonnull RCTResponseSenderBlock)failCallback)
{
    NSLog(@"connect");
    CBPeripheral *peripheral = [self findPeripheralByUUID:peripheralUUID];
    if (peripheral) {
        NSLog(@"Connecting to peripheral with UUID : %@", peripheralUUID);
        
        [connectCallbacks setObject:successCallback forKey:[peripheral uuidAsString]];
        [manager connectPeripheral:peripheral options:nil];
        
    } else {
        NSString *error = [NSString stringWithFormat:@"Could not find peripheral %@.", peripheralUUID];
        NSLog(@"%@", error);
        failCallback(@[error]);
    }
}

RCT_EXPORT_METHOD(disconnect:(NSString *)peripheralUUID  successCallback:(nonnull RCTResponseSenderBlock)successCallback failCallback:(nonnull RCTResponseSenderBlock)failCallback)
{
    CBPeripheral *peripheral = [self findPeripheralByUUID:peripheralUUID];
    if (peripheral) {
        NSLog(@"Disconnecting from peripheral with UUID : %@", peripheralUUID);
        
        if (peripheral.services != nil) {
            for (CBService *service in peripheral.services) {
                if (service.characteristics != nil) {
                    for (CBCharacteristic *characteristic in service.characteristics) {
                        if (characteristic.isNotifying) {
                            NSLog(@"Remove notification from: %@", characteristic.UUID);
                            [peripheral setNotifyValue:NO forCharacteristic:characteristic];
                        }
                    }
                }
            }
        }
        
        [manager cancelPeripheralConnection:peripheral];
        successCallback(@[]);
        
    } else {
        NSString *error = [NSString stringWithFormat:@"Could not find peripheral %@.", peripheralUUID];
        NSLog(@"%@", error);
        failCallback(@[error]);
    }
}

RCT_EXPORT_METHOD(checkState)
{
    if (manager != nil){
        [self centralManagerDidUpdateState:self.manager];
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Peripheral connection failure: %@. (%@)", peripheral, [error localizedDescription]);
}

RCT_EXPORT_METHOD(write:(NSString *)deviceUUID serviceUUID:(NSString*)serviceUUID  characteristicUUID:(NSString*)characteristicUUID message:(NSString*)message  successCallback:(nonnull RCTResponseSenderBlock)successCallback failCallback:(nonnull RCTResponseSenderBlock)failCallback)
{
    NSLog(@"Write");
    
    BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyWrite failCallback:failCallback];
    
    NSData* dataMessage = [[NSData alloc] initWithBase64EncodedString:message options:0];
    if (context) {
        CBPeripheral *peripheral = [context peripheral];
        CBCharacteristic *characteristic = [context characteristic];
        
        NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
        [writeCallbacks setObject:successCallback forKey:key];
        
        RCTLogInfo(@"Message to write(%lu): %@ ", (unsigned long)[dataMessage length], [dataMessage hexadecimalString]);
        if ([dataMessage length] > 20){
            int dataLength = (int)dataMessage.length;
            int count = 0;
            NSData* firstMessage;
            while(count < dataLength && (dataLength - count > 20)){
                if (count == 0){
                    firstMessage = [dataMessage subdataWithRange:NSMakeRange(count, 20)];
                }else{
                    NSData* splitMessage = [dataMessage subdataWithRange:NSMakeRange(count, 20)];
                    [writeQueue addObject:splitMessage];
                }
                count += 20;
            }
            if (count < dataLength) {
                NSData* splitMessage = [dataMessage subdataWithRange:NSMakeRange(count, dataLength - count)];
                [writeQueue addObject:splitMessage];
            }
            NSLog(@"Queued splitted message: %lu", (unsigned long)[writeQueue count]);
            [peripheral writeValue:firstMessage forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
        } else {
            [peripheral writeValue:dataMessage forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
        }
    }else
        failCallback(@[@"Error"]);
}


RCT_EXPORT_METHOD(writeWithoutResponse:(NSString *)deviceUUID serviceUUID:(NSString*)serviceUUID  characteristicUUID:(NSString*)characteristicUUID message:(NSString*)message  successCallback:(nonnull RCTResponseSenderBlock)successCallback failCallback:(nonnull RCTResponseSenderBlock)failCallback)
{
    NSLog(@"writeWithoutResponse");
    
    BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyWriteWithoutResponse failCallback:failCallback];
    
    NSData* dataMessage = [[NSData alloc] initWithBase64EncodedString:message options:0];
    if (context && [dataMessage length] <= 20) {
        CBPeripheral *peripheral = [context peripheral];
        CBCharacteristic *characteristic = [context characteristic];
        
        NSLog(@"Message to write(%lu): %@ ", (unsigned long)[dataMessage length], [dataMessage hexadecimalString]);
        [peripheral writeValue:dataMessage forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
        successCallback(@[]);
    }else
        failCallback(@[@"Error"]);
}


RCT_EXPORT_METHOD(read:(NSString *)deviceUUID serviceUUID:(NSString*)serviceUUID  characteristicUUID:(NSString*)characteristicUUID successCallback:(nonnull RCTResponseSenderBlock)successCallback failCallback:(nonnull RCTResponseSenderBlock)failCallback)
{
    NSLog(@"read");
    
    BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyRead failCallback:failCallback];
    if (context) {
        
        CBPeripheral *peripheral = [context peripheral];
        CBCharacteristic *characteristic = [context characteristic];
        
        NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
        [readCallbacks setObject:successCallback forKey:key];
        
        [peripheral readValueForCharacteristic:characteristic];  // callback sends value
    }
    
}

RCT_EXPORT_METHOD(startNotification:(NSString *)deviceUUID serviceUUID:(NSString*)serviceUUID  characteristicUUID:(NSString*)characteristicUUID successCallback:(nonnull RCTResponseSenderBlock)successCallback failCallback:(nonnull RCTResponseSenderBlock)failCallback)
{
    NSLog(@"startNotification");
    
    BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyNotify failCallback:failCallback];
    
    if (context) {
        CBPeripheral *peripheral = [context peripheral];
        CBCharacteristic *characteristic = [context characteristic];
        
        NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
        [notificationCallbacks setObject: successCallback forKey: key];
        
        [peripheral setNotifyValue:YES forCharacteristic:characteristic];
    }
    
}

RCT_EXPORT_METHOD(stopNotification:(NSString *)deviceUUID serviceUUID:(NSString*)serviceUUID  characteristicUUID:(NSString*)characteristicUUID successCallback:(nonnull RCTResponseSenderBlock)successCallback failCallback:(nonnull RCTResponseSenderBlock)failCallback)
{
    NSLog(@"stopNotification");
    
    BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyNotify failCallback:failCallback];
    
    if (context) {
        CBPeripheral *peripheral = [context peripheral];
        CBCharacteristic *characteristic = [context characteristic];
        
        NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
        [stopNotificationCallbacks setObject: successCallback forKey: key];
        
        if ([characteristic isNotifying]){
            [peripheral setNotifyValue:NO forCharacteristic:characteristic];
            NSLog(@"Characteristic stopped notifying");
        } else {
            NSLog(@"Characteristic is not notifying");
        }
        
    }
    
}


- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSLog(@"didWrite");
    
    NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
    RCTResponseSenderBlock writeCallback = [writeCallbacks objectForKey:key];
    RCTResponseSenderBlock writeErrorCallback = [writeErrorCallbacks objectForKey:key];
    
    if (writeCallback) {
        if (error) {
            NSLog(@"%@", error);
            if(writeErrorCallback){
                writeErrorCallback(@[error.localizedDescription]);
            }
        } else {
            if ([writeQueue count] == 0) {
                writeCallback(@[@""]);
                [writeCallbacks removeObjectForKey:key];
            }else{
                // Rimuovo messaggio da coda e scrivo
                NSData *message = [writeQueue objectAtIndex:0];
                [writeQueue removeObjectAtIndex:0];
                //NSLog(@"Rimangono in coda: %i", [writeQueue count]);
                //NSLog(@"Scrivo messaggio (%lu): %@ ", (unsigned long)[message length], [message hexadecimalString]);
                [peripheral writeValue:message forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
            }
            
        }
    }
    
}


- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Peripheral Connected: %@", [peripheral uuidAsString]);
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Peripheral Disconnected: %@", [peripheral uuidAsString]);
    if (error) {
        NSLog(@"Error: %@", error);
    }
    [self.bridge.eventDispatcher sendAppEventWithName:@"BleManagerDisconnectPeripheral" body:@{@"peripheral": [peripheral uuidAsString]}];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        NSLog(@"Error: %@", error);
        return;
    }
    NSLog(@"Services Discover");
    
    NSMutableSet *servicesForPeriperal = [NSMutableSet new];
    [servicesForPeriperal addObjectsFromArray:peripheral.services];
    [connectCallbackLatches setObject:servicesForPeriperal forKey:[peripheral uuidAsString]];
    for (CBService *service in peripheral.services) {
        NSLog(@"Servizio %@ %@", service.UUID, service.description);
        [peripheral discoverCharacteristics:nil forService:service]; // discover all is slow
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        NSLog(@"Error: %@", error);
        return;
    }
    NSLog(@"Characteristics For Service Discover");
    
    NSString *peripheralUUIDString = [peripheral uuidAsString];
    RCTResponseSenderBlock connectCallback = [connectCallbacks valueForKey:peripheralUUIDString];
    NSMutableSet *latch = [connectCallbackLatches valueForKey:peripheralUUIDString];
    [latch removeObject:service];
    
    if ([latch count] == 0) {
        // Call success callback for connect
        if (connectCallback) {
            connectCallback(@[[peripheral asDictionary]]);
        }
        [connectCallbackLatches removeObjectForKey:peripheralUUIDString];
    }
    
    /*
     NSLog(@"Found characteristics for service %@", service);
     for (CBCharacteristic *characteristic in service.characteristics) {
     NSLog(@"Characteristic %@", characteristic);
     }*/
    
}

// Find a characteristic in service with a specific property
-(CBCharacteristic *) findCharacteristicFromUUID:(CBUUID *)UUID service:(CBService*)service prop:(CBCharacteristicProperties)prop
{
    NSLog(@"Looking for %@ with properties %lu", UUID, (unsigned long)prop);
    for(int i=0; i < service.characteristics.count; i++)
    {
        CBCharacteristic *c = [service.characteristics objectAtIndex:i];
        if ((c.properties & prop) != 0x0 && [c.UUID.UUIDString isEqualToString: UUID.UUIDString]) {
            NSLog(@"Found %@", UUID);
            return c;
        }
    }
    return nil; //Characteristic with prop not found on this service
}

// Find a characteristic in service by UUID
-(CBCharacteristic *) findCharacteristicFromUUID:(CBUUID *)UUID service:(CBService*)service
{
    NSLog(@"Looking for %@", UUID);
    for(int i=0; i < service.characteristics.count; i++)
    {
        CBCharacteristic *c = [service.characteristics objectAtIndex:i];
        if ([c.UUID.UUIDString isEqualToString: UUID.UUIDString]) {
            NSLog(@"Found %@", UUID);
            return c;
        }
    }
    return nil; //Characteristic not found on this service
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSString *stateName = [self centralManagerStateToString:central.state];
    [self.bridge.eventDispatcher sendAppEventWithName:@"BleManagerDidUpdateState" body:@{@"state":stateName}];
}

// expecting deviceUUID, serviceUUID, characteristicUUID in command.arguments
-(BLECommandContext*) getData:(NSString*)deviceUUIDString  serviceUUIDString:(NSString*)serviceUUIDString characteristicUUIDString:(NSString*)characteristicUUIDString prop:(CBCharacteristicProperties)prop failCallback:(nonnull RCTResponseSenderBlock)failCallback
{
    CBUUID *serviceUUID = [CBUUID UUIDWithString:serviceUUIDString];
    CBUUID *characteristicUUID = [CBUUID UUIDWithString:characteristicUUIDString];
    
    CBPeripheral *peripheral = [self findPeripheralByUUID:deviceUUIDString];
    
    if (!peripheral) {
        NSString* err = [NSString stringWithFormat:@"Could not find peripherial with UUID %@", deviceUUIDString];
        NSLog(@"Could not find peripherial with UUID %@", deviceUUIDString);
        failCallback(@[err]);
        
        return nil;
    }
    
    CBService *service = [self findServiceFromUUID:serviceUUID p:peripheral];
    
    if (!service)
    {
        NSString* err = [NSString stringWithFormat:@"Could not find service with UUID %@ on peripheral with UUID %@",
                         serviceUUIDString,
                         peripheral.identifier.UUIDString];
        NSLog(@"Could not find service with UUID %@ on peripheral with UUID %@",
              serviceUUIDString,
              peripheral.identifier.UUIDString);
        failCallback(@[err]);
        return nil;
    }
    
    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service prop:prop];
    
    // Special handling for INDICATE. If charateristic with notify is not found, check for indicate.
    if (prop == CBCharacteristicPropertyNotify && !characteristic) {
        characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service prop:CBCharacteristicPropertyIndicate];
    }
    
    // As a last resort, try and find ANY characteristic with this UUID, even if it doesn't have the correct properties
    if (!characteristic) {
        characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service];
    }
    
    if (!characteristic)
    {
        NSString* err = [NSString stringWithFormat:@"Could not find characteristic with UUID %@ on service with UUID %@ on peripheral with UUID %@", characteristicUUIDString,serviceUUIDString, peripheral.identifier.UUIDString];
        NSLog(@"Could not find characteristic with UUID %@ on service with UUID %@ on peripheral with UUID %@",
              characteristicUUIDString,
              serviceUUIDString,
              peripheral.identifier.UUIDString);
        failCallback(@[err]);
        return nil;
    }
    
    BLECommandContext *context = [[BLECommandContext alloc] init];
    [context setPeripheral:peripheral];
    [context setService:service];
    [context setCharacteristic:characteristic];
    return context;
    
}

-(NSString *) keyForPeripheral: (CBPeripheral *)peripheral andCharacteristic:(CBCharacteristic *)characteristic {
    return [NSString stringWithFormat:@"%@|%@", [peripheral uuidAsString], [characteristic UUID]];
}

@end
