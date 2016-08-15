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
@protocol SCIXMLCompactingTransform <NSObject>

@property (nonatomic, copy, nullable) id _Nullable (^typeTransform)(NSString *);
@property (nonatomic, copy, nullable) id _Nullable (^nameTransform)(NSString *);
@property (nonatomic, copy, nullable) id _Nullable (^attributeTransform)(NSString *);
@property (nonatomic, copy, nullable) id _Nullable (^textTransform)(NSString *);
@property (nonatomic, copy, nullable) id _Nullable (^nodeTransform)(NSDictionary *);

@end
NS_ASSUME_NONNULL_END


NS_ASSUME_NONNULL_BEGIN
@interface SCIXMLCompactingTransform : NSObject <SCIXMLCompactingTransform>

@property (nonatomic, copy, nullable) id _Nullable (^typeTransform)(NSString *);
@property (nonatomic, copy, nullable) id _Nullable (^nameTransform)(NSString *);
@property (nonatomic, copy, nullable) id _Nullable (^attributeTransform)(NSString *);
@property (nonatomic, copy, nullable) id _Nullable (^textTransform)(NSString *);
@property (nonatomic, copy, nullable) id _Nullable (^nodeTransform)(NSDictionary *);

- (instancetype)initWithTypeTransform:(id _Nullable (^_Nullable)(NSString *))typeTransform
                        nameTransform:(id _Nullable (^_Nullable)(NSString *))nameTransform
                   attributeTransform:(id _Nullable (^_Nullable)(NSString *))attributeTransform
                        textTransform:(id _Nullable (^_Nullable)(NSString *))textTransform
                        nodeTransform:(id _Nullable (^_Nullable)(NSDictionary *))nodeTransform NS_DESIGNATED_INITIALIZER;

+ (instancetype)transformWithTypeTransform:(id _Nullable (^_Nullable)(NSString *))typeTransform
                             nameTransform:(id _Nullable (^_Nullable)(NSString *))nameTransform
                        attributeTransform:(id _Nullable (^_Nullable)(NSString *))attributeTransform
                             textTransform:(id _Nullable (^_Nullable)(NSString *))textTransform
                             nodeTransform:(id _Nullable (^_Nullable)(NSDictionary *))nodeTransform;

@end
NS_ASSUME_NONNULL_END
