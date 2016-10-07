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

// Keys for retrieving the name and the value of an attribute from within an attribute transform
FOUNDATION_EXPORT NSString *const SCIXMLAttributeTransformKeyName;
FOUNDATION_EXPORT NSString *const SCIXMLAttributeTransformKeyValue;

// Parser type strings
FOUNDATION_EXPORT NSString *const SCIXMLParserTypeError;
FOUNDATION_EXPORT NSString *const SCIXMLParserTypeNull;
FOUNDATION_EXPORT NSString *const SCIXMLParserTypeIdentity;
FOUNDATION_EXPORT NSString *const SCIXMLParserTypeObjCBool;
FOUNDATION_EXPORT NSString *const SCIXMLParserTypeCXXBool;
FOUNDATION_EXPORT NSString *const SCIXMLParserTypeBool;
FOUNDATION_EXPORT NSString *const SCIXMLParserTypeDecimal;
FOUNDATION_EXPORT NSString *const SCIXMLParserTypeBinary;
FOUNDATION_EXPORT NSString *const SCIXMLParserTypeOctal;
FOUNDATION_EXPORT NSString *const SCIXMLParserTypeHex;
FOUNDATION_EXPORT NSString *const SCIXMLParserTypeInteger;
FOUNDATION_EXPORT NSString *const SCIXMLParserTypeFloating;
FOUNDATION_EXPORT NSString *const SCIXMLParserTypeNumber;
FOUNDATION_EXPORT NSString *const SCIXMLParserTypeEscapeC;
FOUNDATION_EXPORT NSString *const SCIXMLParserTypeUnescapeC;
FOUNDATION_EXPORT NSString *const SCIXMLParserTypeEscapeXML;
FOUNDATION_EXPORT NSString *const SCIXMLParserTypeUnescapeXML;
FOUNDATION_EXPORT NSString *const SCIXMLParserTypeTimestamp;
FOUNDATION_EXPORT NSString *const SCIXMLParserTypeDate;
FOUNDATION_EXPORT NSString *const SCIXMLParserTypeBase64;


@protocol SCIXMLCompactingTransform <NSObject, NSCopying>

@property (nonatomic, copy, nullable) id _Nullable (^typeTransform)(id);
@property (nonatomic, copy, nullable) id _Nullable (^nameTransform)(id);
@property (nonatomic, copy, nullable) id _Nullable (^textTransform)(id);
@property (nonatomic, copy, nullable) id _Nullable (^attributeTransform)(id);
@property (nonatomic, copy, nullable) id           (^nodeTransform)(id);

// NSKeyValueCoding is an informal protocol, and as such,
// we don't get the valueForKey: and setValue:forKey: methods
// by conforming to the NSObject protocol. So, this explicit
// declaration of the methods is necessary.
// Similarly, -copy is not found in either <NSObject> or <NSCopying>.
- (id _Nullable)valueForKey:(NSString *)key;
- (void)setValue:(id _Nullable)value forKey:(NSString *)key;
- (id)copy;

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
@property (nonatomic, copy, nullable) id _Nullable (^typeTransform)(id);
@property (nonatomic, copy, nullable) id _Nullable (^nameTransform)(id);
@property (nonatomic, copy, nullable) id _Nullable (^textTransform)(id);
@property (nonatomic, copy, nullable) id _Nullable (^attributeTransform)(id);
@property (nonatomic, copy, nullable) id           (^nodeTransform)(id);

// Designated initializer.
// Note: -init just calls this with all nil sub-transforms,
// so -init and +new result in essentially an (inefficient) identity transform.
- (instancetype)initWithTypeTransform:(id _Nullable (^_Nullable)(id))typeTransform
                        nameTransform:(id _Nullable (^_Nullable)(id))nameTransform
                        textTransform:(id _Nullable (^_Nullable)(id))textTransform
                   attributeTransform:(id _Nullable (^_Nullable)(id))attributeTransform
                        nodeTransform:(id           (^_Nullable)(id))nodeTransform NS_DESIGNATED_INITIALIZER;

// Combines two transforms. When the conflict resolution strategy is 'Compose',
// the returned transform is equivalent with (lhs o rhs),
// i.e. the right-hand-side is applied first.
+ (id <SCIXMLCompactingTransform>)combineTransform:(id <SCIXMLCompactingTransform>)lhs
                                     withTransform:(id <SCIXMLCompactingTransform>)rhs
                        conflictResolutionStrategy:(SCIXMLTransformCombinationConflictResolutionStrategy)strategy;

// Combines an arbitrary number of transforms using the same conflict resolution strategy.
// The combining process works from right to left, i.e. the first transform in the array
// will be the rightmost/innermost one, so it is applied first. This is done so that
// the transform array can be imagined like a pipeline that the tree flows through.
+ (id <SCIXMLCompactingTransform>)combineTransforms:(NSArray<id<SCIXMLCompactingTransform>> *)transforms
                         conflictResolutionStrategy:(SCIXMLTransformCombinationConflictResolutionStrategy)strategy;

//
// Convenience factory methods for common use cases
//

// General, all-customizable convenience factory method
+ (instancetype)transformWithTypeTransform:(id _Nullable (^_Nullable)(id))typeTransform
                             nameTransform:(id _Nullable (^_Nullable)(id))nameTransform
                             textTransform:(id _Nullable (^_Nullable)(id))textTransform
                        attributeTransform:(id _Nullable (^_Nullable)(id))attributeTransform
                             nodeTransform:(id           (^_Nullable)(id))nodeTransform;

