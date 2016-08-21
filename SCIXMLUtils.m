//
// SCIXMLUtils.m
// SCIXMLSerialization
//
// Created by Arpad Goretity
// on 21/08/2016
//
// Copyright (C) SciApps.io, 2016.
//

#import "SCIXMLUtils.h"
#import "NSError+SCIXMLSerialization.h"


// TODO(H2CO3): implement the functions below using something like this:
//
// if (str.sci_isString == NO) {
//     return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
//                                  format:@"cannot parse non-string value of type %@ as a number",
//                     NSStringFromClass(str.class)];
// }
//
// NSCharacterSet *wsCharset = NSCharacterSet.whitespaceAndNewlineCharacterSet;
// const char *cstr = [str stringByTrimmingCharactersInSet:wsCharset].UTF8String;
// const char *endExpected = cstr + strlen(cstr);
// char *endActual = NULL;
//
// errno = 0;
//
// // First, try parsing input as signed
// long long sResult = strtoll(cstr, &endActual, 10);
//
// // if it failed because the number is too big (positive), then try parsing it as unsigned
// if (errno == ERANGE && sResult == LLONG_MAX) {
//     unsigned long long uResult = strtoull(cstr, &endActual, 10);
//     if (errno == ERANGE) {
//         // unsigned conversion overflowed as well; all hope is lost
//         // TODO(H2CO3): handle error
//     }
// }


id SCIStringToSigned(NSString *str) {
    NSCParameterAssert(str);
    NSCAssert(NO, @"Unimplemented!");
    return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeUnimplemented
                                 format:@"unimplemented function: %s", __PRETTY_FUNCTION__];
}

id SCIStringToUnsigned(NSString *str, unsigned base) {
    NSCParameterAssert(str);
    NSCAssert(NO, @"Unimplemented!");
    return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeUnimplemented
                                 format:@"unimplemented function: %s", __PRETTY_FUNCTION__];
}

id SCIStringToDecimal(NSString *str) {
    NSCParameterAssert(str);
    NSCAssert(NO, @"Unimplemented!");
    return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeUnimplemented
                                 format:@"unimplemented function: %s", __PRETTY_FUNCTION__];
}

id SCIStringToInteger(NSString *str) {
    NSCParameterAssert(str);
    NSCAssert(NO, @"Unimplemented!");
    return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeUnimplemented
                                 format:@"unimplemented function: %s", __PRETTY_FUNCTION__];
}

id SCIStringToFloating(NSString *str) {
    NSCParameterAssert(str);
    NSCAssert(NO, @"Unimplemented!");
    return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeUnimplemented
                                 format:@"unimplemented function: %s", __PRETTY_FUNCTION__];
}

id SCIStringToNumber(NSString *str) {
    NSCParameterAssert(str);
    NSCAssert(NO, @"Unimplemented!");
    return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeUnimplemented
                                 format:@"unimplemented function: %s", __PRETTY_FUNCTION__];
}

BOOL SCIDictionaryHasExactKeys(
    NSDictionary<NSString *, id> *dictionary,
    NSArray<NSString *> *keys
) {
    NSSet<NSString *> *requiredKeySet = [NSSet setWithArray:keys];
    NSSet<NSString *> *actualKeySet = [NSSet setWithArray:dictionary.allKeys];
    return [actualKeySet isEqualToSet:requiredKeySet];
}
