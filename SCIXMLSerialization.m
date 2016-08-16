//
// SCIXMLSerialization.m
// SCIXMLSerialization
//
// Created by Arpad Goretity
// on 08/08/2016
//
// Copyright (C) SciApps.io, 2016.
//

#import <stdlib.h>

#import <libxml/parser.h>
#import <libxml/tree.h>
#import <libxml/xmlmemory.h>
#import <libxml/xmlwriter.h>

#import "SCIXMLSerialization.h"

// Make an NSString out of a const xlmChar *.
#define NSXS(str) (@((const char *)(str)))

// Make a const xmlChar * out of a const char *.
#define XS(str) ((const xmlChar *)(str))

// Get a property corresponding to a given key of a node dictionary.
// Returns nil if the property is not of the specified type.
#define GET_NODE_PROPERTY(getter, key, cls) ((cls *_Nullable)getter((key), cls.class))


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

+ (BOOL)libxmlUsesLibcAllocators;

// Returns a canonical dictionary
+ (NSDictionary *_Nullable)dictionaryWithNode:(xmlNode *)node
                                        error:(NSError *__autoreleasing *)error;

// Expects a canonical dictionary
+ (xmlChar *_Nullable)bufferWithDictionary:(NSDictionary *)dictionary
                               indentation:(NSString *_Nullable)indentation
                                    length:(NSUInteger *)length
                                     error:(NSError *__autoreleasing *)error;

+ (BOOL)writeXMLNode:(NSDictionary *)node
              writer:(xmlTextWriter *)writer
               error:(NSError *__autoreleasing *)error;

+ (id _Nullable (^)(NSString *, Class))propertyGetterWithNode:(NSDictionary *)node
                                                        error:(NSError *__autoreleasing *)error;

+ (NSDictionary *)nodeWriters;

+ (NSDictionary *)unsafeLoadNodeWriters;

+ (BOOL (^)(NSDictionary *, xmlTextWriter *, NSError *__autoreleasing *))nodeWriterWithFunction:(int (*)(xmlTextWriter *, const xmlChar *))writerFunction;

// Expects a canonical dictionary
+ (id _Nullable)compactDictionary:(NSDictionary *)canonical
                    withTransform:(id <SCIXMLCompactingTransform>)transform
                            error:(NSError *__autoreleasing *)error;

// Returns a canonical dictionary
+ (NSDictionary *_Nullable)canonicalizeObject:(id)compacted
                                withTransform:(id <SCIXMLCanonicalizingTransform>)transform
                                        error:(NSError *__autoreleasing *)error;

@end
NS_ASSUME_NONNULL_END


@implementation SCIXMLSerialization

#pragma mark - Memory management (internal)

+ (BOOL)libxmlUsesLibcAllocators {
    xmlFreeFunc xmlFreeFuncPtr = NULL;
    xmlMemGet(
        &xmlFreeFuncPtr, // free
        NULL,            // malloc
        NULL,            // realloc
        NULL             // strdup
    );
    return xmlFreeFuncPtr == &free;
}

#pragma mark - Parsing and Serialization Core (internal)

