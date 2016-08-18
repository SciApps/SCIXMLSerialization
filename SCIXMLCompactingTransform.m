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
#import "NSObject+SCIXMLSerialization.h"


NSString *const SCIXMLAttributeTransformKeyName = @"name";
NSString *const SCIXMLAttributeTransformKeyValue = @"value";


NS_ASSUME_NONNULL_BEGIN
@interface SCIXMLCompactingTransform ()

+ (instancetype)attributeFilterTransformWithNameList:(NSArray<NSString *> *)nameList
                          invertContainmentCondition:(BOOL)invert;

@end
NS_ASSUME_NONNULL_END


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
                    NSObject *tmp = rhsSubtransform(value);
                    return tmp == nil || tmp.isError ? tmp : lhsSubtransform(tmp);
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

+ (id <SCIXMLCompactingTransform>)combineTransforms:(NSArray<id<SCIXMLCompactingTransform>> *)transforms
                         conflictResolutionStrategy:(SCIXMLTransformCombinationConflictResolutionStrategy)strategy {

    NSParameterAssert(transforms);

    id <SCIXMLCompactingTransform> newTransform = [self new];

    for (id <SCIXMLCompactingTransform> transform in transforms) {
        // combine in "reverse" order, right-to-left
        newTransform = [self combineTransform:transform
                                withTransform:newTransform
                   conflictResolutionStrategy:strategy];
    }

    return newTransform;
}

#pragma mark - Convenience factory methods

+ (instancetype)transformWithTypeTransform:(id _Nullable (^_Nullable)(id))typeTransform
                             nameTransform:(id _Nullable (^_Nullable)(id))nameTransform
                             textTransform:(id _Nullable (^_Nullable)(id))textTransform
                        attributeTransform:(id _Nullable (^_Nullable)(id))attributeTransform
                             nodeTransform:(id           (^_Nullable)(id))nodeTransform {

    return [[self alloc] initWithTypeTransform:typeTransform
                                 nameTransform:nameTransform
                                 textTransform:textTransform
                            attributeTransform:attributeTransform
                                 nodeTransform:nodeTransform];
}

+ (instancetype)attributeFlatteningTransform {
    id <SCIXMLCompactingTransform> transform = [self new];

    transform.nodeTransform = ^id (NSDictionary *immutableNode) {
        // the node must be a dictionary...
        if (immutableNode.isDictionary == NO) {
            return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                         format:@"%s: node must be a dictionary", __PRETTY_FUNCTION__];
        }

        // ...as well as its attributes
        NSDictionary *attributes = immutableNode[SCIXMLNodeKeyAttributes];

        // if there are no attributes, save a mutableCopy of the input node
        if (attributes == nil) {
            return immutableNode;
        }

        if (attributes.isDictionary == NO) {
            return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                         format:@"%s: attributes must be a dictionary", __PRETTY_FUNCTION__];
        }

        NSMutableDictionary *node = [immutableNode mutableCopy];

        // remove 'attributes' dictionary from new node
        node[SCIXMLNodeKeyAttributes] = nil;

        // append attributes to the node itself
        for (id <NSCopying> attrKey in attributes) {
            // if the attribute name already exists as a key in the node, that's an error
            if (node[attrKey] != nil) {
                return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                             format:@"attribute for key '%@' already exists in node %p",
                                                    attrKey,
                                                    (void *)immutableNode];
            }

            node[attrKey] = attributes[attrKey];
        }

        return node;
    };

    return transform;
}

+ (instancetype)childFlatteningTransformWithUnnamedNodeKeys:(NSDictionary<NSString *, NSString *> *_Nullable)unnamedNodeKeys {
    NSAssert(NO, @"Unimplemented");
    return nil;
}

+ (instancetype)textNodeFlatteningTransform {
    SCIXMLCompactingTransform *transform = [self new];

    transform.nodeTransform = ^id (NSDictionary *node) {
        if (node.isDictionary == NO) {
            return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                         format:@"%s: node must be a dictionary", __PRETTY_FUNCTION__];
        }

        // If the node is a text node, collapse it into its text contents
        if ([node[SCIXMLNodeKeyType] isEqual:SCIXMLNodeTypeText]) {
            return node[SCIXMLNodeKeyText] ?: @""; // node transform must not yield nil
        }

        // Otherwise, don't touch it
        return node;
    };

    return transform;
}

+ (instancetype)commentFilterTransform {
    NSAssert(NO, @"Unimplemented");
    return nil;
}

+ (instancetype)elementTypeFilterTransform {
    SCIXMLCompactingTransform *transform = [self new];

    transform.typeTransform = ^_Nullable id(id type) {
        return [type isEqual:SCIXMLNodeTypeElement] ? nil : type;
    };

    return transform;
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
    return [self attributeFilterTransformWithNameList:whitelist
                           invertContainmentCondition:NO];
}

+ (instancetype)attributeFilterTransformWithBlacklist:(NSArray<NSString *> *)blacklist {
    return [self attributeFilterTransformWithNameList:blacklist
                           invertContainmentCondition:YES];
}

+ (instancetype)attributeFilterTransformWithNameList:(NSArray<NSString *> *)nameList
                          invertContainmentCondition:(BOOL)invert {

    NSSet<NSString *> *nameSet = [NSSet setWithArray:nameList];
    id <SCIXMLCompactingTransform> transform = [self new];

    transform.attributeTransform = ^id _Nullable (NSDictionary *nameValuePair) {
        if (nameValuePair.isDictionary == NO) {
            return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                         format:@"%s requires a name-value dictionary", __PRETTY_FUNCTION__];
        }

        NSString *name = nameValuePair[SCIXMLAttributeTransformKeyName];
        id value       = nameValuePair[SCIXMLAttributeTransformKeyValue];

        return [nameSet containsObject:name] ^ invert ? value : nil;
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

- (instancetype)initWithTypeTransform:(id _Nullable (^_Nullable)(id))typeTransform
                        nameTransform:(id _Nullable (^_Nullable)(id))nameTransform
                        textTransform:(id _Nullable (^_Nullable)(id))textTransform
                   attributeTransform:(id _Nullable (^_Nullable)(id))attributeTransform
                        nodeTransform:(id           (^_Nullable)(id))nodeTransform {

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
