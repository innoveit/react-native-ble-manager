#import "CBPeripheral+Extensions.h"
#import "NSData+Conversion.h"

static char ADVERTISING_IDENTIFER;
static char ADVERTISEMENT_RSSI_IDENTIFER;

@implementation CBPeripheral(com_megster_ble_extension)

-(NSString *)uuidAsString {
  if (self.identifier.UUIDString) {
    return self.identifier.UUIDString;
  } else {
    return @"";
  }
}


-(NSDictionary *)asDictionary {
  NSString *uuidString = NULL;
  if (self.identifier.UUIDString) {
    uuidString = self.identifier.UUIDString;
  } else {
    uuidString = @"";
  }
  
  NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
  [dictionary setObject: uuidString forKey: @"id"];
  
  if ([self name]) {
    [dictionary setObject: [self name] forKey: @"name"];
  }
  
  if ([self advertisementRSSI]) {
    [dictionary setObject: [self advertisementRSSI] forKey: @"rssi"];
  }
  
  if ([self advertising]) {
    [dictionary setObject: [self advertising] forKey: @"advertising"];
  }
  
  if([[self services] count] > 0) {
    [self serviceAndCharacteristicInfo: dictionary];
  }
  
  return dictionary;
  
}

// AdvertisementData is from didDiscoverPeripheral. RFduino advertises a service name in the Mfg Data Field.
-(void)setAdvertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)rssi{
  
  [self setAdvertising:[self serializableAdvertisementData: advertisementData]];
  [self setAdvertisementRSSI: rssi];
  
}

