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
            @"CipherValue": SCIXMLParserTypeBase64,
            @"return": SCIXMLParserTypeBase64,
        };

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
        NSLog(@"%@", obj ?: error.localizedDescription);
#else
        NSDictionary *root = @{
            @"DC_LOGINREQ": @{
                SCIXMLTempKeyAttrs: @{
                    @"xmlns":    @"namespace",
                    @"testAttr": @"please work",
                },
                @"LangCode": @"EN",
                @"foo": @{
                    @"lol": @"LOL content",
                    @"qux": @"content QUX",
                },
                @"bar": @[
                    @{
                        @"baz": @{
                            SCIXMLTempKeyAttrs: @{
                                @"attrname": @"attrvalue",
                            },
                            SCIXMLTempKeyChild: @[
                                @{ @"baz": @"BAZ 1" },
                                @{ @"baz": @"BAZ 2" },
                            ]
                        }
                    },
                    @{ @"baz": @"BAZ 3" },
                    @{
                        @"baz": @{ SCIXMLTempKeyAttrs: @{ @"OK": @"Google" }, @"inner": @[ @{ @"innermost": @"innervalue" }, @{ @"innermost": @"another" } ] },
                    },
                ],
            },
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
