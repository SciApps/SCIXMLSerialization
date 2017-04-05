#import "SCIXMLSerialization.h"


int main(int argc, char *argv[])
{
    @autoreleasepool {
#if 1
        NSStringEncoding enc = 0;
        NSString *inXML = [NSString stringWithContentsOfFile:@(argv[1])
                                              usedEncoding:&enc
                                                     error:NULL];

        inXML = @"<root><date>2017-04-03T13:37:42</date></root>";

        NSDictionary *typeMap = @{ @"date": SCIXMLParserTypeDate };

        id <SCIXMLCompactingTransform> transform;
        transform = [SCIXMLCompactingTransform basicCompactingTransformWithChildFlatteningGroupingMap:nil
                                                                               attributeParserTypeMap:nil
                                                                              attributeParserFallback:nil
                                                                                  memberParserTypeMap:typeMap
                                                                                 memberParserFallback:nil];

        NSError *error = nil;
        id obj = [SCIXMLSerialization compactedObjectWithXMLString:inXML
                                               compactingTransform:[transform copy] // test copying
                                                             error:&error];
        NSLog(@"%@ | %@", obj, [obj[@"date"] class] ?: error.localizedDescription);
#else
        NSDictionary *root = @{
            @"DC_LOGINREQ": @[
                @{ @"LangCode": @"EN", },
                @{
                    @"baz": @{
                        SCIXMLTempKeyAttrs: @{
                            @"attrname": @"attrvalue",
                        },
                        SCIXMLTempKeyChild: @[
                            @{ @"baz": @"BAZ 1" },
                            @{ @"baz": @"BAZ 2" },
                        ],
                    },
                },
            ],
        };

        NSError *error = nil;
        NSString *xml = [SCIXMLSerialization xmlStringWithNaturalDictionary:root
                                                                indentation:@"    "
                                                                      error:&error];

        NSLog(@"\n\n%@", xml ?: error);
#endif
    }

    return 0;
}
