//
// NSObject+SCIXMLSerialization.m
// SCIXMLSerialization
//
// Created by Arpad Goretity
// on 18/08/2016
//
// Copyright (C) SciApps.io, 2016.
//

#import "NSObject+SCIXMLSerialization.h"


@implementation NSObject (SCIXMLSerialization)

- (BOOL)isString {
    return [self isKindOfClass:NSString.class];
}

- (BOOL)isMutableString {
    return [self isKindOfClass:NSMutableString.class];
}

- (BOOL)isArray {
    return [self isKindOfClass:NSArray.class];
}

- (BOOL)isMutableArray {
    return [self isKindOfClass:NSMutableArray.class];
}

- (BOOL)isDictionary {
    return [self isKindOfClass:NSDictionary.class];
}

- (BOOL)isMutableDictionary {
    return [self isKindOfClass:NSMutableDictionary.class];
}

- (BOOL)isError {
    return [self isKindOfClass:NSError.class];
}

@end
