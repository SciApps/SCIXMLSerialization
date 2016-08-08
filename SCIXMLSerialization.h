//
// SCIXMLSerialization.h
// SCIXMLSerialization
//
// Created by Arpad Goretity
// on 08/08/2016
//
// Copyright (C) SciApps.io, 2016.
//

#import <Foundation/Foundation.h>

#import "SCIXMLError.h"


@class SCIXMLCompactingTransform;
@class SCIXMLCanonicalizingTransform;


NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const SCIXMLNodeKeyType;
FOUNDATION_EXPORT NSString *const SCIXMLNodeKeyName;
FOUNDATION_EXPORT NSString *const SCIXMLNodeKeyChildren;
FOUNDATION_EXPORT NSString *const SCIXMLNodeKeyAttributes;
FOUNDATION_EXPORT NSString *const SCIXMLNodeKeyText;

FOUNDATION_EXPORT NSString *const SCIXMLNodeTypeElement;
FOUNDATION_EXPORT NSString *const SCIXMLNodeTypeText;


@interface SCIXMLSerialization : NSObject

#pragma mark - Parsing/Deserialization from Strings

+ (NSDictionary *)canonicalDictionaryWithXMLString:(NSString *)xml
                                             error:(NSError *_Nullable __autoreleasing *_Nullable)error;

+ (NSDictionary *)compactedDictionaryWithXMLString:(NSString *)xml
                               compactingTransform:(SCIXMLCompactingTransform *)transform
                                             error:(NSError *_Nullable __autoreleasing *_Nullable)error;

#pragma mark - Parsing/Deserialization from Binary Data

+ (NSDictionary *)canonicalDictionaryWithXMLData:(NSData *)xml
                                           error:(NSError *_Nullable __autoreleasing *_Nullable)error;

+ (NSDictionary *)compactedDictionaryWithXMLData:(NSData *)xml
                             compactingTransform:(SCIXMLCompactingTransform *)transform
                                           error:(NSError *_Nullable __autoreleasing *_Nullable)error;

#pragma mark - Generating/Serialization into Strings

+ (NSString *)xmlStringWithCanonicalDictionary:(NSDictionary *)dictionary
                                         error:(NSError *_Nullable __autoreleasing *_Nullable)error;

+ (NSString *)xmlStringWithCompactedDictionary:(NSDictionary *)dictionary
                       canonicalizingTransform:(SCIXMLCanonicalizingTransform *)transform
                                         error:(NSError *_Nullable __autoreleasing *_Nullable)error;

#pragma mark - Generating/Serialization into Binary Data

+ (NSData *)xmlDataWithCanonicalDictionary:(NSDictionary *)dictionary
                                     error:(NSError *_Nullable __autoreleasing *_Nullable)error;

+ (NSData *)xmlDataWithCompactedDictionary:(NSDictionary *)dictionary
                   canonicalizingTransform:(SCIXMLCanonicalizingTransform *)transform
                                     error:(NSError *_Nullable __autoreleasing *_Nullable)error;


@end

NS_ASSUME_NONNULL_END
