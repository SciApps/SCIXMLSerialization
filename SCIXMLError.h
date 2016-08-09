//
// SCIXMLError.h
// SCIXMLSerialization
//
// Created by Arpad Goretity
// on 08/08/2016
//
// Copyright (C) SciApps.io, 2016.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSUInteger, SCIXMLErrorCode) {
    SCIXMLErrorCodeParserInit        = 1, // failed to initialize parser
    SCIXMLErrorCodeMalformedInput    = 2, // malformed XML, cannot parse
    SCIXMLErrorCodeNotUTF8Encoded    = 3, // input data is not in UTF-8
    SCIXMLErrorCodeUnimplemented     = 4, // feature, node type, etc. not yet implemented
};


NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const SCIXMLErrorDomain;

@interface NSError (SCIXMLSerialization)

+ (NSError *)SCIXMLErrorWithCode:(SCIXMLErrorCode)errorCode;

+ (NSError *)SCIXMLErrorWithCode:(SCIXMLErrorCode)errorCode
                          format:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);

@end

NS_ASSUME_NONNULL_END
