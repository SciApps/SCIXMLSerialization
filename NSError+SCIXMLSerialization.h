//
// NSError+SCIXMLSerialization.h
// SCIXMLSerialization
//
// Created by Arpad Goretity
// on 08/08/2016
//
// Copyright (C) SciApps.io, 2016.
//

#import <Foundation/Foundation.h>
#import <libxml/tree.h>


typedef NS_ENUM(NSUInteger, SCIXMLErrorCode) {
    SCIXMLErrorCodeParserInit        = 1, // failed to initialize parser
    SCIXMLErrorCodeWriterInit        = 2, // failed to initialize serializer/writer
    SCIXMLErrorCodeWriteFailed       = 3, // error in actually writing the XML data
    SCIXMLErrorCodeMalformedXML      = 4, // malformed XML, cannot parse
    SCIXMLErrorCodeMalformedTree     = 5, // malformed tree, cannot serialize or compactify
    SCIXMLErrorCodeNotUTF8Encoded    = 6, // input data is not in UTF-8
    SCIXMLErrorCodeUnimplemented     = 7, // feature, node type, etc. not yet implemented
};


NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const SCIXMLErrorDomain;

@interface NSError (SCIXMLSerialization)

+ (NSError *)SCIXMLErrorWithCode:(SCIXMLErrorCode)errorCode;

+ (NSError *)SCIXMLErrorWithCode:(SCIXMLErrorCode)errorCode
                          format:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);

+ (NSError *)SCIXMLErrorWithCode:(SCIXMLErrorCode)errorCode
                        rawError:(xmlError *)rawError;

@end

NS_ASSUME_NONNULL_END
