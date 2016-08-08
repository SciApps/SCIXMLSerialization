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


NSString *const SCIXMLNodeKeyType = @"type";
NSString *const SCIXMLNodeKeyName = @"name";
NSString *const SCIXMLNodeKeyChildren = @"children";
NSString *const SCIXMLNodeKeyAttributes = @"attributes";
NSString *const SCIXMLNodeKeyText = @"text";

NSString *const SCIXMLNodeTypeElement = @"element";
NSString *const SCIXMLNodeTypeText = @"text";

NS_ASSUME_NONNULL_BEGIN
@interface SCIXMLSerialization ()

+ (NSDictionary *)compactDictionary:(NSDictionary *)canonical
					  withTransform:(SCIXMLCompactingTransform *)transform
							  error:(NSError *__autoreleasing *_Nullable)error;

+ (NSDictionary *)canonicalizeDictionary:(NSDictionary *)compacted
						   withTransform:(SCIXMLCanonicalizingTransform *)transform
								   error:(NSError *__autoreleasing *_Nullable)error;

+ (NSDictionary *)dictionaryWithNode:(xmlNode *)xNode;

@end
NS_ASSUME_NONNULL_END


@implementation SCIXMLSerialization

#pragma mark - Internal methods

+ (NSDictionary *)dictionaryWithNode:(xmlNode *)node {
	NSMutableDictionary *dict = [NSMutableDictionary new];

	switch (node->type) {
	case XML_ELEMENT_NODE: {
		dict[SCIXMLNodeKeyType] = SCIXMLNodeTypeElement;
		dict[SCIXMLNodeKeyName] = @((const char *)node->name);
		dict[SCIXMLNodeKeyChildren] = [NSMutableArray new];
		dict[SCIXMLNodeKeyAttributes] = [NSMutableDictionary new];

		// Collect attributes
		for (xmlAttr *attr = node->properties; attr != NULL; attr = attr->next) {
			xmlChar *value = xmlGetProp(node, attr->name);
			dict[SCIXMLNodeKeyAttributes][@((const char *)attr->name)] = @((const char *)value);
			xmlFree(value);
		}

		// Collect children
		for (xmlNode *child = node->children; child != NULL; child = child->next) {
			[dict[SCIXMLNodeKeyChildren] addObject:[self dictionaryWithNode:child]];
		}

		break;
	}
	case XML_TEXT_NODE: {
		dict[SCIXMLNodeKeyType] = SCIXMLNodeTypeText;
		dict[SCIXMLNodeKeyText] = @((const char *)node->content);
		break;
	}
	default:
		// TODO(H2CO3): do something?
		// Especially w.r.t. XML_CDATA_SECTION_NODE, XML_COMMENT_NODE, XML_DTD_NODE, etc.
		break;
	}

	return dict;
}

+ (NSDictionary *)compactDictionary:(NSDictionary *)canonical
					  withTransform:(SCIXMLCompactingTransform *)transform
							  error:(NSError *__autoreleasing *_Nullable)error {

	NSAssert(NO, @"Unimplemented");
	return nil;
}

+ (NSDictionary *)canonicalizeDictionary:(NSDictionary *)compacted
						   withTransform:(SCIXMLCanonicalizingTransform *)transform
								   error:(NSError *__autoreleasing *_Nullable)error {

	NSAssert(NO, @"Unimplemented");
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

	NSAssert(NO, @"Unimplemented");
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
		XML_PARSE_NOENT | XML_PARSE_NONET
	);

	xmlFreeParserCtxt(parser); // does not free 'doc'

	if (doc == NULL) {
		if (error) {
			*error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedInput];
		}
		return nil;
	}

	xmlNode *root = xmlDocGetRootElement(doc);
	NSDictionary *dict = [self dictionaryWithNode:root];

	xmlFreeDoc(doc);

	return dict;
}

+ (NSDictionary *)compactedDictionaryWithXMLData:(NSString *)xml
							 compactingTransform:(SCIXMLCompactingTransform *)transform
										   error:(NSError *_Nullable __autoreleasing *_Nullable)error {

	NSAssert(NO, @"Unimplemented");
	return nil;
}

#pragma mark - Generating/Serialization into Strings

+ (NSString *)xmlStringWithCanonicalDictionary:(NSDictionary *)dictionary
										 error:(NSError *_Nullable __autoreleasing *_Nullable)error {

	NSAssert(NO, @"Unimplemented");
	return nil;
}

+ (NSString *)xmlStringWithCompactedDictionary:(NSDictionary *)dictionary
					   canonicalizingTransform:(SCIXMLCanonicalizingTransform *)transform
										 error:(NSError *_Nullable __autoreleasing *_Nullable)error {

	NSAssert(NO, @"Unimplemented");
	return nil;
}

#pragma mark - Generating/Serialization into Binary Data

+ (NSData *)xmlDataWithCanonicalDictionary:(NSDictionary *)dictionary
									 error:(NSError *_Nullable __autoreleasing *_Nullable)error {

	NSAssert(NO, @"Unimplemented");
	return nil;
}

+ (NSData *)xmlDataWithCompactedDictionary:(NSDictionary *)dictionary
				   canonicalizingTransform:(SCIXMLCanonicalizingTransform *)transform
									 error:(NSError *_Nullable __autoreleasing *_Nullable)error {

	NSAssert(NO, @"Unimplemented");
	return nil;
}

@end
