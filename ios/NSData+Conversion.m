#import "NSData+Conversion.h"

@implementation NSData (NSData_Conversion)

#pragma mark - String Conversion
- (NSString *)hexadecimalString {
  /* Returns hexadecimal string of NSData. Empty string if data is empty.   */
  
  const unsigned char *dataBuffer = (const unsigned char *)[self bytes];
  
  if (!dataBuffer)
    return [NSString string];
  
  NSUInteger          dataLength  = [self length];
  NSMutableString     *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];
  
  for (int i = 0; i < dataLength; ++i)
    [hexString appendString:[NSString stringWithFormat:@"%02x", (unsigned int)dataBuffer[i]]];
  
  return [NSString stringWithString:hexString];
}

#pragma mark - String Conversion
- (NSArray *)toArray {
    /* Returns hexadecimal string of NSData. Empty string if data is empty.   */
    
    const unsigned char *dataBuffer = (const unsigned char *)[self bytes];
    
    if (!dataBuffer)
        return NULL;
    
    NSUInteger          dataLength  = [self length];
    NSMutableArray     *array  = [NSMutableArray arrayWithCapacity:dataLength];
    
    for (int i = 0; i < dataLength; ++i)
        [array addObject:[NSNumber numberWithInteger:dataBuffer[i]]];    
    
    return array;
}

@end
