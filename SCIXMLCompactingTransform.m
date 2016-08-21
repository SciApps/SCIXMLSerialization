//
// SCIXMLCompactingTransform.m
// SCIXMLSerialization
//
// Created by Arpad Goretity
// on 13/08/2016
//
// Copyright (C) SciApps.io, 2016.
//

#import <stdbool.h>
#import <objc/runtime.h>

#import "SCIXMLCompactingTransform.h"
#import "SCIXMLSerialization.h"
#import "SCIXMLUtils.h"
#import "NSObject+SCIXMLSerialization.h"


NSString *const SCIXMLAttributeTransformKeyName  = @"name";
NSString *const SCIXMLAttributeTransformKeyValue = @"value";

NSString *const SCIXMLParserTypeError            = @"Error";
NSString *const SCIXMLParserTypeNull             = @"Null";
NSString *const SCIXMLParserTypeIdentity         = @"Identity";
NSString *const SCIXMLParserTypeObjCBool         = @"ObjCBool";
NSString *const SCIXMLParserTypeCXXBool          = @"CXXBool";
NSString *const SCIXMLParserTypeBool             = @"Bool";
NSString *const SCIXMLParserTypeDecimal          = @"Decimal";
NSString *const SCIXMLParserTypeBinary           = @"Binary";
NSString *const SCIXMLParserTypeOctal            = @"Octal";
NSString *const SCIXMLParserTypeHex              = @"Hex";
NSString *const SCIXMLParserTypeInteger          = @"Integer";
NSString *const SCIXMLParserTypeFloating         = @"Floating";
NSString *const SCIXMLParserTypeNumber           = @"Number";
NSString *const SCIXMLParserTypeEscapeC          = @"EscapeC";
NSString *const SCIXMLParserTypeUnescapeC        = @"UnescapeC";
NSString *const SCIXMLParserTypeEscapeXML        = @"EscapeXML";
NSString *const SCIXMLParserTypeUnescapeXML      = @"UnescapeXML";
NSString *const SCIXMLParserTypeTimestamp        = @"Timestamp";
NSString *const SCIXMLParserTypeDate             = @"Date";
NSString *const SCIXMLParserTypeBase64           = @"Base64";


NS_ASSUME_NONNULL_BEGIN
@interface SCIXMLCompactingTransform ()

+ (instancetype)attributeFilterTransformWithNameList:(NSArray<NSString *> *)nameList
                          invertContainmentCondition:(BOOL)invert;

+ (NSDictionary<NSString *, id _Nullable (^)(id)> *)parserSubtransforms;
+ (NSDictionary<NSString *, id _Nullable (^)(id)> *)unsafeLoadParserSubtransforms;

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

        // If both transforms have the given subtransform, there's a conflict.
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
                    return tmp == nil || tmp.sci_isError ? tmp : lhsSubtransform(tmp);
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
        if (immutableNode.sci_isDictionary == NO) {
            return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                         format:@"%s: node must be a dictionary", __PRETTY_FUNCTION__];
        }

        // ...as well as its attributes
        NSDictionary *attributes = immutableNode[SCIXMLNodeKeyAttributes];

        // if there are no attributes, save a mutableCopy of the input node
        if (attributes == nil) {
            return immutableNode;
        }

        if (attributes.sci_isDictionary == NO) {
            return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                         format:@"%s: attributes must be a dictionary", __PRETTY_FUNCTION__];
        }

        NSMutableDictionary *node = [immutableNode sci_mutableCopyOrSelf];

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

