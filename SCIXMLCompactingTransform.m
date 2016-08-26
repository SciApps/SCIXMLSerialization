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

+ (NSDictionary<NSString *, id _Nullable (^)(NSString *, id)> *)parserSubtransforms;
+ (NSDictionary<NSString *, id _Nullable (^)(NSString *, id)> *)unsafeLoadParserSubtransforms;

+ (id _Nullable (^)(NSString *, id))parserSubtransformWithTypeMap:(NSDictionary<NSString *, id> *)typeMap
                                                             name:(NSString *)name
                                                         fallback:(id)fallback;

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

+ (instancetype)childFlatteningTransformWithGroupingMap:(NSDictionary<NSString *, NSArray<NSString *> *> *_Nullable)groupingMap {

    SCIXMLCompactingTransform *transform = [self new];

    transform.nodeTransform = ^id (NSDictionary *immutableNode) {
        if (immutableNode.sci_isDictionary == NO) {
            return immutableNode;
        }

        NSArray<NSString *> *children = immutableNode[SCIXMLNodeKeyChildren];
        NSString *parentName = immutableNode[SCIXMLNodeKeyName];

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

        // If the node does not have a name or the name is not an NSString, that's an error
        if (parentName == nil || parentName.sci_isString == NO) {
            return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                         format:@"node %p has no name or its name is not a string",
                                                (void *)immutableNode];
        }

        // Everything is awesome, so we can start collapsing the structure.
        // Start by removing the 'children' array.
        NSMutableDictionary *node = [immutableNode sci_mutableCopyOrSelf];
        node[SCIXMLNodeKeyChildren] = nil;

        // Then, add (mutable) arrays for child names of which the corresponding
        // children should be grouped in an array.
        // If the node already has keys that are contained in the goroupedChildNames set,
        // that's a potential error.
        NSSet<NSString *> *groupedChildNames = [NSSet setWithArray:groupingMap[parentName] ?: @[]];

        for (NSString *childName in groupedChildNames) {
            if (node[childName] != nil) {
                return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                             format:@"key '%@' already exists in the parent node, but"
                                                    " it is the name of grouped children", childName];
            }

            node[childName] = [NSMutableArray new];
        }

        // Now enumerate all children and determine if and how they should be flattened.
        for (NSDictionary *child in children) {
            if (child.sci_isDictionary == NO) {
                return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                             format:@"%s: non-string child nodes must be dictionaries",
                                                    __PRETTY_FUNCTION__];
            }

            NSString *childName = child[SCIXMLNodeKeyName];
            if (childName == nil || childName.sci_isString == NO) {
                return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                             format:@"%s: child nodes must have a string name",
                                                    __PRETTY_FUNCTION__];
            }

            BOOL shouldGroupChild = [groupedChildNames containsObject:childName];

            // If the node already has a key for this child's name, and it is not
            // because it's an array that we added on purpose, that's an error
            if (node[childName] != nil && shouldGroupChild == NO) {
                return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                             format:@"duplicate child '%@' in node", childName];
            }

            id objectToAdd = nil;

            // Check the type of the child. If it's a trivial node that only wraps
            // one single string, then replace it by that string.
            // Otherwise, leave it alone, except that its name should be removed
            // because it is redundant since its name will be its key in the parent.
            if (child.sci_isOneChildCanonicalStringNode) {
                NSArray<NSString *> *children = child[SCIXMLNodeKeyChildren];
                objectToAdd = children.firstObject;
                assert(children.firstObject.sci_isString);
            } else {
                // Optimize for the common case where the child has been created by built-in
                // transformations and is therefore mutable. Avoid copying in that case.
                NSMutableDictionary *mutableChild = [child sci_mutableCopyOrSelf];
                mutableChild[SCIXMLNodeKeyName] = nil;
                objectToAdd = mutableChild;
            }

            assert(objectToAdd != nil);

            // If the child is to be added to an array, then do so. Otherwise,
            // just set it for its name as a key in its parent node dictionary.
            if (shouldGroupChild) {
                NSMutableArray *childrenArray = node[childName];
                assert(childrenArray.sci_isMutableArray);
                [childrenArray addObject:objectToAdd];
            } else {
                assert(node[childName] == nil);
                node[childName] = objectToAdd;
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

+ (instancetype)attributeParserTransformWithTypeMap:(NSDictionary<NSString *, id> *)typeMap
                                           fallback:(id)fallback {

    NSParameterAssert(typeMap);
    NSParameterAssert(fallback);

    SCIXMLCompactingTransform *transform = [self new];

    transform.attributeTransform = ^id _Nullable (NSDictionary *nameValuePair) {
        if (nameValuePair.sci_isDictionary == NO) {
            return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                         format:@"%s requires a name-value dictionary", __PRETTY_FUNCTION__];
        }

        // TODO(H2CO3): check that name is not nil and that it is an NSString
        NSString *name = nameValuePair[SCIXMLAttributeTransformKeyName];
        id value       = nameValuePair[SCIXMLAttributeTransformKeyValue];

        // TODO(H2CO3): check that subtransform is not nil
        id _Nullable (^subtransform)(NSString *, id);
        subtransform = [self parserSubtransformWithTypeMap:typeMap
                                                      name:name
                                                  fallback:fallback];

        return subtransform(name, value);
    };

    return transform;
}

