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
        peripherals = [NSMutableSet set];
        connectCallbacks = [NSMutableDictionary new];
        connectCallbackLatches = [NSMutableDictionary new];
        readCallbacks = [NSMutableDictionary new];
        writeCallbacks = [NSMutableDictionary new];
        writeQueue = [NSMutableArray array];
        notificationCallbacks = [NSMutableDictionary new];
        stopNotificationCallbacks = [NSMutableDictionary new];
        NSLog(@"BleManager created");
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
        readCallback(@[[NSNull null], stringFromData]);
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

RCT_EXPORT_METHOD(getDiscoveredPeripherals:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"Get discovered peripherals");
    NSMutableArray *discoveredPeripherals = [NSMutableArray array];
    @synchronized(peripherals) {
      for(CBPeripheral *peripheral in peripherals){
        NSDictionary * obj = [peripheral asDictionary];
        [discoveredPeripherals addObject:obj];
      }
    }
    callback(@[[NSNull null], [NSArray arrayWithArray:discoveredPeripherals]]);
}

RCT_EXPORT_METHOD(getConnectedPeripherals:(NSArray *)serviceUUIDStrings callback:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"Get connected peripherals");
    NSMutableArray *serviceUUIDs = [NSMutableArray new];
    for(NSString *uuidString in serviceUUIDStrings){
        CBUUID *serviceUUID =[CBUUID UUIDWithString:uuidString];
        [serviceUUIDs addObject:serviceUUID];
    }
    
    NSMutableArray *foundedPeripherals = [NSMutableArray array];
    if ([serviceUUIDs count] == 0){
        for(CBPeripheral *peripheral in peripherals){
            if([peripheral state] == CBPeripheralStateConnected || [peripheral state] == CBPeripheralStateConnecting){
                NSDictionary * obj = [peripheral asDictionary];
                [foundedPeripherals addObject:obj];
            }
        }
    } else {
        NSArray *connectedPeripherals = [manager retrieveConnectedPeripheralsWithServices:serviceUUIDs];
        for(CBPeripheral *peripheral in connectedPeripherals){
            NSDictionary * obj = [peripheral asDictionary];
            [foundedPeripherals addObject:obj];
        }
    }
    
    callback(@[[NSNull null], [NSArray arrayWithArray:foundedPeripherals]]);
}

RCT_EXPORT_METHOD(start:(NSDictionary *)options callback:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"BleManager initialized");
    NSDictionary *initOptions = nil;
    if ([[options allKeys] containsObject:@"showAlert"]){
        BOOL showAlert = [[options valueForKey:@"showAlert"] boolValue];
        initOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:showAlert] forKey:CBCentralManagerOptionShowPowerAlertKey];
        manager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:initOptions];
    } else {
        manager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
    }
    callback(@[]);
}

RCT_EXPORT_METHOD(scan:(NSArray *)serviceUUIDStrings timeoutSeconds:(nonnull NSNumber *)timeoutSeconds allowDuplicates:(BOOL)allowDuplicates callback:(nonnull RCTResponseSenderBlock)callback)
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
    callback(@[]);
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

RCT_EXPORT_METHOD(connect:(NSString *)peripheralUUID callback:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"connect");
    CBPeripheral *peripheral = [self findPeripheralByUUID:peripheralUUID];
    if (peripheral) {
        NSLog(@"Connecting to peripheral with UUID : %@", peripheralUUID);
        
        [connectCallbacks setObject:callback forKey:[peripheral uuidAsString]];
        [manager connectPeripheral:peripheral options:nil];
        
    } else {
        NSString *error = [NSString stringWithFormat:@"Could not find peripheral %@.", peripheralUUID];
        NSLog(@"%@", error);
        callback(@[error, [NSNull null]]);
    }
}

