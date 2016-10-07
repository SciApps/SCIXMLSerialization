//
// SCIXMLCanonicalizingTransform.m
// SCIXMLSerialization
//
// Created by Arpad Goretity
// on 26/08/2016
//
// Copyright (C) SciApps.io, 2016.
//

#import "SCIXMLCanonicalizingTransform.h"
#import "SCIXMLSerialization.h"


NSString *const SCIXMLTempKeyType            = @"#type";
NSString *const SCIXMLTempKeyName            = @"#name";
NSString *const SCIXMLTempKeyChild           = @"#child";
NSString *const SCIXMLTempKeyAttrs           = @"#attrs";

NSString *const SCIXMLTmpTypeBranchElement   = @"branchElement";
NSString *const SCIXMLTmpTypeLeafElement     = @"leafElement";
NSString *const SCIXMLTmpTypeTextNode        = @"textNode";


@implementation SCIXMLCanonicalizingTransform

- (instancetype)initWithTypeProvider:(NSString *_Nullable (^)(id, NSError *__autoreleasing *))typeProvider
                        nameProvider:(NSString *_Nullable (^_Nullable)(id, NSError *__autoreleasing *))nameProvider
                   attributeProvider:(NSSet<NSString *> *_Nullable (^_Nullable)(id, NSError *__autoreleasing *))attributeProvider
                       childProvider:(NSArray *_Nullable (^_Nullable)(id, NSError *__autoreleasing *))childProvider
                        textProvider:(NSString *_Nullable (^_Nullable)(id, NSError *__autoreleasing *))textProvider
                  attributeTransform:(NSString *_Nullable (^_Nullable)(id, NSString *, NSError *__autoreleasing *))attributeTransform {

    self = [super init];
    if (self) {
        self.typeProvider       = typeProvider;
        self.nameProvider       = nameProvider;
        self.attributeProvider  = attributeProvider;
        self.childProvider      = childProvider;
        self.textProvider       = textProvider;
        self.attributeTransform = attributeTransform;
    }
    return self;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype _Nullable)init {
    return nil;
}
#pragma clang diagnostic pop

- (instancetype)initWithTypeProvider:(NSString *_Nullable (^)(id, NSError *__autoreleasing *))typeProvider {
    return [self initWithTypeProvider:typeProvider
                         nameProvider:nil
                    attributeProvider:nil
                        childProvider:nil
                         textProvider:nil
                   attributeTransform:nil];
}

+ (instancetype)transformWithTypeProvider:(NSString *_Nullable (^)(id, NSError *__autoreleasing *))typeProvider
                             nameProvider:(NSString *_Nullable (^_Nullable)(id, NSError *__autoreleasing *))nameProvider
                        attributeProvider:(NSSet<NSString *> *_Nullable (^_Nullable)(id, NSError *__autoreleasing *))attributeProvider
                            childProvider:(NSArray *_Nullable (^_Nullable)(id, NSError *__autoreleasing *))childProvider
                             textProvider:(NSString *_Nullable (^_Nullable)(id, NSError *__autoreleasing *))textProvider
                       attributeTransform:(NSString *_Nullable (^_Nullable)(id, NSString *, NSError *__autoreleasing *))attributeTransform {

    return [[self alloc] initWithTypeProvider:typeProvider
                                 nameProvider:nameProvider
                            attributeProvider:attributeProvider
                                childProvider:childProvider
                                 textProvider:textProvider
                           attributeTransform:attributeTransform];
}

#pragma mark - NSCopying

- (instancetype)copyWithZone:(NSZone *)zone {
    return [self.class transformWithTypeProvider:self.typeProvider
                                    nameProvider:self.nameProvider
                               attributeProvider:self.attributeProvider
                                   childProvider:self.childProvider
                                    textProvider:self.textProvider
                              attributeTransform:self.attributeTransform];
}

#pragma mark - Convenience factory methods

