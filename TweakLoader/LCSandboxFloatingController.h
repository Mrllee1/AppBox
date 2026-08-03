@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface LCSandboxFloatingController : NSObject

+ (instancetype)sharedController;
- (void)installWhenReady;

@end

NS_ASSUME_NONNULL_END