+ (NSDictionary *_Nullable)dictionaryWithNode:(xmlNode *)node
                                        error:(NSError *__autoreleasing *)error {

    NSParameterAssert(node);

    NSMutableDictionary *dict = [NSMutableDictionary new];

    switch (node->type) {
    case XML_ELEMENT_NODE: {
        dict[SCIXMLNodeKeyType]       = SCIXMLNodeTypeElement;
        dict[SCIXMLNodeKeyName]       = NSXS(node->name);
        dict[SCIXMLNodeKeyChildren]   = [NSMutableArray new];
        dict[SCIXMLNodeKeyAttributes] = [NSMutableDictionary new];

        // Collect attributes
        for (xmlAttr *attr = node->properties; attr != NULL; attr = attr->next) {
            xmlChar *value = xmlGetProp(node, attr->name);
            dict[SCIXMLNodeKeyAttributes][NSXS(attr->name)] = NSXS(value);
            xmlFree(value);
        }

        // Collect children
        for (xmlNode *child = node->children; child != NULL; child = child->next) {
            NSDictionary *childDict = [self dictionaryWithNode:child error:error];

            if (childDict == nil) {
                return nil;
            }

            [dict[SCIXMLNodeKeyChildren] addObject:childDict];
        }

        break;
    }
    case XML_TEXT_NODE: {
        dict[SCIXMLNodeKeyType] = SCIXMLNodeTypeText;
        dict[SCIXMLNodeKeyText] = NSXS(node->content);
        break;
    }
    case XML_COMMENT_NODE: {
        dict[SCIXMLNodeKeyType] = SCIXMLNodeTypeComment;
        dict[SCIXMLNodeKeyText] = NSXS(node->content);
        break;
    }
    case XML_CDATA_SECTION_NODE: {
        dict[SCIXMLNodeKeyType] = SCIXMLNodeTypeCDATA;
        dict[SCIXMLNodeKeyText] = NSXS(node->content);
        break;
    }
    case XML_ENTITY_REF_NODE: {
        dict[SCIXMLNodeKeyType] = SCIXMLNodeTypeEntityRef;
        dict[SCIXMLNodeKeyName] = NSXS(node->name);
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

+ (xmlChar *_Nullable)bufferWithDictionary:(NSDictionary *)dictionary
                               indentation:(NSString *_Nullable)indentation
                                    length:(NSUInteger *)length
                                     error:(NSError *__autoreleasing *)error {

    NSParameterAssert(dictionary);
    NSParameterAssert(length);

    *length = 0;
    if (error) {
        *error = nil;
    }

    //
    // Initialize buffer and writer
    // (this is gonna be long)
    //

    xmlBuffer *buf = xmlBufferCreate();
    if (buf == NULL) {
        if (error) {
            *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeWriterInit
                                           format:@"could not allocate buffer"];
        }
        return NULL;
    }

    xmlTextWriter *writer = xmlNewTextWriterMemory(buf, NO);
    if (writer == NULL) {
        if (error) {
            *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeWriterInit
                                           format:@"could not allocate writer"];
        }
        xmlBufferFree(buf);
        return NULL;
    }

    if (
        indentation
        &&
        (
            xmlTextWriterSetIndent(writer, 1) < 0
            ||
            xmlTextWriterSetIndentString(writer, XS(indentation.UTF8String)) < 0
        )
    ) {
        if (error) {
            *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeWriterInit
                                           format:@"could not set indentation"];
        }
        xmlFreeTextWriter(writer);
        xmlBufferFree(buf);
        return NULL;
    }

    if (xmlTextWriterStartDocument(writer, NULL, "UTF-8", NULL) < 0) {
        if (error) {
            *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeWriterInit
                                           format:@"could not start writing document"];
        }
        xmlFreeTextWriter(writer);
        xmlBufferFree(buf);
        return NULL;
    }

    // Try writing root element.
    // Move content out of buffer upon success.
    xmlChar *content = NULL;

    if ([self writeXMLNode:dictionary writer:writer error:error]) {
        if (xmlTextWriterEndDocument(writer) >= 0) {
            *length = xmlBufferLength(buf);
            content = xmlBufferDetach(buf);
        } else if (error) {
            *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeWriteFailed
                                           format:@"error writing XML for node %p", (void *)dictionary];
        }
    }

    // Clean up writer state
    xmlFreeTextWriter(writer);
    xmlBufferFree(buf);

    return content;
}