+ (instancetype)memberParserTransformWithTypeMap:(NSDictionary<NSString *, id> *)typeMap
                                        fallback:(id)fallback {

    NSParameterAssert(typeMap);
    NSParameterAssert(fallback);

    SCIXMLCompactingTransform *transform = [self new];

    transform.nodeTransform = ^id (NSDictionary *immutableNode) {
        // if the node is not a dictionary, don't try to second guess the user
        if (immutableNode.sci_isDictionary == NO) {
            return immutableNode;
        }

        NSArray<NSString *> *memberNames = immutableNode.allKeys;
        NSMutableDictionary *node = [immutableNode sci_mutableCopyOrSelf];

        for (NSString *name in memberNames) {
            // TODO(H2CO3): check that subtransform is not nil
            id _Nullable (^subtransform)(NSString *, id);
            subtransform = [self parserSubtransformWithTypeMap:typeMap
                                                          name:name
                                                      fallback:fallback];

            id result = subtransform(name, node[name]);

            // If transforming any of the members fails, return the resulting error
            if ([result sci_isError]) {
                return result;
            }

            node[name] = result;
        }

        return node;
    };

    return transform;
}

+ (NSDictionary<NSString *, id _Nullable (^)(NSString *, id)> *)parserSubtransforms {
    static NSDictionary<NSString *, id _Nullable (^)(NSString *, id)> *subtransforms = nil;
    static dispatch_once_t token;

    // thread-safely cache attribute and member parser functions
    dispatch_once(&token, ^{
        subtransforms = [self unsafeLoadParserSubtransforms];
    });

    return subtransforms;
}

