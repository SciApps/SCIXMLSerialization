//
// SCIXMLCompactingTransform.m
// SCIXMLSerialization
//
// Created by Arpad Goretity
// on 13/08/2016
//
// Copyright (C) SciApps.io, 2016.
//

#import <objc/runtime.h>

#import "SCIXMLCompactingTransform.h"


@implementation SCIXMLCompactingTransform

#pragma mark - Combining transforms

+ (id <SCIXMLCompactingTransform>)combineTransform:(id <SCIXMLCompactingTransform>)lhs
                                     withTransform:(id <SCIXMLCompactingTransform>)rhs
                        conflictResolutionStrategy:(SCIXMLTransformCombinationConflictResolutionStrategy)strategy {

    NSParameterAssert(lhs);
    NSParameterAssert(rhs);

    SCIXMLCompactingTransform *transform = [SCIXMLCompactingTransform new];

    // enumerate all properties of the compacting transform protocol
    unsigned n = 0;
    objc_property_t *props = protocol_copyPropertyList(@protocol(SCIXMLCompactingTransform), &n);

    for (unsigned i = 0; i < n; i++) {
        const char *c_name = property_getName(props[i]);
        NSString *name = @(c_name);

        id _Nullable (^lhs_prop)(id) = [lhs valueForKey:name];
        id _Nullable (^rhs_prop)(id) = [rhs valueForKey:name];
        id _Nullable (^new_prop)(id) = nil;

        if (lhs_prop && rhs_prop) {
            switch (strategy) {
            case SCIXMLTransformCombinationConflictResolutionStrategyUseLeft: {
                new_prop = lhs_prop;
                break;
            }
            case SCIXMLTransformCombinationConflictResolutionStrategyUseRight: {
                new_prop = rhs_prop;
                break;
            }
            case SCIXMLTransformCombinationConflictResolutionStrategyCompose: {
                new_prop = ^id _Nullable(id value) {
                    id tmp = rhs_prop(value);
                    return tmp == nil || [tmp isKindOfClass:NSError.class] ? tmp : lhs_prop(tmp);
                };
                break;
            }
            default:
                NSAssert(NO, @"invalid conflict resolution strategy");
                break;
            }
        } else {
            new_prop = lhs_prop ?: rhs_prop;
        }

        [transform setValue:new_prop forKey:name];
    }

    free(props);

    return transform;
}

#pragma mark - Convenience factory methods

+ (instancetype)transformWithTypeTransform:(id _Nullable (^_Nullable)(NSString *))typeTransform
                             nameTransform:(id _Nullable (^_Nullable)(NSString *))nameTransform
                             textTransform:(id _Nullable (^_Nullable)(NSString *))textTransform
                        attributeTransform:(id _Nullable (^_Nullable)(NSString *))attributeTransform
                             nodeTransform:(id           (^_Nullable)(NSDictionary *))nodeTransform {

    return [[self alloc] initWithTypeTransform:typeTransform
                                 nameTransform:nameTransform
                                 textTransform:textTransform
                            attributeTransform:attributeTransform
                                 nodeTransform:nodeTransform];
}

+ (instancetype)attributeFlatteningTransform {
    NSAssert(NO, @"Unimplemented");
    return nil;
}

+ (instancetype)childFlatteningTransformWithUnnamedNodeKeys:(NSDictionary<NSString *, NSString *> *_Nullable)unnamedNodeKeys {
    NSAssert(NO, @"Unimplemented");
    return nil;
}

+ (instancetype)attributeParserTransformWithTypeMap:(NSDictionary<NSString *, NSString *> *)typeMap {
    NSAssert(NO, @"Unimplemented");
    return nil;
}

+ (instancetype)memberParserTransformWithTypeMap:(NSDictionary<NSString *, NSString *> *)typeMap {
    NSAssert(NO, @"Unimplemented");
    return nil;
}

+ (instancetype)attributeFilterTransformWithWhitelist:(NSArray<NSString *> *)whitelist {
    NSAssert(NO, @"Unimplemented");
    return nil;
}

+ (instancetype)attributeFilterTransformWithBlacklist:(NSArray<NSString *> *)blacklist {
    NSAssert(NO, @"Unimplemented");
    return nil;
}

+ (instancetype)memberFilterTransformWithWhitelist:(NSArray<NSString *> *)whitelist {
    NSAssert(NO, @"Unimplemented");
    return nil;
}

+ (instancetype)memberFilterTransformWithBlacklist:(NSArray<NSString *> *)blacklist {
    NSAssert(NO, @"Unimplemented");
    return nil;
}

#pragma mark - Initializers

- (instancetype)initWithTypeTransform:(id _Nullable (^_Nullable)(NSString *))typeTransform
                        nameTransform:(id _Nullable (^_Nullable)(NSString *))nameTransform
                        textTransform:(id _Nullable (^_Nullable)(NSString *))textTransform
                   attributeTransform:(id _Nullable (^_Nullable)(NSString *))attributeTransform
                        nodeTransform:(id           (^_Nullable)(NSDictionary *))nodeTransform {

    self = [super init];
    if (self) {
        self.typeTransform      = typeTransform;
        self.nameTransform      = nameTransform;
        self.textTransform      = textTransform;
        self.attributeTransform = attributeTransform;
        self.nodeTransform      = nodeTransform;
    }
    return self;
}

- (instancetype)init {
    return [self initWithTypeTransform:nil
                         nameTransform:nil
                         textTransform:nil
                    attributeTransform:nil
                         nodeTransform:nil];
}


@end