+ (instancetype)childFlatteningTransform {
    SCIXMLCompactingTransform *transform = [self new];

    transform.nodeTransform = ^id (NSDictionary *immutableNode) {
        if (immutableNode.sci_isDictionary == NO) {
            return immutableNode;
        }

        NSArray<NSString *> *children = immutableNode[SCIXMLNodeKeyChildren];

        // Spare a mutableCopy if the children are already removed
        if (children == nil) {
            return immutableNode;
        }

        // If the 'children' member is used for something different, don't touch it
        if (children.sci_isArray == NO) {
            return immutableNode;
        }

        // Leve flattened text nodes alone
        if (immutableNode.sci_isOneChildStringNode) {
            return immutableNode;
        }

        // Everything is awesome, so we can start collapsing the structure.
        // Start by removing the 'children' array.
        NSMutableDictionary *node = [immutableNode sci_mutableCopyOrSelf];
        node[SCIXMLNodeKeyChildren] = nil;

        for (NSDictionary *child in children) {
            if (child.sci_isDictionary == NO) {
                return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                             format:@"%s: non-string child nodes must be dictionaries",
                                                    __PRETTY_FUNCTION__];
            }

            NSString *name = child[SCIXMLNodeKeyName];
            if (name.sci_isString == NO) {
                return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                             format:@"%s: child nodes must have a string name",
                                                    __PRETTY_FUNCTION__];
            }

            // TODO(H2CO3): implement grouping of children by name
            if (child.sci_isOneChildCanonicalStringNode) {
                NSArray<NSString *> *children = child[SCIXMLNodeKeyChildren];
                node[name] = children.firstObject;
            } else {
                // Remove the name of the child (it has become redundant).
                // Optimize for the common case where the child has been created by built-in
                // transformations and is therefore mutable. Avoid copying in that case.
                NSMutableDictionary *mutableChild = [child sci_mutableCopyOrSelf];
                mutableChild[SCIXMLNodeKeyName] = nil;
                node[name] = mutableChild;
            }
        }

        return node;
    };

    return transform;
}

+ (instancetype)textNodeFlatteningTransform {
    SCIXMLCompactingTransform *transform = [self new];

    transform.nodeTransform = ^id (NSDictionary *node) {
        if (node.sci_isDictionary == NO) {
            return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                         format:@"%s: node must be a dictionary", __PRETTY_FUNCTION__];
        }

        // If the node is a text-ish node, collapse it into its text contents
        // TODO(H2CO3): ensure that node[SCIXMLNodeKeyType] is not nil
        if (node.sci_isTextOrCDATANode) {
            return node[SCIXMLNodeKeyText] ?: @""; // node transform must not yield nil
        }

        // Otherwise, don't touch it
        return node;
    };

    return transform;
}

+ (instancetype)commentFilterTransform {
    // TODO(H2CO3): implement
    NSAssert(NO, @"Unimplemented");
    return nil;
}

+ (instancetype)elementTypeFilterTransform {
    SCIXMLCompactingTransform *transform = [self new];

    transform.typeTransform = ^id _Nullable (id type) {
        return [type isEqual:SCIXMLNodeTypeElement] ? nil : type;
    };

    return transform;
}

+ (instancetype)attributeParserTransformWithTypeMap:(NSDictionary<NSString *, NSString *> *)typeMap
                           unspecifiedTransformType:(NSString *)unspecifiedTransformType {

    NSParameterAssert(typeMap);
    NSParameterAssert(unspecifiedTransformType);

    SCIXMLCompactingTransform *transform = [self new];

    transform.attributeTransform = ^id _Nullable (NSDictionary *nameValuePair) {
        if (nameValuePair.sci_isDictionary == NO) {
            return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                         format:@"%s requires a name-value dictionary", __PRETTY_FUNCTION__];
        }

        // TODO(H2CO3): check that name is not nil and that it is an NSString
        NSString *name = nameValuePair[SCIXMLAttributeTransformKeyName];
        id value       = nameValuePair[SCIXMLAttributeTransformKeyValue];

        NSString *transformName = typeMap[name] ?: unspecifiedTransformType;
        id _Nullable (^subtransform)(id) = self.parserSubtransforms[transformName];

        // TODO(H2CO3): check that subtransform is not nil
        return subtransform(value);
    };

    return transform;
}

+ (instancetype)memberParserTransformWithTypeMap:(NSDictionary<NSString *, NSString *> *)typeMap
                        unspecifiedTransformType:(NSString *)unspecifiedTransformType {

    // TODO(H2CO3): implement
    NSParameterAssert(typeMap);
    NSParameterAssert(unspecifiedTransformType);

    NSAssert(NO, @"Unimplemented");
    return nil;
}

+ (NSDictionary<NSString *, id _Nullable (^)(id)> *)parserSubtransforms {
    static NSDictionary<NSString *, id _Nullable (^)(id)> *subtransforms = nil;
    static dispatch_once_t token;

    // thread-safely cache attribute and member parser functions
    dispatch_once(&token, ^{
        subtransforms = [self unsafeLoadParserSubtransforms];
    });

    return subtransforms;
}

