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
#import "SCIXMLSerialization.h"
#import "SCIXMLUtils.h"


@implementation NSObject (SCIXMLSerialization)

- (BOOL)sci_isString {
    return [self isKindOfClass:NSString.class];
}

- (BOOL)sci_isMutableString {
    return [self isKindOfClass:NSMutableString.class];
}

- (BOOL)sci_isArray {
    return [self isKindOfClass:NSArray.class];
}

- (BOOL)sci_isMutableArray {
    return [self isKindOfClass:NSMutableArray.class];
}

- (BOOL)sci_isDictionary {
    return [self isKindOfClass:NSDictionary.class];
}

- (BOOL)sci_isMutableDictionary {
    return [self isKindOfClass:NSMutableDictionary.class];
}

- (BOOL)sci_isNumber {
    return [self isKindOfClass:NSNumber.class];
}

- (BOOL)sci_isError {
    return [self isKindOfClass:NSError.class];
}

- (BOOL)sci_isTextOrCDATANode {
    if (self.sci_isDictionary == NO) {
        return NO;
    }

    NSDictionary *dictSelf = (NSDictionary *)self;

    // if the child has any additional info other than the 'type' and 'text'
    // keys, then it cannot just be replaced by its text child, because
    // that would result in the extra information being lost altogether.
    // These two keys are, however, required.
    if (SCIDictionaryHasExactKeys(dictSelf, @[ SCIXMLNodeKeyType, SCIXMLNodeKeyText ]) == NO) {
        return NO;
    }

    // Check if the type of the node is one of the text-containing types
    NSString *nodeType = dictSelf[SCIXMLNodeKeyType];
    NSArray<NSString *> *types = @[
        SCIXMLNodeTypeText,
        SCIXMLNodeTypeCDATA,
    ];

    return nodeType && [types containsObject:nodeType];
}

- (BOOL)sci_isOneChildStringNode {
    // A node is a one-child string node if it has a name
    // and a single child of string type.

    if (self.sci_isDictionary == NO) {
        return NO;
    }

    NSDictionary *dictSelf = (NSDictionary *)self;
    NSArray<NSString *> *children = dictSelf[SCIXMLNodeKeyChildren];
    NSString *name = dictSelf[SCIXMLNodeKeyName];

    return children.sci_isArray
        && children.count == 1
        && children.firstObject.sci_isString
        && name.sci_isString;
}

- (BOOL)sci_isOneChildCanonicalStringNode {
    if (self.sci_isDictionary == NO) {
        return NO;
    }

    NSDictionary *dictSelf = (NSDictionary *)self;

    // if the child has any additional info other than the 'name' and 'children'
    // keys, then it cannot just be replaced by its text child, because
    // that would result in the extra information being lost altogether.
    // These two keys are, however, required.
    return self.sci_isOneChildStringNode
        && SCIDictionaryHasExactKeys(dictSelf, @[ SCIXMLNodeKeyName, SCIXMLNodeKeyChildren ]);
}

- (id)sci_mutableCopyOrSelf {
    BOOL isMutable = self.sci_isMutableString || self.sci_isMutableArray || self.sci_isMutableDictionary;
    return isMutable ? self : [self mutableCopy];
}

@end
