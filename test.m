#import "SCIXMLSerialization.h"


int main(int argc, char *argv[])
{
    @autoreleasepool {
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
    }

    return 0;
}
