#import "AppBoxAssetCrypto.h"

@import CommonCrypto;
#import <zlib.h>

@implementation AppBoxAssetCrypto

+ (NSData *)decryptImageData:(NSData *)data {
  if (data.length == 0) {
    return nil;
  }

  NSData *key = [self configuredBytesForInfoKey:@"QuietformAssetAESKey"
                               fallbackMaterial:@"appbox-asset-image-key-v1"
                                          length:kCCKeySizeAES256];
  NSData *iv = [self configuredBytesForInfoKey:@"QuietformAssetAESIV"
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

+ (NSData *)encryptTempMailAPIData:(NSData *)data {
  return [self cryptTempMailAPIData:data operation:kCCEncrypt];
}

+ (NSData *)decryptTempMailAPIData:(NSData *)data {
  return [self cryptTempMailAPIData:data operation:kCCDecrypt];
}

+ (NSData *)cryptTempMailAPIData:(NSData *)data operation:(CCOperation)operation {
  if (data.length == 0) {
    return nil;
  }

  NSData *key = [self configuredBytesForInfoKey:@"TempMailAPIAESKey"
                               fallbackMaterial:@"84d76a52788a6c3c9bff5f9a4084f84d"
                                          length:kCCKeySizeAES128];
  NSData *iv = [self configuredBytesForInfoKey:@"TempMailAPIAESIV"
                              fallbackMaterial:@"1b95061000a8bd9f2ad3537b74649b59"
                                         length:kCCBlockSizeAES128];
  NSMutableData *output = [NSMutableData dataWithLength:data.length + kCCBlockSizeAES128];
  size_t outputLength = 0;
  CCCryptorStatus status = CCCrypt(operation,
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

+ (NSData *)gunzipTempMailAPIData:(NSData *)data {
  if (data.length == 0) {
    return nil;
  }

  z_stream stream;
  memset(&stream, 0, sizeof(stream));
  stream.next_in = (Bytef *)data.bytes;
  stream.avail_in = (uInt)data.length;

  if (inflateInit2(&stream, 15 + 32) != Z_OK) {
    return nil;
  }

  NSMutableData *output = [NSMutableData dataWithLength:MAX(data.length * 2, 4096)];
  int status = Z_OK;
  while (status == Z_OK) {
    if (stream.total_out >= output.length) {
      output.length += MAX(data.length, 4096);
    }
    stream.next_out = (Bytef *)output.mutableBytes + stream.total_out;
    stream.avail_out = (uInt)(output.length - stream.total_out);
    status = inflate(&stream, Z_SYNC_FLUSH);
  }
  inflateEnd(&stream);

  if (status != Z_STREAM_END) {
    return nil;
  }
  output.length = stream.total_out;
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

  NSData *configuredFallback = [self decodeConfiguredBytes:fallbackMaterial];
  if (configuredFallback.length == length) {
    return configuredFallback;
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
