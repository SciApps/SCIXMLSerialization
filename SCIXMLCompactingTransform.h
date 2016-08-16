//
// SCIXMLCompactingTransform.h
// SCIXMLSerialization
//
// Created by Arpad Goretity
// on 13/08/2016
//
// Copyright (C) SciApps.io, 2016.
//

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const SCIXMLAttributeTransformKeyName;
FOUNDATION_EXPORT NSString *const SCIXMLAttributeTransformKeyValue;


@protocol SCIXMLCompactingTransform <NSObject>

@property (nonatomic, copy, nullable) id _Nullable (^typeTransform)(NSString *);
@property (nonatomic, copy, nullable) id _Nullable (^nameTransform)(NSString *);
@property (nonatomic, copy, nullable) id _Nullable (^textTransform)(NSString *);
@property (nonatomic, copy, nullable) id _Nullable (^attributeTransform)(NSDictionary *);
@property (nonatomic, copy, nullable) id           (^nodeTransform)(NSDictionary *);

// NSKeyValueCoding is an informal protocol, and as such,
// we don't get the valueForKey: and setValue:forKey: methods
// by conforming to the NSObject protocol. So, this explicit
// declaration of the methods is necessary.
- (id _Nullable)valueForKey:(NSString *)key;
- (void)setValue:(id _Nullable)value forKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END


// Strategy for resolving conflicts that arise when two transforms to-be-combined
// both contain a certain sub-transform.
// 'UseLeft' resolves the conflict by using the sub-transform of the left-hand side.
// 'UseRight' resolves the conflict by using the sub-transform of the right-hand side.
// 'Compose' resolves the conflict by generating a new sub-transform that calls the
// sub-transform of the RHS first, then call that of the LHS with the resulting value.
// If the result of the first sub-transform is nil, then the second sub-transform is
// not called and nil is returned.
typedef NS_ENUM(NSUInteger, SCIXMLTransformCombinationConflictResolutionStrategy) {
    SCIXMLTransformCombinationConflictResolutionStrategyUseLeft,
    SCIXMLTransformCombinationConflictResolutionStrategyUseRight,
    SCIXMLTransformCombinationConflictResolutionStrategyCompose,
};


NS_ASSUME_NONNULL_BEGIN
@interface SCIXMLCompactingTransform : NSObject <SCIXMLCompactingTransform>

// Sub-transforms.
// These may return nil which usually means "remove the transformed object".
// The only exception are node sub-transforms which *must* return a non-nil object.
// Sub-transforms may also return an instance of NSError, in which case the
// transformation operation will be aborted and the error will be propagated back
// to the caller via the out NSError ** parameter of SCIXMLSerialization's methods.
//
// The transforms will be invoked on each individual node in the following order:
//   1. typeTransform
//   2. nameTransform
//   3. textTransform
//   4. attributeTransform
//   5. nodeTransform
//
@property (nonatomic, copy, nullable) id _Nullable (^typeTransform)(NSString *);
@property (nonatomic, copy, nullable) id _Nullable (^nameTransform)(NSString *);
@property (nonatomic, copy, nullable) id _Nullable (^textTransform)(NSString *);
@property (nonatomic, copy, nullable) id _Nullable (^attributeTransform)(NSDictionary *);
@property (nonatomic, copy, nullable) id           (^nodeTransform)(NSDictionary *);

// Designated initializer.
// Note: -init just calls this with all nil sub-transforms,
// so -init and +new result in essentially an (inefficient) identity transform.
- (instancetype)initWithTypeTransform:(id _Nullable (^_Nullable)(NSString *))typeTransform
                        nameTransform:(id _Nullable (^_Nullable)(NSString *))nameTransform
                        textTransform:(id _Nullable (^_Nullable)(NSString *))textTransform
                   attributeTransform:(id _Nullable (^_Nullable)(NSDictionary *))attributeTransform
                        nodeTransform:(id           (^_Nullable)(NSDictionary *))nodeTransform NS_DESIGNATED_INITIALIZER;

// Combines two transforms.
+ (id <SCIXMLCompactingTransform>)combineTransform:(id <SCIXMLCompactingTransform>)lhs
                                     withTransform:(id <SCIXMLCompactingTransform>)rhs
                        conflictResolutionStrategy:(SCIXMLTransformCombinationConflictResolutionStrategy)strategy;