// Translates the Advertisement Data from didDiscoverPeripheral into a structure that can be serialized as JSON
//
// This version keeps the iOS constants for keys, future versions could create more friendly keys
//
// Advertisement Data from a Peripheral could look something like
//
// advertising = {
//     kCBAdvDataChannel = 39;
//     kCBAdvDataIsConnectable = 1;
//     kCBAdvDataLocalName = foo;
//     kCBAdvDataManufacturerData = {
//         CDVType = ArrayBuffer;
//         data = "AABoZWxsbw==";
//     };
//     kCBAdvDataServiceData = {
//         FED8 = {
//             CDVType = ArrayBuffer;
//             data = "ACAAYWJjBw==";
//         };
//     };
//     kCBAdvDataServiceUUIDs = (
//         FED8
//     );
//     kCBAdvDataTxPowerLevel = 32;
//};
- (NSDictionary *) serializableAdvertisementData: (NSDictionary *) advertisementData {
  
  NSMutableDictionary *dict = [advertisementData mutableCopy];

  // Rename 'local name' key
  NSObject *localName = [dict objectForKey:CBAdvertisementDataLocalNameKey];
  if (localName) {
    [dict setObject:[dict objectForKey:CBAdvertisementDataLocalNameKey] forKey:@"localName"];
    [dict removeObjectForKey:CBAdvertisementDataLocalNameKey];
  }

  // Rename 'isConnectable' key
  NSObject *isConnectable = [dict objectForKey:CBAdvertisementDataIsConnectable];
  if (isConnectable) {
    [dict setObject:[dict objectForKey:CBAdvertisementDataIsConnectable] forKey:@"isConnectable"];
    [dict removeObjectForKey:CBAdvertisementDataIsConnectable];
  }

  // Rename 'power level' key
  NSObject *powerLevel = [dict objectForKey:CBAdvertisementDataTxPowerLevelKey];
  if (powerLevel) {
    [dict setObject:[dict objectForKey:CBAdvertisementDataTxPowerLevelKey] forKey:@"txPowerLevel"];
    [dict removeObjectForKey:CBAdvertisementDataTxPowerLevelKey];
  }

  // Service Data is a dictionary of CBUUID and NSData
  // Convert to String keys with Array Buffer values
  NSMutableDictionary *serviceData = [dict objectForKey:CBAdvertisementDataServiceDataKey];
  if (serviceData) {
    NSLog(@"%@", serviceData);
    
    for (CBUUID *key in [serviceData allKeys]) {
        if ([serviceData objectForKey:key]) {
            [serviceData setObject:dataToArrayBuffer([serviceData objectForKey:key]) forKey:[key UUIDString]];
            [serviceData removeObjectForKey:key];
        }
    }

    // replace the Service Data object
    [dict setObject:[dict objectForKey:CBAdvertisementDataServiceDataKey] forKey:@"serviceData"];
    [dict removeObjectForKey:CBAdvertisementDataServiceDataKey];
  }

  // Create a new list of Service UUIDs as Strings instead of CBUUIDs
  NSMutableArray *serviceUUIDs = [dict objectForKey: CBAdvertisementDataServiceUUIDsKey];
  NSMutableArray *serviceUUIDStrings;
  if (serviceUUIDs) {
    serviceUUIDStrings = [[NSMutableArray alloc] initWithCapacity:serviceUUIDs.count];
    
    for (CBUUID *uuid in serviceUUIDs) {
      [serviceUUIDStrings addObject:[uuid UUIDString]];
    }
    
    // replace the UUID list with list of strings
    [dict removeObjectForKey:CBAdvertisementDataServiceUUIDsKey];
    [dict setObject:serviceUUIDStrings forKey:@"serviceUUIDs"];
  }
  
  // Solicited Services UUIDs is an array of CBUUIDs, convert into Strings
  NSMutableArray *solicitiedServiceUUIDs = [dict objectForKey:CBAdvertisementDataSolicitedServiceUUIDsKey];
  NSMutableArray *solicitiedServiceUUIDStrings;
  if (solicitiedServiceUUIDs) {
    // NSLog(@"%@", solicitiedServiceUUIDs);
    solicitiedServiceUUIDStrings = [[NSMutableArray alloc] initWithCapacity:solicitiedServiceUUIDs.count];
    
    for (CBUUID *uuid in solicitiedServiceUUIDs) {
      [solicitiedServiceUUIDStrings addObject:[uuid UUIDString]];
    }
    
    // replace the UUID list with list of strings
    [dict removeObjectForKey:CBAdvertisementDataSolicitedServiceUUIDsKey];
    [dict setObject:solicitiedServiceUUIDStrings forKey:@"solicitedServiceUUIDs"];
  }

  // Overflow Services UUIDs is an array of CBUUIDs, convert into Strings
  NSMutableArray *overflowServiceUUIDs = [dict objectForKey:CBAdvertisementDataOverflowServiceUUIDsKey];
  NSMutableArray *overflowServiceUUIDStrings;
  if (overflowServiceUUIDs) {
    // NSLog(@"%@", overflowServiceUUIDs);
    overflowServiceUUIDStrings = [[NSMutableArray alloc] initWithCapacity:overflowServiceUUIDs.count];

    for (CBUUID *uuid in overflowServiceUUIDs) {
      [overflowServiceUUIDStrings addObject:[uuid UUIDString]];
    }

    // replace the UUID list with list of strings
    [dict removeObjectForKey:CBAdvertisementDataOverflowServiceUUIDsKey];
    [dict setObject:overflowServiceUUIDStrings forKey:@"overflowServiceUUIDs"];
  }
  
  // Convert the manufacturer data
  NSData *mfgData = [dict objectForKey:CBAdvertisementDataManufacturerDataKey];
  if (mfgData) {
    [dict setObject:dataToArrayBuffer([dict objectForKey:CBAdvertisementDataManufacturerDataKey]) forKey:@"manufacturerData"];
    [dict removeObjectForKey:CBAdvertisementDataManufacturerDataKey];
  }
  
  return dict;
}

