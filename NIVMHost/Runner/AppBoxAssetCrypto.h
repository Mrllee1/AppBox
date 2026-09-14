#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AppBoxAssetCrypto : NSObject

+ (nullable NSData *)decryptImageData:(NSData *)data;

/// AES-128-CBC helpers used by the first-party temporary-mail API transport.
/// The API still verifies every response with HMAC-SHA256 in Swift before the
/// decrypted bytes are decoded.
+ (nullable NSData *)encryptTempMailAPIData:(NSData *)data;
+ (nullable NSData *)decryptTempMailAPIData:(NSData *)data;

/// Decompresses gzip responses produced by the API for payloads over 1 KiB.
+ (nullable NSData *)gunzipTempMailAPIData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