RCT_EXPORT_METHOD(disconnect:(NSString *)peripheralUUID  callback:(nonnull RCTResponseSenderBlock)callback)
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
        callback(@[]);
        
    } else {
        NSString *error = [NSString stringWithFormat:@"Could not find peripheral %@.", peripheralUUID];
        NSLog(@"%@", error);
        callback(@[error]);
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

RCT_EXPORT_METHOD(write:(NSString *)deviceUUID serviceUUID:(NSString*)serviceUUID  characteristicUUID:(NSString*)characteristicUUID message:(NSString*)message maxByteSize:(NSInteger)maxByteSize callback:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"Write");
    
    BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyWrite callback:callback];
    
    NSData* dataMessage = [[NSData alloc] initWithBase64EncodedString:message options:0];
    if (context) {
        CBPeripheral *peripheral = [context peripheral];
        CBCharacteristic *characteristic = [context characteristic];
        
        NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
        [writeCallbacks setObject:callback forKey:key];
        
        RCTLogInfo(@"Message to write(%lu): %@ ", (unsigned long)[dataMessage length], [dataMessage hexadecimalString]);
        if ([dataMessage length] > maxByteSize){
            int dataLength = (int)dataMessage.length;
            int count = 0;
            NSData* firstMessage;
            while(count < dataLength && (dataLength - count > maxByteSize)){
                if (count == 0){
                    firstMessage = [dataMessage subdataWithRange:NSMakeRange(count, maxByteSize)];
                }else{
                    NSData* splitMessage = [dataMessage subdataWithRange:NSMakeRange(count, maxByteSize)];
                    [writeQueue addObject:splitMessage];
                }
                count += maxByteSize;
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
    }
}


RCT_EXPORT_METHOD(writeWithoutResponse:(NSString *)deviceUUID serviceUUID:(NSString*)serviceUUID  characteristicUUID:(NSString*)characteristicUUID message:(NSString*)message maxByteSize:(NSInteger)maxByteSize queueSleepTime:(NSInteger)queueSleepTime callback:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"writeWithoutResponse");
    
    BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyWriteWithoutResponse callback:callback];
    NSData* dataMessage = [[NSData alloc] initWithBase64EncodedString:message options:0];
    if (context) {
        if ([dataMessage length] > maxByteSize) {
            NSUInteger length = [dataMessage length];
            NSUInteger offset = 0;
            CBPeripheral *peripheral = [context peripheral];
            CBCharacteristic *characteristic = [context characteristic];
            
            do {
                NSUInteger thisChunkSize = length - offset > maxByteSize ? maxByteSize : length - offset;
                NSData* chunk = [NSData dataWithBytesNoCopy:(char *)[dataMessage bytes] + offset length:thisChunkSize freeWhenDone:NO];
                
                offset += thisChunkSize;
                [peripheral writeValue:chunk forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
                [NSThread sleepForTimeInterval:(queueSleepTime / 1000)];
            } while (offset < length);
            
            NSLog(@"Message to write(%lu): %@ ", (unsigned long)[dataMessage length], [dataMessage hexadecimalString]);
            callback(@[]);
        } else {
            
            CBPeripheral *peripheral = [context peripheral];
            CBCharacteristic *characteristic = [context characteristic];
            
            NSLog(@"Message to write(%lu): %@ ", (unsigned long)[dataMessage length], [dataMessage hexadecimalString]);
            [peripheral writeValue:dataMessage forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
            callback(@[]);
        }
    }
}


RCT_EXPORT_METHOD(read:(NSString *)deviceUUID serviceUUID:(NSString*)serviceUUID  characteristicUUID:(NSString*)characteristicUUID callback:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"read");
    
    BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyRead callback:callback];
    if (context) {
        
        CBPeripheral *peripheral = [context peripheral];
        CBCharacteristic *characteristic = [context characteristic];
        
        NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
        [readCallbacks setObject:callback forKey:key];
        
        [peripheral readValueForCharacteristic:characteristic];  // callback sends value
    }
    
}

RCT_EXPORT_METHOD(startNotification:(NSString *)deviceUUID serviceUUID:(NSString*)serviceUUID  characteristicUUID:(NSString*)characteristicUUID callback:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"startNotification");
    
    BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyNotify callback:callback];
    
    if (context) {
        CBPeripheral *peripheral = [context peripheral];
        CBCharacteristic *characteristic = [context characteristic];
        
        NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
        [notificationCallbacks setObject: callback forKey: key];
        
        [peripheral setNotifyValue:YES forCharacteristic:characteristic];
    }
    
}

RCT_EXPORT_METHOD(stopNotification:(NSString *)deviceUUID serviceUUID:(NSString*)serviceUUID  characteristicUUID:(NSString*)characteristicUUID callback:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"stopNotification");
    
    BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyNotify callback:callback];
    
    if (context) {
        CBPeripheral *peripheral = [context peripheral];
        CBCharacteristic *characteristic = [context characteristic];
        
        NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
        [stopNotificationCallbacks setObject: callback forKey: key];
        
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
    
    if (writeCallback) {
        if (error) {
            NSLog(@"%@", error);
            [writeCallbacks removeObjectForKey:key];
            writeCallback(@[error.localizedDescription]);
        } else {
            if ([writeQueue count] == 0) {
                [writeCallbacks removeObjectForKey:key];
                writeCallback(@[]);
            }else{
                // Remove and write the queud message
                NSData *message = [writeQueue objectAtIndex:0];
                [writeQueue removeObjectAtIndex:0];
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
    [self.bridge.eventDispatcher sendAppEventWithName:@"BleManagerConnectPeripheral" body:@{@"peripheral": [peripheral uuidAsString]}];
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
            connectCallback(@[[NSNull null], [peripheral asDictionary]]);
        }
        [connectCallbackLatches removeObjectForKey:peripheralUUIDString];
    }
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
-(BLECommandContext*) getData:(NSString*)deviceUUIDString  serviceUUIDString:(NSString*)serviceUUIDString characteristicUUIDString:(NSString*)characteristicUUIDString prop:(CBCharacteristicProperties)prop callback:(nonnull RCTResponseSenderBlock)callback
{
    CBUUID *serviceUUID = [CBUUID UUIDWithString:serviceUUIDString];
    CBUUID *characteristicUUID = [CBUUID UUIDWithString:characteristicUUIDString];
    
    CBPeripheral *peripheral = [self findPeripheralByUUID:deviceUUIDString];
    
    if (!peripheral) {
        NSString* err = [NSString stringWithFormat:@"Could not find peripherial with UUID %@", deviceUUIDString];
        NSLog(@"Could not find peripherial with UUID %@", deviceUUIDString);
        callback(@[err]);
        
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
        callback(@[err]);
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
        callback(@[err]);
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