+ (BOOL)writeXMLNode:(NSDictionary *)node
              writer:(xmlTextWriter *)writer
               error:(NSError *__autoreleasing *)error {

    NSParameterAssert(node);
    NSParameterAssert(writer);

    id (^getter)(NSString *, Class) = [self propertyGetterWithNode:node error:error];

    NSString *nodeType = GET_NODE_PROPERTY(getter, SCIXMLNodeKeyType, NSString);
    if (nodeType == nil) {
        return NO;
    }

    BOOL (^nodeWriter)(
        NSDictionary *,
        xmlTextWriter *,
        NSError *__autoreleasing *
    );

    nodeWriter = self.nodeWriters[nodeType];
    if (nodeWriter == nil) {
        if (error) {
            *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeUnimplemented
                                           format:@"unhandled node type: %@", nodeType];
        }
        return NO;
    }

    return nodeWriter(node, writer, error);
}

+ (id _Nullable (^)(NSString *, Class))propertyGetterWithNode:(NSDictionary *)node
                                                        error:(NSError *__autoreleasing *)error {

    NSParameterAssert(node);

    // This function attempts to retrieve a value from the node dictionary,
    // then checks if it is of the specified type/class.
    // If the key does not exist or the value is of the wrong type, it
    // sets the error and returns nil. Otherwise, it returns the value.
    return ^id _Nullable(NSString *key, Class cls) {
        id value = node[key];

        if ([value isKindOfClass:cls] == NO) {
            value = nil;
        }

        if (value == nil && error) {
            *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                           format:@"node %p has no value for key '%@' of type %@",
                                                  (void *)node,
                                                  key,
                                                  NSStringFromClass(cls)];
        }

        return value;
    };
}

+ (NSDictionary *)nodeWriters {
    static NSDictionary *dict = nil;
    static dispatch_once_t token;

    dispatch_once(&token, ^{
        dict = [self unsafeLoadNodeWriters];
    });

    return dict;
}

+ (NSDictionary *)unsafeLoadNodeWriters {
    return @{
        SCIXMLNodeTypeElement: ^BOOL(NSDictionary *node, xmlTextWriter *writer, NSError *__autoreleasing *error) {
            id _Nullable (^getter)(NSString *, Class) = [self propertyGetterWithNode:node error:error];

            NSString *name = GET_NODE_PROPERTY(getter, SCIXMLNodeKeyName, NSString);
            if (name == nil) {
                return NO;
            }

            NSArray *children = GET_NODE_PROPERTY(getter, SCIXMLNodeKeyChildren, NSArray);
            if (children == nil) {
                return NO;
            }

            NSDictionary *attributes = GET_NODE_PROPERTY(getter, SCIXMLNodeKeyAttributes, NSDictionary);
            if (attributes == nil) {
                return NO;
            }

            // Write <opening> tag
            if (xmlTextWriterStartElement(writer, XS(name.UTF8String)) < 0) {
                if (error) {
                    *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeWriteFailed
                                                   format:@"could not start element <%@>", name];
                }
                return NO;
            }

            // Write attributes
            for (NSString *attrName in attributes) {
                NSString *attrValue = attributes[attrName];

                // Both keys and values _must_ be strings!
                if ([attrName isKindOfClass:NSString.class] && [attrValue isKindOfClass:NSString.class]) {
                    if (xmlTextWriterWriteAttribute(writer, XS(attrName.UTF8String), XS(attrValue.UTF8String)) < 0) {
                        if (error) {
                            *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeWriteFailed
                                                           format:@"could not write attribute '%@'", attrName];
                        }
                        return NO;
                    }
                } else {
                    if (error) {
                        *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                                       format:@"attribute name or value was not a string"];
                    }
                    return NO;
                }
            }

            // Write children recursively
            for (NSDictionary *child in children) {
                if ([child isKindOfClass:NSDictionary.class]) {
                    if ([self writeXMLNode:child writer:writer error:error] == NO) {
                        return NO;
                    }
                } else {
                    if (error) {
                        *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                                       format:@"child node was not a dictionary"];
                    }
                    return NO;
                }
            }

            // Write </closing> tag
            if (xmlTextWriterEndElement(writer) < 0) {
                if (error) {
                    *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeWriteFailed
                                                   format:@"could not end element </%@>", name];
                }
                return NO;
            }

            return YES;
        },

        SCIXMLNodeTypeText:    [self nodeWriterWithFunction:xmlTextWriterWriteString],
        SCIXMLNodeTypeComment: [self nodeWriterWithFunction:xmlTextWriterWriteComment],
        SCIXMLNodeTypeCDATA:   [self nodeWriterWithFunction:xmlTextWriterWriteCDATA],

        SCIXMLNodeTypeEntityRef: ^BOOL(NSDictionary *node, xmlTextWriter *writer, NSError *__autoreleasing *error) {
            id _Nullable (^getter)(NSString *, Class) = [self propertyGetterWithNode:node error:error];

            NSString *name = GET_NODE_PROPERTY(getter, SCIXMLNodeKeyName, NSString);
            if (name == nil) {
                return NO;
            }

            if (xmlTextWriterWriteFormatRaw(writer, "&%s;", name.UTF8String) < 0) {
                if (error) {
                    *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeWriteFailed
                                                   format:@"error writing entity '&%@;' for node %p",
                                                          name,
                                                          (void *)node];
                }
                return NO;
            }

            return YES;
        },
    };
}

