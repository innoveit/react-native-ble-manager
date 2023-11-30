#import <Foundation/Foundation.h>
#import "React/RCTBridgeModule.h"
#import "React/RCTEventDispatcher.h"

@interface RCT_EXTERN_MODULE(BleManager, NSObject)
RCT_EXTERN_METHOD(start:
                  (NSDictionary *)options
                  callback:(RCTResponseSenderBlock) callback
                  )
RCT_EXTERN_METHOD(scan:
                  (NSArray *)serviceUUIDStrings
                  timeoutSeconds:(nonnull NSNumber *)timeoutSeconds
                  allowDuplicates:(BOOL)allowDuplicates
                  scanningOptions:(nonnull NSDictionary*)scanningOptions
                  callback:(nonnull RCTResponseSenderBlock)callback
                  )
RCT_EXTERN_METHOD(connect:
                  (NSString *)peripheralUUID
                  options:(NSDictionary *)options
                  callback:(nonnull RCTResponseSenderBlock)callback
                  )
RCT_EXTERN_METHOD(disconnect:
                  (NSString *)peripheralUUID 
                  force:(BOOL)force
                  callback:(nonnull RCTResponseSenderBlock)callback)
RCT_EXTERN_METHOD(retrieveServices:
                  (NSString *)peripheralUUID
                  services:(NSArray<NSString *> *)services
                  callback:(nonnull RCTResponseSenderBlock)callback
                  )
RCT_EXTERN_METHOD(readRSSI:
                  (NSString *)deviceUUID
                  callback:(nonnull RCTResponseSenderBlock)callback
                  )
@end
