#import "SwishContact.h"

@implementation SwishContact

- (NSString *)fullName {
    return [NSString stringWithFormat:@"%@ %@", self.firstName, self.lastName];
}

@end