+ (NSDictionary<NSString *, id _Nullable (^)(NSString *, id)> *)unsafeLoadParserSubtransforms {
    return @{
        SCIXMLParserTypeError: ^id _Nullable (NSString *name, id value) {
            return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                         format:@"no type specification for attribute or node '%@'", name];
        },
        SCIXMLParserTypeNull: ^id _Nullable (NSString *name, id value) {
            return nil;
        },
        SCIXMLParserTypeIdentity: ^id _Nullable (NSString *name, id value) {
            return value;
        },
        SCIXMLParserTypeObjCBool: ^id _Nullable (NSString *name, id value) {
            NSDictionary<NSString *, NSNumber *> *map = @{
                @"YES": @YES,
                @"NO":  @NO
            };

            return map[value] ?: [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                                       format:@"'%@': not an Obj-C BOOL string: '%@'",
                                                              name, value];
        },
        SCIXMLParserTypeCXXBool: ^id _Nullable (NSString *name, id value) {
            NSDictionary<NSString *, NSNumber *> *map = @{
                @"true":  @true,
                @"false": @false
            };

            return map[value] ?: [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                                       format:@"'%@': not a C++ bool string: '%@'",
                                                              name, value];
        },
        SCIXMLParserTypeBool: ^id _Nullable (NSString *name, id value) {
            NSDictionary<NSString *, NSNumber *> *map = @{
                @"YES":   @YES,
                @"NO":    @NO,
                @"true":  @true,
                @"false": @false,
            };

            return map[value] ?: [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                                       format:@"'%@': not a boolean string: '%@'",
                                                              name, value];
        },
        SCIXMLParserTypeDecimal: ^id _Nullable (NSString *name, id value) {
            return SCIStringToDecimal(value);
        },
        SCIXMLParserTypeBinary: ^id _Nullable (NSString *name, id value) {
            return SCIStringToUnsigned(value, 2);
        },
        SCIXMLParserTypeOctal: ^id _Nullable (NSString *name, id value) {
            return SCIStringToUnsigned(value, 8);
        },
        SCIXMLParserTypeHex: ^id _Nullable (NSString *name, id value) {
            return SCIStringToUnsigned(value, 16);
        },
        SCIXMLParserTypeInteger: ^id _Nullable (NSString *name, id value) {
            return SCIStringToInteger(value);
        },
        SCIXMLParserTypeFloating: ^id _Nullable (NSString *name, id value) {
            return SCIStringToFloating(value);
        },
        SCIXMLParserTypeNumber: ^id _Nullable (NSString *name, id value) {
            return SCIStringToNumber(value);
        },
        SCIXMLParserTypeTimestamp: ^id _Nullable (NSString *name, id value) {
            id numberOrError = SCIStringToNumber(value);

            if ([numberOrError sci_isNumber]) {
                NSNumber *number = numberOrError;
                return [NSDate dateWithTimeIntervalSince1970:number.doubleValue];
            } else {
                // otherwise, it's an error - couldn't parse numeric string
                return numberOrError;
            }
        },
        SCIXMLParserTypeDate: ^id _Nullable (NSString *name, NSString *value) {
            if (value.sci_isString == NO) {
                return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                             format:@"expected '%@' to have an NSString value; got %@",
                                                    name, NSStringFromClass(value.class)];
            }

            // Creating a date formatter is expensive - formatters should be re-used
            static NSDateFormatter *dateFormatter = nil;
            static dispatch_once_t token;

            dispatch_once(&token, ^{
                dateFormatter = [NSDateFormatter new];
                dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
                dateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
            });

            // Common date formats resembling ISO-8601 full date and time
            NSArray<NSString *> *dateFormats = @[
                @"yyyy'-'MM'-'dd'T'HH':'mm':'ss.SZ",
                @"yyyy'-'MM'-'dd'T'HH':'mm':'ss.S",
                @"yyyy'-'MM'-'dd'T'HH':'mm':'ssZ",
                @"yyyy'-'MM'-'dd'T'HH':'mm':'ss",
            ];

            for (NSString *format in dateFormats) {
                dateFormatter.dateFormat = format;
                NSDate *date = [dateFormatter dateFromString:value];

                if (date) {
                    return date;
                }
            }

            return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                         format:@"value of key '%@' ('%@') isn't a valid ISO-8601 string",
                                                name, value];
        },
        SCIXMLParserTypeBase64: ^id _Nullable (NSString *name, NSString *value) {
            if (value.sci_isString == NO) {
                return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                             format:@"expected an NSString for key '%@'", name];
            }

            // Remove any whitespace (it's customary to present Base-64 in a tabulated, multiline shape)
            NSCharacterSet *wsCharset = NSCharacterSet.whitespaceAndNewlineCharacterSet;

            if ([value rangeOfCharacterFromSet:wsCharset].location != NSNotFound) {
                NSMutableString *noWsString = [value mutableCopy];

                [noWsString replaceOccurrencesOfString:@"\\s"
                                            withString:@""
                                               options:NSRegularExpressionSearch
                                                 range:(NSRange){ 0, noWsString.length }];

                value = noWsString;
            }

            NSData *data = [[NSData alloc] initWithBase64EncodedString:value
                                                               options:kNilOptions];

            if (data == nil) {
                return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                             format:@"value for key '%@' is not a Base-64 string", name];
            }

            return data;
        },
        // TODO(H2CO3): implement all parser transforms
    };
};

+ (id _Nullable (^)(NSString *, id))parserSubtransformWithTypeMap:(NSDictionary<NSString *, id> *)typeMap
                                                             name:(NSString *)name
                                                         fallback:(id)fallback {

    NSParameterAssert(typeMap);
    NSParameterAssert(name);
    NSParameterAssert(fallback);

    id subtransformNameOrBlock = typeMap[name] ?: fallback;

    // if it's a transform name, then look it up in the table of predefined parser subtransforms
    if ([subtransformNameOrBlock sci_isString]) {
        // TODO(H2CO3): check that 'parserSubtransforms[subtransformNameOrBlock]' is not nil
        return self.parserSubtransforms[subtransformNameOrBlock];
    }

    // Otherwise, it must be a block
    NSAssert(
        SCIBlockIsParserSubtransform(subtransformNameOrBlock),
        @"parser transform block must be compatible with signature 'id _Nullable (^)(NSString *, id)'"
    );

    return subtransformNameOrBlock;
}

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
