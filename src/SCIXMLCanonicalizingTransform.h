//
// SCIXMLCanonicalizingTransform.h
// SCIXMLSerialization
//
// Created by Arpad Goretity
// on 14/08/2016
//
// Copyright (C) SciApps.io, 2016.
//

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const SCIXMLTempKeyType;
FOUNDATION_EXPORT NSString *const SCIXMLTempKeyName;
FOUNDATION_EXPORT NSString *const SCIXMLTempKeyChild;
FOUNDATION_EXPORT NSString *const SCIXMLTempKeyAttrs;

FOUNDATION_EXPORT NSString *const SCIXMLTmpTypeBranchElement;
FOUNDATION_EXPORT NSString *const SCIXMLTmpTypeLeafElement;
FOUNDATION_EXPORT NSString *const SCIXMLTmpTypeTextNode;


@protocol SCIXMLCanonicalizingTransform <NSObject, NSCopying>

// These properties must return a value upon successful completion.
// They must return nil to indicate a failure, and if the out error parameter is not
// NULL, they must set the pointed pointer to a pointer to an instance of NSError.
@property (nonatomic, copy          ) NSString *_Nullable (^typeProvider)(id, NSError *__autoreleasing *);
@property (nonatomic, copy, nullable) NSString *_Nullable (^nameProvider)(id, NSError *__autoreleasing *);

@property (nonatomic, copy, nullable) NSSet<NSString *> *_Nullable (^attributeProvider)(id, NSError *__autoreleasing *);
@property (nonatomic, copy, nullable) NSArray *_Nullable (^childProvider)(id, NSError *__autoreleasing *);

@property (nonatomic, copy, nullable) NSString *_Nullable (^textProvider)(id, NSError *__autoreleasing *);
@property (nonatomic, copy, nullable) NSString *_Nullable (^attributeTransform)(id, NSString *, NSError *__autoreleasing *);

- (id)copy;

@end
NS_ASSUME_NONNULL_END


NS_ASSUME_NONNULL_BEGIN
@interface SCIXMLCanonicalizingTransform : NSObject <SCIXMLCanonicalizingTransform>

@property (nonatomic, copy          ) NSString *_Nullable (^typeProvider)(id, NSError *__autoreleasing *);
@property (nonatomic, copy, nullable) NSString *_Nullable (^nameProvider)(id, NSError *__autoreleasing *);

@property (nonatomic, copy, nullable) NSSet<NSString *> *_Nullable (^attributeProvider)(id, NSError *__autoreleasing *);
@property (nonatomic, copy, nullable) NSArray *_Nullable (^childProvider)(id, NSError *__autoreleasing *);

@property (nonatomic, copy, nullable) NSString *_Nullable (^textProvider)(id, NSError *__autoreleasing *);
@property (nonatomic, copy, nullable) NSString *_Nullable (^attributeTransform)(id, NSString *, NSError *__autoreleasing *);

// Designated initializer
- (instancetype)initWithTypeProvider:(NSString *_Nullable (^)(id, NSError *__autoreleasing *))typeProvider
                        nameProvider:(NSString *_Nullable (^_Nullable)(id, NSError *__autoreleasing *))nameProvider
                   attributeProvider:(NSSet<NSString *> *_Nullable (^_Nullable)(id, NSError *__autoreleasing *))attributeProvider
                       childProvider:(NSArray *_Nullable (^_Nullable)(id, NSError *__autoreleasing *))childProvider
                        textProvider:(NSString *_Nullable (^_Nullable)(id, NSError *__autoreleasing *))textProvider
                  attributeTransform:(NSString *_Nullable (^_Nullable)(id, NSString *, NSError *__autoreleasing *))attributeTransform
                            NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithTypeProvider:(NSString *_Nullable (^)(id, NSError *__autoreleasing *))typeProvider;

- (instancetype _Nullable)init;

//
// Convenience factory methods for common use cases
//

// General, all-customizable convenience factory method
+ (instancetype)transformWithTypeProvider:(NSString *_Nullable (^)(id, NSError *__autoreleasing *))typeProvider
                             nameProvider:(NSString *_Nullable (^_Nullable)(id, NSError *__autoreleasing *))nameProvider
                        attributeProvider:(NSSet<NSString *> *_Nullable (^_Nullable)(id, NSError *__autoreleasing *))attributeProvider
                            childProvider:(NSArray *_Nullable (^_Nullable)(id, NSError *__autoreleasing *))childProvider
                             textProvider:(NSString *_Nullable (^_Nullable)(id, NSError *__autoreleasing *))textProvider
                       attributeTransform:(NSString *_Nullable (^_Nullable)(id, NSString *, NSError *__autoreleasing *))attributeTransform;


// Transform for canonicalizing dictionaries in "natural" (convenience) format
// (through an intermediate, semi-canonical representation)
+ (id <SCIXMLCanonicalizingTransform>)transformForCanonicalizingNaturalDictionary;

#pragma mark - Other helper methods

// Prepares a root dictionary in "natural" format for canonicalization
+ (NSDictionary *_Nullable)semiCanonicalDictionaryWithNaturalDictionary:(NSDictionary *)root
                                                                  error:(NSError *__autoreleasing *)error;

@end

NS_ASSUME_NONNULL_END
