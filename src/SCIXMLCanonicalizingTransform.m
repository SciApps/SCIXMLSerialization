//
// SCIXMLCanonicalizingTransform.h
// SCIXMLSerialization
//
// Created by Arpad Goretity
// on 26/08/2016
//
// Copyright (C) SciApps.io, 2016.
//

#import "SCIXMLCanonicalizingTransform.h"


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

+ (instancetype)memberToAttributeTransformWithTypeMap:(NSDictionary *)typeMap {
    NSAssert(NO, @"Unimplemented");
    return nil;
}

+ (instancetype)memberToChildTransformWithTypeMap:(NSDictionary *)typeMap {
    NSAssert(NO, @"Unimplemented");
    return nil;
}

@end
