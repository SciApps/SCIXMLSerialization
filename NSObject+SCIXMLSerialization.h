//
// NSObject+SCIXMLSerialization.h
// SCIXMLSerialization
//
// Created by Arpad Goretity
// on 18/08/2016
//
// Copyright (C) SciApps.io, 2016.
//


#import <Foundation/Foundation.h>


@interface NSObject (SCIXMLSerialization)

@property (nonatomic, readonly) BOOL isString;
@property (nonatomic, readonly) BOOL isMutableString;
@property (nonatomic, readonly) BOOL isArray;
@property (nonatomic, readonly) BOOL isMutableArray;
@property (nonatomic, readonly) BOOL isDictionary;
@property (nonatomic, readonly) BOOL isMutableDictionary;
@property (nonatomic, readonly) BOOL isError;

@end
