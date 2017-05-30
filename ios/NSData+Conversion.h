#import <Foundation/Foundation.h>

@interface NSData (NSData_Conversion)

#pragma mark - String Conversion
- (NSString *)hexadecimalString;

#pragma mark - NSArray Conversion
- (NSArray *)toArray;

@end