// Return a block that writes a simple, text-content-only node,
// e.g. text nodes, comment nodes and CDATA section nodes.
+ (BOOL (^)(NSDictionary *, xmlTextWriter *, NSError *__autoreleasing *))nodeWriterWithFunction:(int (*)(xmlTextWriter *, const xmlChar *))writerFunction {

    NSParameterAssert(writerFunction);

    return ^BOOL(NSDictionary *node, xmlTextWriter *writer, NSError *__autoreleasing *error) {
        id _Nullable (^getter)(NSString *, Class) = [self propertyGetterWithNode:node error:error];

        NSString *text = GET_NODE_PROPERTY(getter, SCIXMLNodeKeyText, NSString);
        if (text == nil) {
            return NO;
        }

        if (writerFunction(writer, XS(text.UTF8String)) < 0) {
            if (error) {
                *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeWriteFailed
                                               format:@"error writing XML for node %p of type %@",
                                                      (void *)node,
                                                      node[SCIXMLNodeKeyType]];
            }
            return NO;
        }

        return YES;
    };
}

#pragma mark - Compaction and Canonicalization (internal methods)

+ (id _Nullable)compactDictionary:(NSDictionary *)canonical
                    withTransform:(id <SCIXMLCompactingTransform>)transform
                            error:(NSError *__autoreleasing *)error {

    NSParameterAssert(canonical);
    NSParameterAssert(transform);

    // We know that the canonical dictionary is mutable; we use this knowledge
    // to optimize the traversal by eliminating unnecessary memory allocations.
    assert([canonical isKindOfClass:NSMutableDictionary.class]);
    NSMutableDictionary *node = (NSMutableDictionary *)canonical;

    // Perform a bottom-up traversal of the node tree.
    // The reason for the bottom-up traversal is that this way, the structure
    // of the 'remaining' tree (the part above the node currently being processed)
    // is guaranteed to remain canonical, since the transform has no choice of
    // modifying it (for obvious temporal reasons).
    NSMutableArray *children = node[SCIXMLNodeKeyChildren];
    assert(children && [children isKindOfClass:NSMutableArray.class]);

    // So, we recurse _first_, ...
    for (NSUInteger i = 0; i < children.count; i++) {
        id transformedChild = [self compactDictionary:children[i]
                                        withTransform:transform
                                                error:error];
        if (transformedChild == nil) {
            return nil;
        }

        children[i] = transformedChild;
    }

    // ...and the actual application of individual transforms comes only after that.

    // Every node has a type, ...
    if (transform.typeTransform) {
        id value = transform.typeTransform(node[SCIXMLNodeKeyType]);

        if ([value isKindOfClass:NSError.class]) {
            if (error) {
                *error = value;
            }
            return nil;
        }

        node[SCIXMLNodeKeyType] = value;
    }

    // ...But not all of them have a name...
    if (node[SCIXMLNodeKeyName] && transform.nameTransform) {
        id value = transform.nameTransform(node[SCIXMLNodeKeyName]);

        if ([value isKindOfClass:NSError.class]) {
            if (error) {
                *error = value;
            }
            return nil;
        }

        node[SCIXMLNodeKeyName] = value;
    }

    // ...or text contents.
    if (node[SCIXMLNodeKeyText] && transform.textTransform) {
        id value = transform.textTransform(node[SCIXMLNodeKeyText]);

        if ([value isKindOfClass:NSError.class]) {
            if (error) {
                *error = value;
            }
            return nil;
        }

        node[SCIXMLNodeKeyText] = value;
    }

    // But in canonical form, they all have an attribute dictionary.
    if (transform.attributeTransform) {
        NSMutableDictionary *attributes = node[SCIXMLNodeKeyAttributes];
        assert(attributes && [attributes isKindOfClass:NSMutableDictionary.class]);

        NSArray<NSString *> *attributeNames = attributes.allKeys;

        for (NSString *attrName in attributeNames) {
            id value = transform.attributeTransform(
                @{
                    SCIXMLAttributeTransformKeyName:  attrName,
                    SCIXMLAttributeTransformKeyValue: attributes[attrName],
                }
            );

            if ([value isKindOfClass:NSError.class]) {
                if (error) {
                    *error = value;
                }
                return nil;
            }

            attributes[attrName] = value;
        }
    }

    // Finally, when all transformations on the individual parts of the node
    // have been performed, we give the transform a last opportunity to make
    // the node even more meaningful and concise...
    if (transform.nodeTransform) {
        id value = transform.nodeTransform(node);
        NSAssert(value != nil, @"nodeTransform may not return nil, only a valid object or an NSError");

        if ([value isKindOfClass:NSError.class]) {
            if (error) {
                *error = value;
            }
            return nil;
        }

        return value;
    }

    return node;
}