// Put the service, characteristic, and descriptor data in a format that will serialize through JSON
// sending a list of services and a list of characteristics
- (void) serviceAndCharacteristicInfo: (NSMutableDictionary *) info {
  
  NSMutableArray *serviceList = [NSMutableArray new];
  NSMutableArray *characteristicList = [NSMutableArray new];
  
  // This can move into the CBPeripherial Extension
  for (CBService *service in [self services]) {
    [serviceList addObject:[[service UUID] UUIDString]];
    for (CBCharacteristic *characteristic in service.characteristics) {
      NSMutableDictionary *characteristicDictionary = [NSMutableDictionary new];
      [characteristicDictionary setObject:[[service UUID] UUIDString] forKey:@"service"];
      [characteristicDictionary setObject:[[characteristic UUID] UUIDString] forKey:@"characteristic"];
      
      if ([characteristic value] && [[characteristic value] length] > 0) {
        [characteristicDictionary setObject:dataToArrayBuffer([characteristic value]) forKey:@"value"];
      }
      if ([characteristic properties]) {
        //[characteristicDictionary setObject:[NSNumber numberWithInt:[characteristic properties]] forKey:@"propertiesValue"];
        [characteristicDictionary setObject:[self decodeCharacteristicProperties:characteristic] forKey:@"properties"];
      }
      // permissions only exist on CBMutableCharacteristics
      [characteristicDictionary setObject:[NSNumber numberWithBool:[characteristic isNotifying]] forKey:@"isNotifying"];
      [characteristicList addObject:characteristicDictionary];
      
      // descriptors always seem to be nil, probably a bug here
      NSMutableArray *descriptorList = [NSMutableArray new];
      for (CBDescriptor *descriptor in characteristic.descriptors) {
        NSMutableDictionary *descriptorDictionary = [NSMutableDictionary new];
        [descriptorDictionary setObject:[[descriptor UUID] UUIDString] forKey:@"descriptor"];
        if ([descriptor value]) { // should always have a value?
          [descriptorDictionary setObject:[descriptor value] forKey:@"value"];
        }
        [descriptorList addObject:descriptorDictionary];
      }
      if ([descriptorList count] > 0) {
        [characteristicDictionary setObject:descriptorList forKey:@"descriptors"];
      }
      
    }
  }
  
  [info setObject:serviceList forKey:@"services"];
  [info setObject:characteristicList forKey:@"characteristics"];
  
}

-(NSArray *) decodeCharacteristicProperties: (CBCharacteristic *) characteristic {
  NSMutableArray *props = [NSMutableArray new];
  
  CBCharacteristicProperties p = [characteristic properties];
  
  // NOTE: props strings need to be consistent across iOS and Android
  if ((p & CBCharacteristicPropertyBroadcast) != 0x0) {
    [props addObject:@"Broadcast"];
  }
  
  if ((p & CBCharacteristicPropertyRead) != 0x0) {
    [props addObject:@"Read"];
  }
  
  if ((p & CBCharacteristicPropertyWriteWithoutResponse) != 0x0) {
    [props addObject:@"WriteWithoutResponse"];
  }
  
  if ((p & CBCharacteristicPropertyWrite) != 0x0) {
    [props addObject:@"Write"];
  }
  
  if ((p & CBCharacteristicPropertyNotify) != 0x0) {
    [props addObject:@"Notify"];
  }
  
  if ((p & CBCharacteristicPropertyIndicate) != 0x0) {
    [props addObject:@"Indicate"];
  }
  
  if ((p & CBCharacteristicPropertyAuthenticatedSignedWrites) != 0x0) {
    [props addObject:@"AuthenticateSignedWrites"];
  }
  
  if ((p & CBCharacteristicPropertyExtendedProperties) != 0x0) {
    [props addObject:@"ExtendedProperties"];
  }
  
  if ((p & CBCharacteristicPropertyNotifyEncryptionRequired) != 0x0) {
    [props addObject:@"NotifyEncryptionRequired"];
  }
  
  if ((p & CBCharacteristicPropertyIndicateEncryptionRequired) != 0x0) {
    [props addObject:@"IndicateEncryptionRequired"];
  }
  
  return props;
}

// Borrowed from Cordova messageFromArrayBuffer since Cordova doesn't handle NSData in NSDictionary
id dataToArrayBuffer(NSData* data)
{
  return @{
           @"CDVType" : @"ArrayBuffer",
           @"data" :[data base64EncodedStringWithOptions:0],
           @"bytes" :[data toArray]
           };
}


-(void)setAdvertising:(NSDictionary *)newAdvertisingValue{
  objc_setAssociatedObject(self, &ADVERTISING_IDENTIFER, newAdvertisingValue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(NSString*)advertising{
  return objc_getAssociatedObject(self, &ADVERTISING_IDENTIFER);
}


-(void)setAdvertisementRSSI:(NSNumber *)newAdvertisementRSSIValue {
  objc_setAssociatedObject(self, &ADVERTISEMENT_RSSI_IDENTIFER, newAdvertisementRSSIValue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(NSString*)advertisementRSSI{
  return objc_getAssociatedObject(self, &ADVERTISEMENT_RSSI_IDENTIFER);
}

@end
