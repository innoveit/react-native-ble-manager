#import <objc/runtime.h>
#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "CBPeripheral+Extensions.h"


@interface CBPeripheral(com_megster_ble_extension)

@property (nonatomic, retain) NSDictionary *advertising;
@property (nonatomic, retain) NSNumber *advertisementRSSI;

-(void)setAdvertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber*)rssi;
-(NSDictionary *)asDictionary;
-(NSString *)uuidAsString;

@end
