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

NS_ASSUME_NONNULL_BEGIN
@interface SCIXMLSerialization ()

+ (NSDictionary *)compactDictionary:(NSDictionary *)canonical
                      withTransform:(SCIXMLCompactingTransform *)transform
                              error:(NSError *_Nullable __autoreleasing *_Nullable)error;

+ (NSDictionary *)canonicalizeDictionary:(NSDictionary *)compacted
                           withTransform:(SCIXMLCanonicalizingTransform *)transform
                                   error:(NSError *_Nullable __autoreleasing *_Nullable)error;

+ (NSDictionary *)dictionaryWithNode:(xmlNode *)node
                               error:(NSError *_Nullable __autoreleasing *_Nullable)error;

@end
NS_ASSUME_NONNULL_END


@implementation SCIXMLSerialization

#pragma mark - Internal methods

+ (NSDictionary *)dictionaryWithNode:(xmlNode *)node
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

+ (NSDictionary *)compactDictionary:(NSDictionary *)canonical
                      withTransform:(SCIXMLCompactingTransform *)transform
                              error:(NSError *_Nullable __autoreleasing *_Nullable)error {

    if (error) {
        *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeUnimplemented
                                       format:@"method not implemented: %s", __PRETTY_FUNCTION__];
    }
    return nil;
}

+ (NSDictionary *)canonicalizeDictionary:(NSDictionary *)compacted
                           withTransform:(SCIXMLCanonicalizingTransform *)transform
                                   error:(NSError *_Nullable __autoreleasing *_Nullable)error {

    if (error) {
        *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeUnimplemented
                                       format:@"method not implemented: %s", __PRETTY_FUNCTION__];
    }
    return nil;
}

#pragma mark - Parsing/Deserialization from Strings

+ (NSDictionary *)canonicalDictionaryWithXMLString:(NSString *)xml
                                             error:(NSError *_Nullable __autoreleasing *_Nullable)error {

    NSData *data = [xml dataUsingEncoding:NSUTF8StringEncoding];

    if (data == nil) {
        if (error) {
            *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeNotUTF8Encoded];
        }
        return nil;
    }

    return [self canonicalDictionaryWithXMLData:data error:error];
}

+ (NSDictionary *)compactedDictionaryWithXMLString:(NSString *)xml
                               compactingTransform:(SCIXMLCompactingTransform *)transform
                                             error:(NSError *_Nullable __autoreleasing *_Nullable)error {

    if (error) {
        *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeUnimplemented
                                       format:@"method not implemented: %s", __PRETTY_FUNCTION__];
    }
    return nil;
}

#pragma mark - Parsing/Deserialization from Data

+ (NSDictionary *)canonicalDictionaryWithXMLData:(NSData *)xml
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
            *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedInput];
        }
        return nil;
    }

    xmlNode *root = xmlDocGetRootElement(doc);
    NSDictionary *dict = [self dictionaryWithNode:root error:error];

    xmlFreeDoc(doc);

    return dict;
}

+ (NSDictionary *)compactedDictionaryWithXMLData:(NSString *)xml
                             compactingTransform:(SCIXMLCompactingTransform *)transform
                                           error:(NSError *_Nullable __autoreleasing *_Nullable)error {

    if (error) {
        *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeUnimplemented
                                       format:@"method not implemented: %s", __PRETTY_FUNCTION__];
    }
    return nil;
}

#pragma mark - Generating/Serialization into Strings

+ (NSString *)xmlStringWithCanonicalDictionary:(NSDictionary *)dictionary
                                         error:(NSError *_Nullable __autoreleasing *_Nullable)error {

    if (error) {
        *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeUnimplemented
                                       format:@"method not implemented: %s", __PRETTY_FUNCTION__];
    }
    return nil;
}

+ (NSString *)xmlStringWithCompactedDictionary:(NSDictionary *)dictionary
                       canonicalizingTransform:(SCIXMLCanonicalizingTransform *)transform
                                         error:(NSError *_Nullable __autoreleasing *_Nullable)error {

    if (error) {
        *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeUnimplemented
                                       format:@"method not implemented: %s", __PRETTY_FUNCTION__];
    }
    return nil;
}

#pragma mark - Generating/Serialization into Binary Data

+ (NSData *)xmlDataWithCanonicalDictionary:(NSDictionary *)dictionary
                                     error:(NSError *_Nullable __autoreleasing *_Nullable)error {

    if (error) {
        *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeUnimplemented
                                       format:@"method not implemented: %s", __PRETTY_FUNCTION__];
    }
    return nil;
}

+ (NSData *)xmlDataWithCompactedDictionary:(NSDictionary *)dictionary
                   canonicalizingTransform:(SCIXMLCanonicalizingTransform *)transform
                                     error:(NSError *_Nullable __autoreleasing *_Nullable)error {

    if (error) {
        *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeUnimplemented
                                       format:@"method not implemented: %s", __PRETTY_FUNCTION__];
    }
    return nil;
}

@end
