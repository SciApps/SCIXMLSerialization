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

+ (instancetype)memberToAttributeTransformWithTypeMap:(NSDictionary *)typeMap;
+ (instancetype)memberToChildTransformWithTypeMap:(NSDictionary *)typeMap;

@end
NS_ASSUME_NONNULL_END
