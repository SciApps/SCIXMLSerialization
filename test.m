#import "SCIXMLSerialization.h"


int main(int argc, char *argv[])
{
    @autoreleasepool {
        NSStringEncoding enc = 0;
        NSString *inXML = [NSString stringWithContentsOfFile:@(argv[1])
                                              usedEncoding:&enc
                                                     error:NULL];

        NSError *error = nil;
        id obj = [SCIXMLSerialization compactedObjectWithXMLString:inXML
                                               compactingTransform:SCIXMLCompactingTransform.attributeFlatteningTransform
                                                             error:&error];
        NSLog(@"%@", obj ?: error);


        // NSError *error = nil;
        // NSDictionary *root = [SCIXMLSerialization canonicalDictionaryWithXMLString:inXML
        //                                                                      error:&error];
        // if (error) {
        //     NSLog(@"Parser Error: %@", error);
        //     return -1;
        // }


        // NSString *outXML = [SCIXMLSerialization xmlStringWithCanonicalDictionary:root
        //                                                              indentation:@"\t"
        //                                                                    error:&error];
        // if (error) {
        //     NSLog(@"Serialization Error: %@", error);
        //     return -1;
        // }

        // [outXML writeToFile:@(argv[2])
        //          atomically:YES
        //            encoding:NSUTF8StringEncoding
        //               error:NULL];
    }

    return 0;
}