//
// Convenience factory methods for common use cases
//

// General, all-customizable convenience factory method
+ (instancetype)transformWithTypeTransform:(id _Nullable (^_Nullable)(NSString *))typeTransform
                             nameTransform:(id _Nullable (^_Nullable)(NSString *))nameTransform
                             textTransform:(id _Nullable (^_Nullable)(NSString *))textTransform
                        attributeTransform:(id _Nullable (^_Nullable)(NSDictionary *))attributeTransform
                             nodeTransform:(id           (^_Nullable)(NSDictionary *))nodeTransform;

// A transform that removes the 'attributes' dictionary and adds its contents
// directly to the node being transformed.
// If the attribute name already exists in the node as a key, an error is returned.
// This is a node transform.
+ (instancetype)attributeFlatteningTransform;

// A transform that removes the 'children' array from a parent node and puts
// its child nodes directly into it, where the keys are the tag names
// of element children.
// If a child with a specific tag name appears more than once in the parent node,
// then all children with that tag name will be grouped into an NSArray.
// Non-element children (e.g. text and CDATA nodes, comments and entity references)
// will be added with keys that correspond to their types (SCIXMLNodeType*) in the
// 'unnamedNodeKeys' dictionary. If no such key is found in the 'unnamedNodeKeys'
// dictionary, then an error is returned.
// This is a node transform.
+ (instancetype)childFlatteningTransformWithUnnamedNodeKeys:(NSDictionary<NSString *, NSString *> *_Nullable)unnamedNodeKeys;

// A transform that attempts to parse attribute values as certain types.
// This is an attribute transform.
// The type map is a dictionary of attribute names to type specifier strings.
// The following type specifier strings are currently supported:
//   null:       removes the key-value pair altogether, can be used for blacklisting filtering too
//   objc_bool:  "YES" is parsed as @(YES), "NO" is parsed as @(NO), otherwise return an error
//   cxx_bool:   "true" is parsed as @(true), "false" is parsed as @(false), otherwise return an error
//   bool:       objc_bool or cxx_bool, whichever works
//   decimal:    base-10 signed or unsigned integer, as parsed by strto[u]l(); error if unparseable
//   binary:     base-2 unsigned integer as parsed by strtoul(); may have 0b prefix; error if unparseable
//   octal:      base-8 unsigned integer as parsed by strtoul(); may have 0o prefix; error if unparseable
//   hex:        base-16 unsigned integer as parsed by strtoul(); may have 0x prefix; error if unparseable
//   integer:    any of decimal, binary, octal, hex, as specified by its prefix (0b, 0o, 0x or none)
//   floating:   base-10 floating-point number, as parsed by strtod(); error if unparseable
//   identity:   return the value verbatim, basically the identity transform, does nothing
//   escape_c:   escape the string as if it were written as a C string literal
//   unesc_c:    inverse of escape_c
//   escape_xml: escape the string as if it were to be placed inside an XML text element
//   unesc_xml:  inverse of escape_xml
//   timestamp:  UNIX time stamp (decimal integer or double), converted to NSDate; error if unparseable
//   date:       ISO-8601 formatted date, converted to NSDate; error if unparseable
//   base64:     Base-64 encoded string, converted to NSData; return error if encoding is invalid
+ (instancetype)attributeParserTransformWithTypeMap:(NSDictionary<NSString *, NSString *> *)typeMap;

// Similar to the attribute parser, but operates on immediate members of the node.
// This is a node transform.
+ (instancetype)memberParserTransformWithTypeMap:(NSDictionary<NSString *, NSString *> *)typeMap;

// Filtering attributes. The whitelisting variant keeps only the attributes of which
// the name is in the whitelist; the blacklisting one throws away only those of which
// the name is in the blacklist.
// These are attribute transforms.
+ (instancetype)attributeFilterTransformWithWhitelist:(NSArray<NSString *> *)whitelist;
+ (instancetype)attributeFilterTransformWithBlacklist:(NSArray<NSString *> *)blacklist;

// Similar to the attribute filters, but this one filters the immediate members of the node.
// These are node transforms.
+ (instancetype)memberFilterTransformWithWhitelist:(NSArray<NSString *> *)whitelist;
+ (instancetype)memberFilterTransformWithBlacklist:(NSArray<NSString *> *)blacklist;

@end
NS_ASSUME_NONNULL_END
