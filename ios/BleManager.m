#import <Foundation/Foundation.h>
#import "React/RCTBridgeModule.h"

@interface RCT_EXTERN_MODULE(BleManager, NSObject)
    RCT_EXTERN_METHOD(start:
      (NSDictionary *)options
      callback:(RCTResponseSenderBlock) callback
    )
@end
