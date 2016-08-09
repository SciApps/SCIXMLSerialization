//
// SCIXMLSerialization.m
// SCIXMLSerialization
//
// Created by Arpad Goretity
// on 08/08/2016
//
// Copyright (C) SciApps.io, 2016.
//

#import <libxml/parser.h>
#import <libxml/tree.h>

#import "SCIXMLSerialization.h"


NSString *const SCIXMLNodeKeyType       = @"type";
NSString *const SCIXMLNodeKeyName       = @"name";
NSString *const SCIXMLNodeKeyChildren   = @"children";
NSString *const SCIXMLNodeKeyAttributes = @"attributes";
NSString *const SCIXMLNodeKeyText       = @"text";

NSString *const SCIXMLNodeTypeElement   = @"element";
NSString *const SCIXMLNodeTypeText      = @"text";
NSString *const SCIXMLNodeTypeComment   = @"comment";
NSString *const SCIXMLNodeTypeCDATA     = @"cdata";
NSString *const SCIXMLNodeTypeEntityRef = @"entityref";


NS_ASSUME_NONNULL_BEGIN
@interface SCIXMLSerialization ()

+ (NSDictionary *_Nullable)compactDictionary:(NSDictionary *)canonical
                               withTransform:(SCIXMLCompactingTransform *)transform
                                       error:(NSError *_Nullable __autoreleasing *_Nullable)error;

+ (NSDictionary *_Nullable)canonicalizeDictionary:(NSDictionary *)compacted
                                    withTransform:(SCIXMLCanonicalizingTransform *)transform
                                            error:(NSError *_Nullable __autoreleasing *_Nullable)error;

+ (NSDictionary *_Nullable)dictionaryWithNode:(xmlNode *)node
                                        error:(NSError *_Nullable __autoreleasing *_Nullable)error;

+ (xmlChar *_Nullable)xmlBufferWithDictionary:(NSDictionary *)dictionary
                                        error:(NSError *_Nullable __autoreleasing *_Nullable)error;

@end
NS_ASSUME_NONNULL_END


@implementation SCIXMLSerialization

#pragma mark - Parsing and Serialization Core (internal)

+ (NSDictionary *_Nullable)dictionaryWithNode:(xmlNode *)node
                                        error:(NSError *_Nullable __autoreleasing *_Nullable)error {

    NSMutableDictionary *dict = [NSMutableDictionary new];

    switch (node->type) {
    case XML_ELEMENT_NODE: {
        dict[SCIXMLNodeKeyType]       = SCIXMLNodeTypeElement;
        dict[SCIXMLNodeKeyName]       = @((const char *)node->name);
        dict[SCIXMLNodeKeyChildren]   = [NSMutableArray new];
        dict[SCIXMLNodeKeyAttributes] = [NSMutableDictionary new];

        // Collect attributes
        for (xmlAttr *attr = node->properties; attr != NULL; attr = attr->next) {
            xmlChar *value = xmlGetProp(node, attr->name);
            dict[SCIXMLNodeKeyAttributes][@((const char *)attr->name)] = @((const char *)value);
            xmlFree(value);
        }

        // Collect children
        for (xmlNode *child = node->children; child != NULL; child = child->next) {
            NSError *childError = nil;
            NSDictionary *childDict = [self dictionaryWithNode:child error:&childError];

            if (childError) {
                if (error) {
                    *error = childError;
                }
                return nil;
            }

            [dict[SCIXMLNodeKeyChildren] addObject:childDict];
        }

        break;
    }
    case XML_TEXT_NODE: {
        dict[SCIXMLNodeKeyType] = SCIXMLNodeTypeText;
        dict[SCIXMLNodeKeyText] = @((const char *)node->content);
        break;
    }
    case XML_COMMENT_NODE: {
        dict[SCIXMLNodeKeyType] = SCIXMLNodeTypeComment;
        dict[SCIXMLNodeKeyText] = @((const char *)node->content);
        break;
    }
    case XML_CDATA_SECTION_NODE: {
        dict[SCIXMLNodeKeyType] = SCIXMLNodeTypeCDATA;
        dict[SCIXMLNodeKeyText] = @((const char *)node->content);
        break;
    }
    case XML_ENTITY_REF_NODE: {
        dict[SCIXMLNodeKeyType] = SCIXMLNodeTypeEntityRef;
        dict[SCIXMLNodeKeyName] = @((const char *)node->name);
        break;
    }
    default:
        // TODO(H2CO3): implement all node types (XML_*_NODE, enum xmlElementType)
        // E.g.: Entities, DTDs, ...
        if (error) {
            *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeUnimplemented
                                           format:@"unhandled node type: %d", (int)node->type];
        }
        return nil;
    }

    return dict;
}

+ (xmlChar *_Nullable)xmlBufferWithDictionary:(NSDictionary *)dictionary
                                        error:(NSError *_Nullable __autoreleasing *_Nullable)error {

    if (error) {
        *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeUnimplemented
                                       format:@"method not implemented: %s", __PRETTY_FUNCTION__];
    }
    return NULL;
}

#pragma mark - Compaction and Canonicalization (internal methods)

