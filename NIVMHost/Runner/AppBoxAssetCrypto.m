#import "AppBoxAssetCrypto.h"

@import CommonCrypto;

@implementation AppBoxAssetCrypto

+ (NSData *)decryptImageData:(NSData *)data {
  if (data.length == 0) {
    return nil;
  }

  NSData *key = [self configuredBytesForInfoKey:@"AppBoxAssetAESKey"
                               fallbackMaterial:@"appbox-asset-image-key-v1"
                                          length:kCCKeySizeAES256];
  NSData *iv = [self configuredBytesForInfoKey:@"AppBoxAssetAESIV"
                              fallbackMaterial:@"appbox-asset-image-iv-v1"
                                         length:kCCBlockSizeAES128];

  NSMutableData *output = [NSMutableData dataWithLength:data.length + kCCBlockSizeAES128];
  size_t outputLength = 0;
  CCCryptorStatus status = CCCrypt(kCCDecrypt,
                                   kCCAlgorithmAES,
                                   kCCOptionPKCS7Padding,
                                   key.bytes,
                                   key.length,
                                   iv.bytes,
                                   data.bytes,
                                   data.length,
                                   output.mutableBytes,
                                   output.length,
                                   &outputLength);
  if (status != kCCSuccess) {
    return nil;
  }
  output.length = outputLength;
  return output;
}

+ (NSData *)configuredBytesForInfoKey:(NSString *)infoKey
                     fallbackMaterial:(NSString *)fallbackMaterial
                                length:(NSUInteger)length {
  NSString *configured = [NSBundle.mainBundle objectForInfoDictionaryKey:infoKey];
  if ([configured isKindOfClass:NSString.class] && configured.length > 0) {
    NSData *decoded = [self decodeConfiguredBytes:configured];
    if (decoded.length == length) {
      return decoded;
    }
  }

  NSData *material = [fallbackMaterial dataUsingEncoding:NSUTF8StringEncoding];
  uint8_t digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256(material.bytes, (CC_LONG)material.length, digest);
  return [NSData dataWithBytes:digest length:length];
}

+ (NSData *)decodeConfiguredBytes:(NSString *)value {
  if (value.length % 2 == 0 && [self isHex:value]) {
    NSMutableData *result = [NSMutableData dataWithCapacity:value.length / 2];
    for (NSUInteger offset = 0; offset < value.length; offset += 2) {
      unsigned int byte = 0;
      NSString *pair = [value substringWithRange:NSMakeRange(offset, 2)];
      [[NSScanner scannerWithString:pair] scanHexInt:&byte];
      uint8_t parsedByte = (uint8_t)byte;
      [result appendBytes:&parsedByte length:1];
    }
    return result;
  }

  NSData *base64 = [[NSData alloc] initWithBase64EncodedString:value options:0];
  if (base64.length > 0) {
    return base64;
  }
  return [value dataUsingEncoding:NSUTF8StringEncoding];
}

+ (BOOL)isHex:(NSString *)value {
  NSCharacterSet *notHex = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"] invertedSet];
  return [value rangeOfCharacterFromSet:notHex].location == NSNotFound;
}

@end