+ (id <SCIXMLCanonicalizingTransform>)transformForCanonicalizingNaturalDictionary {

    id typeProvider = ^NSString *(id object, NSError *__autoreleasing *error) {
        NSDictionary *typeMap = @{
            SCIXMLTmpTypeBranchElement: SCIXMLNodeTypeElement,
            SCIXMLTmpTypeLeafElement:   SCIXMLNodeTypeElement,
            SCIXMLTmpTypeTextNode:      SCIXMLNodeTypeText,
        };

        NSString *tmpType = object[SCIXMLTempKeyType];
        NSString *xmlType = typeMap[tmpType];

        if (xmlType == nil) {
            [self setError:error format:@"unknown node type: %@", tmpType];
        }

        return xmlType;
    };

    id nameProvider = ^NSString *(NSDictionary *object, NSError *__autoreleasing *error) {
        return object[SCIXMLTempKeyName];
    };

    id attributeProvider = ^NSSet<NSString *> *(id object, NSError *__autoreleasing *error) {
        NSDictionary<NSString *, NSDictionary *> *child = object[SCIXMLTempKeyChild];
        if ([child isKindOfClass:NSDictionary.class]) {
            return [NSSet setWithArray:child[SCIXMLTempKeyAttrs].allKeys];
        } else {
            return NSSet.set;
        }
    };

    id attributeTransform = ^NSString *(id node, NSString *name, NSError *__autoreleasing *error) {
        return node[SCIXMLTempKeyChild][SCIXMLTempKeyAttrs][name];
    };

    id childProvider = ^NSArray *(NSDictionary *object, NSError *__autoreleasing *error) {
        // This function transforms a node in natural format (i.e. a string or a dictionary in natural format)
        // into a semi-canonical, temporary description, suitable for canonicalization by the transformations.
        NSDictionary *(^childToDescriptor)(NSString *, id) = ^(NSString *elementName, id child) {
            return @{
                SCIXMLTempKeyType:  [child isKindOfClass:NSString.class] ? SCIXMLTmpTypeLeafElement : SCIXMLTmpTypeBranchElement,
                SCIXMLTempKeyName:  elementName,
                SCIXMLTempKeyChild: child,
            };
        };

        // Creates an array with a raw text node as its only elements
        NSArray *(^childArrayWithSingleTextNode)(NSString *) = ^(NSString *string) {
            return @[
                @{
                    SCIXMLTempKeyType:  SCIXMLTmpTypeTextNode,
                    SCIXMLTempKeyChild: string,
                }
            ];
        };

        // Converts an array of natural-format dictionaries to an array of semi-canonical descriptors
        NSArray *(^childArrayWithElementsInArray)(NSArray *) = ^NSArray *(NSArray *array) {
            NSMutableArray *children = [NSMutableArray arrayWithCapacity:array.count];

            for (NSDictionary *node in array) {
                if ([node isKindOfClass:NSDictionary.class] == NO) {
                    [self setError:error
                            format:@"Array element must be a dictionary; found %@", node.class];
                    return nil;
                }

                if (node.count != 1) {
                    [self setError:error
                            format:@"Dictionary in array must have exactly one key; found %lu", (unsigned long) node.count];
                    return nil;
                }

                NSString *nodeName = node.allKeys.firstObject;
                NSString *value = node[nodeName];
                [children addObject:childToDescriptor(nodeName, value)];
            }

            return children;
        };

        // This does NOT recursively check for funnily-constructed, explicit
        // dictionary nodes with the SCIXMLTempKeyChild key. The reason for that is
        // that it doesn't really make sense to try and explicitly construct
        // the temporary semi-canonical format by hand using deeper and deeper
        // levels of "child" links - it's just superfluous and would needlessly
        // complicate attribute handling. Hence, its implementation is omitted,
        // and this function merely performs the naive and obviuos iteration.
        NSArray *(^childArrayWithKeysAndValuesOfDictionary)(NSDictionary *) = ^NSArray *(NSDictionary *dict) {
            NSMutableArray *children = [NSMutableArray arrayWithCapacity:dict.count];

            for (NSString *nodeName in dict) {
                if ([nodeName isEqualToString:SCIXMLTempKeyAttrs]) {
                    continue;
                }

                id node = dict[nodeName];
                [children addObject:childToDescriptor(nodeName, node)];
            }

            return children;
        };

        NSString *type = object[SCIXMLTempKeyType];

        if ([type isEqualToString:SCIXMLTmpTypeBranchElement]) {
            // "Branch" elements are elements that contain child elements

            id child = object[SCIXMLTempKeyChild];

            if ([child isKindOfClass:NSDictionary.class]) {
                NSDictionary *dict = child;

                // If the user has already put in an explicit text or array child, process it
                id grandChild = dict[SCIXMLTempKeyChild];
                if (grandChild) {
                    if ([grandChild isKindOfClass:NSString.class]) {
                        return childArrayWithSingleTextNode(grandChild);
                    } else if ([grandChild isKindOfClass:NSArray.class]) {
                        return childArrayWithElementsInArray(grandChild);
                    } else if ([grandChild isKindOfClass:NSDictionary.class]) {
                        return childArrayWithKeysAndValuesOfDictionary(grandChild);
                    } else {
                        [self setError:error format:@"Invalid child type: %@", [grandChild class]];
                        return nil;
                    }
                }

                return childArrayWithKeysAndValuesOfDictionary(dict);
            } else if ([child isKindOfClass:NSArray.class]) {
                return childArrayWithElementsInArray(child);
            } else {
                [self setError:error
                        format:@"parent's children must be wrapped in a dictionary or an array; found %@", [child class]];
                return nil;
            }
        } else if ([type isEqualToString:SCIXMLTmpTypeLeafElement]) {
            // "Leaf" elements are elements that contain a raw text node only, but not elements
            return childArrayWithSingleTextNode(object[SCIXMLTempKeyChild]);
        } else {
            [self setError:error
                    format:@"children of non-text element must be other non-text (branch) elements or text (leaf) elements; raw text nodes are not allowed"];
            return nil;
        }
    };

    id textProvider = ^NSString *(NSDictionary *object, NSError *__autoreleasing *error) {
        return object[SCIXMLTempKeyChild];
    };

    // Cache transform because it's quite expensive to construct
    static id <SCIXMLCanonicalizingTransform> transform;
    static dispatch_once_t token;

    dispatch_once(&token, ^{
        transform = [SCIXMLCanonicalizingTransform transformWithTypeProvider:typeProvider
                                                                nameProvider:nameProvider
                                                           attributeProvider:attributeProvider
                                                               childProvider:childProvider
                                                                textProvider:textProvider
                                                          attributeTransform:attributeTransform];
    });

    return transform;
}

#pragma mark - Other helper methods

// Prepares a root dictionary in "natural" format for canonicalization
+ (NSDictionary *_Nullable)semiCanonicalDictionaryWithNaturalDictionary:(NSDictionary *)root
                                                                  error:(NSError *__autoreleasing *)error {

    NSParameterAssert(root);

    // Root object must have exactly one key
    if (root.count != 1) {
        [self setError:error
                format:@"root element must have exactly 1 key; got %lu", (unsigned long) root.count];
        return nil;
    }

    NSString *rootName = root.allKeys.firstObject;
    NSString *child = root.allValues.firstObject;

    return @{
        SCIXMLTempKeyType:  [child isKindOfClass:NSString.class] ? SCIXMLTmpTypeLeafElement : SCIXMLTmpTypeBranchElement,
        SCIXMLTempKeyName:  rootName,
        SCIXMLTempKeyChild: child,
    };
}

#pragma mark - Private methods

+ (void)setError:(NSError *__autoreleasing *)error
          format:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3) {

    NSParameterAssert(format);

    if (error == NULL) {
        return;
    }

    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                 code:NSKeyValueValidationError
                             userInfo:@{ NSLocalizedDescriptionKey: message }];
}

@end
