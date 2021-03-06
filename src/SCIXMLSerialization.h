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

#import "NSError+SCIXMLSerialization.h"
#import "SCIXMLCompactingTransform.h"
#import "SCIXMLCanonicalizingTransform.h"


NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const SCIXMLNodeKeyType;
FOUNDATION_EXPORT NSString *const SCIXMLNodeKeyName;
FOUNDATION_EXPORT NSString *const SCIXMLNodeKeyChildren;
FOUNDATION_EXPORT NSString *const SCIXMLNodeKeyAttributes;
FOUNDATION_EXPORT NSString *const SCIXMLNodeKeyText;

// Implementation of methods should be provided for both parsing (reading)
// and serializing (writing) individual nodes of types identified by the
// following constants.
FOUNDATION_EXPORT NSString *const SCIXMLNodeTypeElement;
FOUNDATION_EXPORT NSString *const SCIXMLNodeTypeText;
FOUNDATION_EXPORT NSString *const SCIXMLNodeTypeComment;
FOUNDATION_EXPORT NSString *const SCIXMLNodeTypeCDATA;
FOUNDATION_EXPORT NSString *const SCIXMLNodeTypeEntityRef;


@interface SCIXMLSerialization : NSObject

#pragma mark - Parsing/Deserialization from Strings

+ (NSDictionary *_Nullable)canonicalDictionaryWithXMLString:(NSString *)xml
                                                      error:(NSError *__autoreleasing *)error;

+ (id _Nullable)compactedObjectWithXMLString:(NSString *)xml
                         compactingTransform:(id <SCIXMLCompactingTransform>)transform
                                       error:(NSError *__autoreleasing *)error;

#pragma mark - Parsing/Deserialization from Binary Data

+ (NSDictionary *_Nullable)canonicalDictionaryWithXMLData:(NSData *)xml
                                                    error:(NSError *__autoreleasing *)error;

+ (id _Nullable)compactedObjectWithXMLData:(NSData *)xml
                       compactingTransform:(id <SCIXMLCompactingTransform>)transform
                                     error:(NSError *__autoreleasing *)error;

#pragma mark - Generating/Serialization into Strings

+ (NSString *_Nullable)xmlStringWithCanonicalDictionary:(NSDictionary *)dictionary
                                            indentation:(NSString *_Nullable)indentation
                                                  error:(NSError *__autoreleasing *)error;

+ (NSString *_Nullable)xmlStringWithCompactedObject:(id)object
                            canonicalizingTransform:(id <SCIXMLCanonicalizingTransform>)transform
                                        indentation:(NSString *_Nullable)indentation
                                              error:(NSError *__autoreleasing *)error;

+ (NSString *_Nullable)xmlStringWithNaturalDictionary:(NSDictionary *)root
                                          indentation:(NSString *_Nullable)indentation
                                                error:(NSError *__autoreleasing *)error;

#pragma mark - Generating/Serialization into Binary Data

+ (NSData *_Nullable)xmlDataWithCanonicalDictionary:(NSDictionary *)dictionary
                                        indentation:(NSString *_Nullable)indentation
                                              error:(NSError *__autoreleasing *)error;

+ (NSData *_Nullable)xmlDataWithCompactedObject:(id)object
                        canonicalizingTransform:(id <SCIXMLCanonicalizingTransform>)transform
                                    indentation:(NSString *_Nullable)indentation
                                          error:(NSError *__autoreleasing *)error;

+ (NSData *_Nullable)xmlDataWithNaturalDictionary:(NSDictionary *)root
                                      indentation:(NSString *_Nullable)indentation
                                            error:(NSError *__autoreleasing *)error;

@end

NS_ASSUME_NONNULL_END
