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
    SCIXMLErrorCodeParserInit,            // failed to initialize parser
    SCIXMLErrorCodeMalformedInput,        // malformed XML, cannot parse
    SCIXMLErrorCodeNotUTF8Encoded,        // input data is not in UTF-8
};


NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const SCIXMLErrorDomain;

@interface NSError (SCIXMLSerialization)
+ (NSError *)SCIXMLErrorWithCode:(SCIXMLErrorCode)errorCode;
@end

NS_ASSUME_NONNULL_END
