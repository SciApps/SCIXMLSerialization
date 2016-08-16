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
#import "SCIXMLSerialization.h"


NSString *const SCIXMLAttributeTransformKeyName = @"name";
NSString *const SCIXMLAttributeTransformKeyValue = @"value";


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

        id _Nullable (^lhsSubtransform)(id) = [lhs valueForKey:name];
        id _Nullable (^rhsSubtransform)(id) = [rhs valueForKey:name];
        id _Nullable (^newSubtransform)(id) = nil;

        if (lhsSubtransform && rhsSubtransform) {
            switch (strategy) {
            case SCIXMLTransformCombinationConflictResolutionStrategyUseLeft: {
                newSubtransform = lhsSubtransform;
                break;
            }
            case SCIXMLTransformCombinationConflictResolutionStrategyUseRight: {
                newSubtransform = rhsSubtransform;
                break;
            }
            case SCIXMLTransformCombinationConflictResolutionStrategyCompose: {
                newSubtransform = ^id _Nullable(id value) {
                    id tmp = rhsSubtransform(value);
                    return (tmp == nil || [tmp isKindOfClass:NSError.class]) ? tmp : lhsSubtransform(tmp);
                };
                break;
            }
            default:
                NSAssert(NO, @"invalid conflict resolution strategy");
                break;
            }
        } else {
            newSubtransform = lhsSubtransform ?: rhsSubtransform;
        }

        [transform setValue:newSubtransform forKey:name];
    }

    free(props);

    return transform;
}

#pragma mark - Convenience factory methods

+ (instancetype)transformWithTypeTransform:(id _Nullable (^_Nullable)(NSString *))typeTransform
                             nameTransform:(id _Nullable (^_Nullable)(NSString *))nameTransform
                             textTransform:(id _Nullable (^_Nullable)(NSString *))textTransform
                        attributeTransform:(id _Nullable (^_Nullable)(NSDictionary *))attributeTransform
                             nodeTransform:(id           (^_Nullable)(NSDictionary *))nodeTransform {

    return [[self alloc] initWithTypeTransform:typeTransform
                                 nameTransform:nameTransform
                                 textTransform:textTransform
                            attributeTransform:attributeTransform
                                 nodeTransform:nodeTransform];
}

+ (instancetype)attributeFlatteningTransform {
    id <SCIXMLCompactingTransform> transform = [self new];

    transform.nodeTransform = ^id (NSDictionary *immutableNode) {
        NSDictionary *attributes = immutableNode[SCIXMLNodeKeyAttributes];
        NSMutableDictionary *node = [immutableNode mutableCopy];

        // remove 'attributes' dictionary from new node
        node[SCIXMLNodeKeyAttributes] = nil;

        // append attributes to the node itself
        for (NSString *attrName in attributes) {
            // if the attribute name already exists as a key in the node, that's an error
            if (node[attrName] != nil) {
                return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                             format:@"attribute '%@' already exists in node %p",
                                                    attrName,
                                                    (void *)immutableNode];
            }

            node[attrName] = attributes[attrName];
        }

        return node;
    };

    return transform;
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
    id <SCIXMLCompactingTransform> transform = [self new];
    NSSet<NSString *> *whitelistSet = [NSSet setWithArray:whitelist];

    transform.attributeTransform = ^id _Nullable (NSDictionary *nameValuePair) {
        NSString *name  = nameValuePair[SCIXMLAttributeTransformKeyName];
        NSString *value = nameValuePair[SCIXMLAttributeTransformKeyValue];

        return [whitelistSet containsObject:name] ? value : nil;
    };

    return transform;
}

+ (instancetype)attributeFilterTransformWithBlacklist:(NSArray<NSString *> *)blacklist {
    id <SCIXMLCompactingTransform> transform = [self new];
    NSSet<NSString *> *blacklistSet = [NSSet setWithArray:blacklist];

    transform.attributeTransform = ^id _Nullable (NSDictionary *nameValuePair) {
        NSString *name  = nameValuePair[SCIXMLAttributeTransformKeyName];
        NSString *value = nameValuePair[SCIXMLAttributeTransformKeyValue];

        return [blacklistSet containsObject:name] ? nil : value;
    };

    return transform;
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
                   attributeTransform:(id _Nullable (^_Nullable)(NSDictionary *))attributeTransform
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
