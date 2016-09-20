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

@property (nonatomic, readonly) BOOL sci_isString;
@property (nonatomic, readonly) BOOL sci_isMutableString;
@property (nonatomic, readonly) BOOL sci_isArray;
@property (nonatomic, readonly) BOOL sci_isMutableArray;
@property (nonatomic, readonly) BOOL sci_isDictionary;
@property (nonatomic, readonly) BOOL sci_isMutableDictionary;
@property (nonatomic, readonly) BOOL sci_isNumber;
@property (nonatomic, readonly) BOOL sci_isError;

@property (nonatomic, readonly) BOOL sci_isTextOrCDATANode;
@property (nonatomic, readonly) BOOL sci_isOneChildStringNode;
@property (nonatomic, readonly) BOOL sci_isOneChildCanonicalStringNode;

// Returns the object unchanged if it's mutable, a mutableCopy thereof otherwise.
// (this should really not be implemented on NSObject but on a specific
// superclass of Cocoa collections... but unfortunately, there's no such thing.)
- (id)sci_mutableCopyOrSelf;

@end
