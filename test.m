#import "SCIXMLSerialization.h"


int main(int argc, char *argv[])
{
    @autoreleasepool {
#if 0
        NSStringEncoding enc = 0;
        NSString *inXML = [NSString stringWithContentsOfFile:@(argv[1])
                                              usedEncoding:&enc
                                                     error:NULL];

        NSDictionary<NSString *, id> *typeMap = @{
            @"StatusCode":                 SCIXMLParserTypeInteger,
            @"StatusDate":                 ^NSDate *(NSString *name, NSString *value) {
                NSDateFormatter *dateFormatter = [NSDateFormatter new];
                dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
                dateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
                dateFormatter.dateFormat = @"yyyyMMdd";
                return [dateFormatter dateFromString:value];
            },
            @"TemplateExpirationDate":     SCIXMLParserTypeHex,
            @"ValueMax":                   SCIXMLParserTypeNumber,
            @"Osszeg":                     SCIXMLParserTypeFloating,
            @"TemplateAllowed":            SCIXMLParserTypeCXXBool,
            @"FixedValue":                 SCIXMLParserTypeBool,
            @"CouponEnabled":              SCIXMLParserTypeCXXBool,
            @"Extra":                      SCIXMLParserTypeBase64,
            @"data":                       SCIXMLParserTypeBase64,
        };
        NSDictionary<NSString *, NSArray<NSString *> *> *groupingMap = @{
            @"TransactionList": @[ @"Transaction", @"foo" ],
        };

        id _Nullable (^censoringTransform)(NSString *, id) = ^id _Nullable(NSString *name, id value) {
            if ([name isEqualToString:@"Currency"]) {
                return @"REDACTED";
            }

            return value;
        };

        NSArray<id<SCIXMLCompactingTransform>> *transforms = @[
            SCIXMLCompactingTransform.attributeFlatteningTransform,
            SCIXMLCompactingTransform.elementTypeFilterTransform,
            SCIXMLCompactingTransform.textNodeFlatteningTransform,
            [SCIXMLCompactingTransform childFlatteningTransformWithGroupingMap:groupingMap],
            [SCIXMLCompactingTransform memberParserTransformWithTypeMap:typeMap
                                                               fallback:censoringTransform],
        ];

        id <SCIXMLCompactingTransform> transform;
        transform = [SCIXMLCompactingTransform combineTransforms:transforms
                                      conflictResolutionStrategy:SCIXMLTransformCombinationConflictResolutionStrategyCompose];

        NSError *error = nil;
        id obj = [SCIXMLSerialization compactedObjectWithXMLString:inXML
                                               compactingTransform:transform
                                                             error:&error];
        NSLog(@"%@", obj ?: error.localizedDescription);
#else
        NSDictionary *compactedObject = @{
            @"attribute1": @"value1",
            @"attribute2": @42,
            @"child1": @{
                @"subattribute": @"value3",
            },
            @"child2": @{
                @"subattribute": [NSDate date],
            },
        };

        id <SCIXMLCanonicalizingTransform> transform = [SCIXMLCanonicalizingTransform new];

        transform.typeProvider = ^(NSDictionary *node, NSError *__autoreleasing *error) {
            if (node == compactedObject || [compactedObject.allValues containsObject:node]) {
                return SCIXMLNodeTypeElement;
            } else {
                return SCIXMLNodeTypeText;
            }
        };
        transform.nameProvider = ^(id node, NSError *__autoreleasing *error) {
            return node == compactedObject ? @"root" : @"child";
        };
        transform.textProvider = ^(NSDictionary<NSString *, NSObject *> *node, NSError *__autoreleasing *error) {
            return node[SCIXMLNodeKeyText].description;
        };
        transform.childProvider = ^(id node, NSError *__autoreleasing *error) {
            if (node[@"child1"]) {
                return @[ node[@"child1"], node[@"child2"] ];
            }
            return @[ @{ SCIXMLNodeKeyText: node[@"subattribute"] } ];
        };
        transform.attributeProvider = ^(id node, NSError *__autoreleasing *error) {
            NSArray *arr = node == compactedObject ? @[ @"attribute1", @"attribute2" ] : @[ @"subattribute" ];
            return [NSSet setWithArray:arr];
        };
        transform.attributeTransform = ^NSString *(id node, NSString *name, NSError *__autoreleasing *error) {
            if ([name isEqualToString:@"attribute1"]) {
                return node[name];
            } else if ([name isEqualToString:@"attribute2"]) {
                return [node[name] description];
            } else if ([name isEqualToString:@"subattribute"]) {
                return [node[name] description];
            }
            return nil;
        };
        // transform.textProvider = ^(id object, NSError *__autoreleasing *error) {
        //     return @"YOLO AND SWAG";
        // };

        NSError *error = nil;
        NSString *xml = [SCIXMLSerialization xmlStringWithCompactedObject:compactedObject
                                                  canonicalizingTransform:transform
                                                              indentation:@"    "
                                                                    error:&error];

        NSLog(@"%@", xml ?: error);
#endif
    }

    return 0;
}
