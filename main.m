#import "SCIXMLSerialization.h"


int main(int argc, char *argv[])
{
    @autoreleasepool {
        NSStringEncoding enc = 0;
        NSString *xml = [NSString stringWithContentsOfFile:@(argv[1])
                                              usedEncoding:&enc
                                                     error:NULL];

        NSError *error = nil;
        NSDictionary *dict = [SCIXMLSerialization canonicalDictionaryWithXMLString:xml
                                                                             error:&error];

        NSLog(@"%@", dict ?: error);
    }

    return 0;
}