+ (NSDictionary<NSString *, id _Nullable (^)(id)> *)unsafeLoadParserSubtransforms {
    return @{
        SCIXMLParserTypeError: ^id _Nullable (id input) {
            return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                         format:@"no type specification for attribute or node: %@", input];
        },
        SCIXMLParserTypeNull: ^id _Nullable (id unused) {
            return nil;
        },
        SCIXMLParserTypeIdentity: ^id _Nullable (id input) {
            return input;
        },
        SCIXMLParserTypeObjCBool: ^id _Nullable (id input) {
            NSDictionary<NSString *, NSNumber *> *map = @{ @"YES": @YES, @"NO": @NO };
            return map[input] ?: [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                                       format:@"not an Obj-C BOOL string: %@", input];
        },
        SCIXMLParserTypeCXXBool: ^id _Nullable (id input) {
            NSDictionary<NSString *, NSNumber *> *map = @{ @"true": @true, @"false": @false };
            return map[input] ?: [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                                       format:@"not a C++ bool string: %@", input];
        },
        SCIXMLParserTypeBool: ^id _Nullable (id input) {
            NSDictionary<NSString *, NSNumber *> *map = @{
                @"YES":   @YES,
                @"NO":    @NO,
                @"true":  @true,
                @"false": @false,
            };

            return map[input] ?: [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                                       format:@"not a boolean string: %@", input];
        },
        SCIXMLParserTypeDecimal: ^id _Nullable (id input) {
            return SCIStringToDecimal(input);
        },
        SCIXMLParserTypeBinary: ^id _Nullable (id input) {
            return SCIStringToUnsigned(input, 2);
        },
        SCIXMLParserTypeOctal: ^id _Nullable (id input) {
            return SCIStringToUnsigned(input, 8);
        },
        SCIXMLParserTypeHex: ^id _Nullable (id input) {
            return SCIStringToUnsigned(input, 16);
        },
        SCIXMLParserTypeInteger: ^id _Nullable (id input) {
            return SCIStringToInteger(input);
        },
        SCIXMLParserTypeFloating: ^id _Nullable (id input) {
            return SCIStringToFloating(input);
        },
        SCIXMLParserTypeNumber: ^id _Nullable (id input) {
            return SCIStringToNumber(input);
        },
        // TODO(H2CO3): implement all parser transforms
    };
};

+ (instancetype)attributeFilterTransformWithWhitelist:(NSArray<NSString *> *)whitelist {
    NSParameterAssert(whitelist);

    return [self attributeFilterTransformWithNameList:whitelist
                           invertContainmentCondition:NO];
}

+ (instancetype)attributeFilterTransformWithBlacklist:(NSArray<NSString *> *)blacklist {
    NSParameterAssert(blacklist);

    return [self attributeFilterTransformWithNameList:blacklist
                           invertContainmentCondition:YES];
}

+ (instancetype)attributeFilterTransformWithNameList:(NSArray<NSString *> *)nameList
                          invertContainmentCondition:(BOOL)invert {

    NSParameterAssert(nameList);

    NSSet<NSString *> *nameSet = [NSSet setWithArray:nameList];
    id <SCIXMLCompactingTransform> transform = [self new];

    transform.attributeTransform = ^id _Nullable (NSDictionary *nameValuePair) {
        if (nameValuePair.sci_isDictionary == NO) {
            return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                         format:@"%s requires a name-value dictionary", __PRETTY_FUNCTION__];
        }

        // TODO(H2CO3): check that name is not nil
        NSString *name = nameValuePair[SCIXMLAttributeTransformKeyName];
        id value       = nameValuePair[SCIXMLAttributeTransformKeyValue];

        return [nameSet containsObject:name] ^ invert ? value : nil;
    };

    return transform;
}

+ (instancetype)memberFilterTransformWithWhitelist:(NSArray<NSString *> *)whitelist {
    // TODO(H2CO3): implement
    NSParameterAssert(whitelist);
    NSAssert(NO, @"Unimplemented");
    return nil;
}

+ (instancetype)memberFilterTransformWithBlacklist:(NSArray<NSString *> *)blacklist {
    // TODO(H2CO3): implement
    NSParameterAssert(blacklist);
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
