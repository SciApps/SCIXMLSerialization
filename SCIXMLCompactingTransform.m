//
// SCIXMLCompactingTransform.m
// SCIXMLSerialization
//
// Created by Arpad Goretity
// on 13/08/2016
//
// Copyright (C) SciApps.io, 2016.
//

#import "SCIXMLCompactingTransform.h"


@implementation SCIXMLCompactingTransform

+ (instancetype)transformWithTypeTransform:(id _Nullable (^_Nullable)(NSString *))typeTransform
                             nameTransform:(id _Nullable (^_Nullable)(NSString *))nameTransform
                        attributeTransform:(id _Nullable (^_Nullable)(NSString *))attributeTransform
                             textTransform:(id _Nullable (^_Nullable)(NSString *))textTransform
                             nodeTransform:(id _Nullable (^_Nullable)(NSDictionary *))nodeTransform {

    return [[self alloc] initWithTypeTransform:typeTransform
                                 nameTransform:nameTransform
                            attributeTransform:attributeTransform
                                 textTransform:textTransform
                                 nodeTransform:nodeTransform];
}

- (instancetype)initWithTypeTransform:(id _Nullable (^_Nullable)(NSString *))typeTransform
                        nameTransform:(id _Nullable (^_Nullable)(NSString *))nameTransform
                   attributeTransform:(id _Nullable (^_Nullable)(NSString *))attributeTransform
                        textTransform:(id _Nullable (^_Nullable)(NSString *))textTransform
                        nodeTransform:(id _Nullable (^_Nullable)(NSDictionary *))nodeTransform {

    self = [super init];
    if (self) {
        self.typeTransform      = typeTransform;
        self.nameTransform      = nameTransform;
        self.attributeTransform = attributeTransform;
        self.textTransform      = textTransform;
        self.nodeTransform      = nodeTransform;
    }
    return self;
}

- (instancetype)init {
    return [self initWithTypeTransform:nil
                         nameTransform:nil
                    attributeTransform:nil
                         textTransform:nil
                         nodeTransform:nil];
}


@end
