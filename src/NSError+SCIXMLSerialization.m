//
// NSError+SCIXMLSerialization.m
// SCIXMLSerialization
//
// Created by Arpad Goretity
// on 08/08/2016
//
// Copyright (C) SciApps.io, 2016.
//

#import "NSError+SCIXMLSerialization.h"

#import <stdarg.h>

NSString *const SCIXMLErrorDomain = @"SCIXMLErrorDomain";


@implementation NSError (SCIXMLSerialization)

+ (NSError *)SCIXMLErrorWithCode:(SCIXMLErrorCode)errorCode {
    return [NSError errorWithDomain:SCIXMLErrorDomain
                               code:errorCode
                           userInfo:nil];
}

+ (NSError *)SCIXMLErrorWithCode:(SCIXMLErrorCode)errorCode
                          format:(NSString *)format, ... {

    va_list args;
    NSString *message;

    va_start(args, format);
    message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    return [NSError errorWithDomain:SCIXMLErrorDomain
                               code:errorCode
                           userInfo:@{ NSLocalizedDescriptionKey: message }];
}

+ (NSError *)SCIXMLErrorWithCode:(SCIXMLErrorCode)errorCode
                        rawError:(xmlError *)rawError {

    return [NSError SCIXMLErrorWithCode:errorCode
                                 format:@"line %d char %d: error #%d: %s",
                                        rawError->line,
                                        rawError->int2,
                                        rawError->code,
                                        rawError->message];
}

@end
