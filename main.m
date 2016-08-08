#import "SCIXMLSerialization.h"


int main(int argc, char *argv[])
{
    @autoreleasepool {
        NSStringEncoding enc = 0;
        NSString *xml = [NSString stringWithContentsOfFile:@(argv[1])
                                              usedEncoding:&enc
                                                     error:NULL];

        NSDictionary *dict = [SCIXMLSerialization canonicalDictionaryWithXMLString:xml
                                                                             error:NULL];

        NSLog(@"%@", dict);
    }

    return 0;
}