+ (NSDictionary *_Nullable)canonicalizeObject:(id)compacted
                                withTransform:(id <SCIXMLCanonicalizingTransform>)transform
                                        error:(NSError *__autoreleasing *)error {

    NSParameterAssert(compacted);
    NSParameterAssert(transform);

    if (error) {
        *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeUnimplemented
                                       format:@"method not implemented: %s", __PRETTY_FUNCTION__];
    }
    return nil;
}

#pragma mark - Parsing/Deserialization from Strings

+ (NSDictionary *_Nullable)canonicalDictionaryWithXMLString:(NSString *)xml
                                                      error:(NSError *__autoreleasing *)error {

    NSParameterAssert(xml);

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

+ (id _Nullable)compactedObjectWithXMLString:(NSString *)xml
                         compactingTransform:(id <SCIXMLCompactingTransform>)transform
                                       error:(NSError *__autoreleasing *)error {

    NSParameterAssert(xml);
    NSParameterAssert(transform);

    NSData *data = [xml dataUsingEncoding:NSUTF8StringEncoding];

    if (data == nil) {
        if (error) {
            *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeNotUTF8Encoded];
        }
        return nil;
    }

    return [self compactedObjectWithXMLData:data
                        compactingTransform:transform
                                      error:error];
}

#pragma mark - Parsing/Deserialization from Data

+ (NSDictionary *_Nullable)canonicalDictionaryWithXMLData:(NSData *)xml
                                                    error:(NSError *__autoreleasing *)error {

    NSParameterAssert(xml);

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
            *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedXML
                                         rawError:xmlCtxtGetLastError(parser)];
        }
        return nil;
    }

    xmlNode *root = xmlDocGetRootElement(doc);
    NSDictionary *dict = [self dictionaryWithNode:root error:error];

    xmlFreeDoc(doc);

    return dict;
}