+ (NSDictionary *_Nullable)compactDictionary:(NSDictionary *)canonical
                               withTransform:(SCIXMLCompactingTransform *)transform
                                       error:(NSError *_Nullable __autoreleasing *_Nullable)error {

    if (error) {
        *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeUnimplemented
                                       format:@"method not implemented: %s", __PRETTY_FUNCTION__];
    }
    return nil;
}

+ (NSDictionary *_Nullable)canonicalizeDictionary:(NSDictionary *)compacted
                                    withTransform:(SCIXMLCanonicalizingTransform *)transform
                                            error:(NSError *_Nullable __autoreleasing *_Nullable)error {

    if (error) {
        *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeUnimplemented
                                       format:@"method not implemented: %s", __PRETTY_FUNCTION__];
    }
    return nil;
}

#pragma mark - Parsing/Deserialization from Strings

+ (NSDictionary *_Nullable)canonicalDictionaryWithXMLString:(NSString *)xml
                                                      error:(NSError *_Nullable __autoreleasing *_Nullable)error {

    NSData *data = [xml dataUsingEncoding:NSUTF8StringEncoding];

    if (data == nil) {
        if (error) {
            *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeNotUTF8Encoded];
        }
        return nil;
    }

    return [self canonicalDictionaryWithXMLData:data
                                          error:error];
}

+ (NSDictionary *_Nullable)compactedDictionaryWithXMLString:(NSString *)xml
                                        compactingTransform:(SCIXMLCompactingTransform *)transform
                                                      error:(NSError *_Nullable __autoreleasing *_Nullable)error {

    NSData *data = [xml dataUsingEncoding:NSUTF8StringEncoding];

    if (data == nil) {
        if (error) {
            *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeNotUTF8Encoded];
        }
        return nil;
    }

    return [self compactedDictionaryWithXMLData:data
                            compactingTransform:transform
                                          error:error];
}

#pragma mark - Parsing/Deserialization from Data

+ (NSDictionary *_Nullable)canonicalDictionaryWithXMLData:(NSData *)xml
                                                    error:(NSError *_Nullable __autoreleasing *_Nullable)error {

    if (error) {
        *error = nil;
    }

    xmlParserCtxt *parser = xmlNewParserCtxt();

    if (parser == NULL) {
        if (error) {
            *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeParserInit];
        }
        return nil;
    }

    xmlDoc *doc = xmlCtxtReadMemory(
        parser,
        xml.bytes,
        xml.length,
        "",
        "UTF-8",
        XML_PARSE_NOENT | XML_PARSE_NONET | XML_PARSE_NOBLANKS | XML_PARSE_HUGE
    );

    xmlFreeParserCtxt(parser); // does not free 'doc'

    if (doc == NULL) {
        if (error) {
            xmlError *rawErr = xmlCtxtGetLastError(parser);
            *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedInput
                                           format:@"line %d char %d: error %d: %s",
                                                  rawErr->line,
                                                  rawErr->int2,
                                                  rawErr->code,
                                                  rawErr->message];
        }
        return nil;
    }

    xmlNode *root = xmlDocGetRootElement(doc);
    NSDictionary *dict = [self dictionaryWithNode:root error:error];

    xmlFreeDoc(doc);

    return dict;
}

+ (NSDictionary *_Nullable)compactedDictionaryWithXMLData:(NSData *)xml
                                      compactingTransform:(SCIXMLCompactingTransform *)transform
                                                    error:(NSError *_Nullable __autoreleasing *_Nullable)error {

    NSDictionary *canonicalDict = [self canonicalDictionaryWithXMLData:xml
                                                                 error:error];

    if (canonicalDict == nil) {
        return nil;
    }

    return [self compactDictionary:canonicalDict
                     withTransform:transform
                             error:error];
}

#pragma mark - Generating/Serialization into Strings

+ (NSString *_Nullable)xmlStringWithCanonicalDictionary:(NSDictionary *)dictionary
                                                  error:(NSError *_Nullable __autoreleasing *_Nullable)error {

    if (error) {
        *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeUnimplemented
                                       format:@"method not implemented: %s", __PRETTY_FUNCTION__];
    }
    return nil;
}

+ (NSString *_Nullable)xmlStringWithCompactedDictionary:(NSDictionary *)dictionary
                                canonicalizingTransform:(SCIXMLCanonicalizingTransform *)transform
                                                  error:(NSError *_Nullable __autoreleasing *_Nullable)error {

    if (error) {
        *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeUnimplemented
                                       format:@"method not implemented: %s", __PRETTY_FUNCTION__];
    }
    return nil;
}

#pragma mark - Generating/Serialization into Binary Data

+ (NSData *_Nullable)xmlDataWithCanonicalDictionary:(NSDictionary *)dictionary
                                              error:(NSError *_Nullable __autoreleasing *_Nullable)error {

    if (error) {
        *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeUnimplemented
                                       format:@"method not implemented: %s", __PRETTY_FUNCTION__];
    }
    return nil;
}

+ (NSData *_Nullable)xmlDataWithCompactedDictionary:(NSDictionary *)dictionary
                            canonicalizingTransform:(SCIXMLCanonicalizingTransform *)transform
                                              error:(NSError *_Nullable __autoreleasing *_Nullable)error {

    if (error) {
        *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeUnimplemented
                                       format:@"method not implemented: %s", __PRETTY_FUNCTION__];
    }
    return nil;
}

@end
