//
// SCIXMLError.m
// SCIXMLSerialization
//
// Created by Arpad Goretity
// on 08/08/2016
//
// Copyright (C) SciApps.io, 2016.
//

#import "SCIXMLError.h"


NSString *const SCIXMLErrorDomain = @"SCIXMLErrorDomain";


@implementation NSError (SCIXMLSerialization)

+ (NSError *)SCIXMLErrorWithCode:(SCIXMLErrorCode)errorCode {
	return [NSError errorWithDomain:SCIXMLErrorDomain
														 code:errorCode
												 userInfo:nil];
}

@end