// A transform that simplifies canonical trees in a generalized manner
// so that usual XML documents are easier to use. It is composed of the attribute flattening
// transform, the element type filtering transform, the text node flattening transform,
// the child flattening transform with the specified grouping map and the member parser
// transform with the specified type map and fallback, in this order.
+ (instancetype)basicCompactingTransformWithChildFlatteningGroupingMap:(NSDictionary<NSString *, NSArray<NSString *> *> *_Nullable)groupingMap
                                                attributeParserTypeMap:(NSDictionary<NSString *, id> *_Nullable)attributeParserTypeMap
                                               attributeParserFallback:(id _Nullable)attributeParserFallback
                                                   memberParserTypeMap:(NSDictionary<NSString *, id> *_Nullable)memberParserTypeMap
                                                  memberParserFallback:(id _Nullable)memberParserFallback;

// A transform that removes the 'attributes' dictionary and adds its contents
// directly to the node being transformed.
// If the attribute name already exists in the node as a key, an error is returned.
// This is a node transform.
+ (instancetype)attributeFlatteningTransform;

// A transform that removes the 'children' array from a parent node and puts
// its child nodes directly into it, where the keys are the tag names
// of element children. The children will also have their name removed.
// Children of which the name exists in the groupingMap for the key that is the
// node name of their parent will be added as members of an array for the
// child name as the key in the parent node dictionary, regardless of their count
// (i.e. even zero or one child will be added to an array).
// If a child element of a particular tag name is encountered multiple times, then:
//   * if the tag name is in the groupingMap, as described above, then
//     grouping in an array occurs
//   * otherwise, an error about duplicate children is returned.
// If 'groupingMap' is nil, it is assumed to be an empty dictionary.
// TODO(H2CO3): document behavior when encountering a malformed tree
// This is a node transform.
+ (instancetype)childFlatteningTransformWithGroupingMap:(NSDictionary<NSString *, NSArray<NSString *> *> *_Nullable)groupingMap;

// This transform flattens text and CDATA nodes: it replaces them with just their string content.
//
// For example, the following XML:
//
//    <value>Foo</value>
//
// would be represented in canonical form as:
//
//    {
//      name = value;
//      children = (
//        {
//          text = Foo;
//        }
//      );
//    }
//
// But after this transform, it would simplify to:
//
//   {
//     name = value;
//     children = (
//       "Foo"
//     );
//   }
//
// This is a node transform.
+ (instancetype)textNodeFlatteningTransform;

// Removes all comment nodes from the tree.
// This is a node transform.
+ (instancetype)commentFilterTransform;

// Removes the 'type' key from element nodes.
// This is a type transform.
+ (instancetype)elementTypeFilterTransform;

// A transform that attempts to parse attribute values as certain types.
// This is an attribute transform.
// The type map is a dictionary of attribute names to type specifier strings
// or custom transform blocks.
//
// Custom transform blocks must have the signature 'id _Nullable (^)(NSString *name, id value)'.
// The first parameter of the transform block is the name of the attribute,
// while its second parameter is the corresponding value. Neither the name or the value
// will be nil when passed to a transform block. Transform blocks may return a valid object,
// or nil (for omission of the attribute), or an instance of NSError (to signal an error).
//
// For attributes of which the name is not contained in the type specification dictionary, the
// fallback will be called, appropriately interpreted as a type key or as a block.
//
// The following type specifier strings are currently supported:
//   Error:       should be used for returning an error for unspecified attributes
//   Null:        removes the key-value pair altogether, can be used for blacklisting filtering too
//   Identity:    return the value verbatim, basically the identity transform, does nothing
//   ObjCBool:    "YES" is parsed as @(YES), "NO" is parsed as @(NO), otherwise return an error
//   CXXBool:     "true" is parsed as @(true), "false" is parsed as @(false), otherwise return an error
//   Bool:        ObjCBool or CXXBool, whichever works
//   Decimal:     base-10 signed or unsigned integer, as parsed by strto[u]ll(); error if unparseable
//   Binary:      base-2 unsigned integer as parsed by strtoull(); may have 0b prefix; error if unparseable
//   Octal:       base-8 unsigned integer as parsed by strtoull(); may have 0o prefix; error if unparseable
//   Hex:         base-16 unsigned integer as parsed by strtoull(); may have 0x prefix; error if unparseable
//   Integer:     any of Decimal, Binary, Octal, Hex, as specified by its prefix (0b, 0o, 0x or none)
//   Floating:    base-10 floating-point number, as parsed by strtod(); error if unparseable
//   Number:      Integer or Floating
//   EscapeC:     escape the string as if it were written as a C string literal
//   UnescapeC:   inverse of EscapeC
//   EscapeXML:   escape the string as if it were to be placed inside an XML text element
//   UnescapeXML: inverse of EscapeXML
//   Timestamp:   Time stamp since midnight 01/01/1970 UTC, as integer or double,
//                converted to an instance of NSDate;
//                an error is returned if the string is unparseable
//   Date:        ISO-8601 formatted date, converted to an instance of NSDate;
//                with or without fractional seconds, with or without a time zone
//                (missing timezone is assumed to be UTC);
//                an error is returned if the string is unparseable or if the date is invalid
//   Base64:      Base-64 encoded string, converted to NSData; return error if encoding is invalid
+ (instancetype)attributeParserTransformWithTypeMap:(NSDictionary<NSString *, id> *)typeMap
                                           fallback:(id)fallback;

// Similar to the attribute parser, but operates on immediate members of the node.
// This is a node transform.
+ (instancetype)memberParserTransformWithTypeMap:(NSDictionary<NSString *, id> *)typeMap
                                        fallback:(id)fallback;

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

#pragma mark - Other helper methods

+ (NSDictionary *)naturalDictionaryWithCompactedDictionary:(NSDictionary *)compactedDictionary;

@end
NS_ASSUME_NONNULL_END