+ (id _Nullable)compactedObjectWithXMLData:(NSData *)xml
                       compactingTransform:(id <SCIXMLCompactingTransform>)transform
                                     error:(NSError *__autoreleasing *)error {

    NSParameterAssert(xml);
    NSParameterAssert(transform);

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
                                            indentation:(NSString *_Nullable)indentation
                                                  error:(NSError *__autoreleasing *)error {

    NSParameterAssert(dictionary);

    NSString *string = nil;
    NSUInteger length = 0;
    xmlChar *buf = [self bufferWithDictionary:dictionary
                                  indentation:indentation
                                       length:&length
                                        error:error];
    if (buf == NULL) {
        return nil;
    }

    // It is safe to have NSData free() the byte buffer
    // as long as we know that xmlFree(ptr) is equivalent with free(ptr).
    // In that case, as an optimization, we don't copy the output buffer.
    // Otherwise, we make a copy of it and then xmlFree() it.
    if (self.libxmlUsesLibcAllocators) {
        string = [[NSString alloc] initWithBytesNoCopy:buf
                                                length:length
                                              encoding:NSUTF8StringEncoding
                                          freeWhenDone:YES];

        // if initialization fails, NSString doesn't free the buffer
        if (string == nil) {
            xmlFree(buf);
        }
    } else {
        NSLog(@"*** %s: libxml uses custom allocators; copying output buffer!", __PRETTY_FUNCTION__);
        string = [[NSString alloc] initWithBytes:buf
                                          length:length
                                        encoding:NSUTF8StringEncoding];
        xmlFree(buf);
    }

    // Report error if necessary
    if (string == nil && error) {
        *error = [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeNotUTF8Encoded];
    }

    return string;
}

+ (NSString *_Nullable)xmlStringWithCompactedObject:(id)object
                            canonicalizingTransform:(id <SCIXMLCanonicalizingTransform>)transform
                                        indentation:(NSString *_Nullable)indentation
                                              error:(NSError *__autoreleasing *)error {

    NSParameterAssert(object);
    NSParameterAssert(transform);

    NSDictionary *canonicalDict = [self canonicalizeObject:object
                                             withTransform:transform
                                                     error:error];
    if (canonicalDict == nil) {
        return nil;
    }

    return [self xmlStringWithCanonicalDictionary:canonicalDict
                                      indentation:indentation
                                            error:error];
}

#pragma mark - Generating/Serialization into Binary Data

+ (NSData *_Nullable)xmlDataWithCanonicalDictionary:(NSDictionary *)dictionary
                                        indentation:(NSString *_Nullable)indentation
                                              error:(NSError *__autoreleasing *)error {

    NSParameterAssert(dictionary);

    NSUInteger length = 0;
    xmlChar *buf = [self bufferWithDictionary:dictionary
                                  indentation:indentation
                                       length:&length
                                        error:error];
    if (buf == NULL) {
        return nil;
    }

    // It is safe to have NSData free() the byte buffer
    // as long as we know that xmlFree(ptr) is equivalent with free(ptr).
    // In that case, as an optimization, we don't copy the output buffer.
    // Otherwise, we make a copy of it and then xmlFree() it.
    if (self.libxmlUsesLibcAllocators) {
        return [NSData dataWithBytesNoCopy:buf
                                    length:length
                              freeWhenDone:YES];
    } else {
        NSLog(@"*** %s: libxml uses custom allocators; copying output buffer!", __PRETTY_FUNCTION__);
        NSData *data = [NSData dataWithBytes:buf length:length];
        xmlFree(buf);
        return data;
    }
}

+ (NSData *_Nullable)xmlDataWithCompactedObject:(id)object
                        canonicalizingTransform:(id <SCIXMLCanonicalizingTransform>)transform
                                    indentation:(NSString *_Nullable)indentation
                                          error:(NSError *__autoreleasing *)error {

    NSParameterAssert(object);
    NSParameterAssert(transform);

    NSDictionary *canonicalDict = [self canonicalizeObject:object
                                             withTransform:transform
                                                     error:error];
    if (canonicalDict == nil) {
        return nil;
    }

    return [self xmlDataWithCanonicalDictionary:canonicalDict
                                    indentation:indentation
                                          error:error];
}

@end
