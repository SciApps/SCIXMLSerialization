#import "SCIXMLSerialization.h"


int main(int argc, char *argv[])
{
    @autoreleasepool {
#if 1
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

        id typeProvider = ^(NSDictionary *node, NSError *__autoreleasing *error) {
            if (node == compactedObject || [compactedObject.allValues containsObject:node]) {
                return SCIXMLNodeTypeElement;
            } else {
                return SCIXMLNodeTypeText;
            }
        };

        id <SCIXMLCanonicalizingTransform> transform = [[SCIXMLCanonicalizingTransform alloc] initWithTypeProvider:typeProvider];

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
