//
// SCIXMLUtils.m
// SCIXMLSerialization
//
// Created by Arpad Goretity
// on 21/08/2016
//
// Copyright (C) SciApps.io, 2016.
//

#import <math.h>

#import "SCIXMLUtils.h"
#import "NSError+SCIXMLSerialization.h"
#import "NSObject+SCIXMLSerialization.h"


typedef NS_ENUM(NSUInteger, SCINumberParsingResult) {
    SCINumberParsingResultSuccess,
    SCINumberParsingResultNoConversion,
    SCINumberParsingResultOverflow,
};


NS_ASSUME_NONNULL_BEGIN

static const char *SCISkipBasePrefix(const char *str, unsigned base) {
    // if the string is not at least 2 characters long, it can't have a base prefix
    if (strlen(str) < 2) {
        return str;
    }

    NSDictionary<NSNumber *, NSString *> *prefixes = @{
        @2:  @"b",
        @8:  @"o",
        @16: @"x",
    };

    const char *prefix = prefixes[@(base)].UTF8String;

    if (prefix && str[0] == '0' && tolower(str[1]) == *prefix) {
        return str + 2;
    }

    return str;
}

static NSError *SCIErrorFromNumberParsingResult(SCINumberParsingResult result, NSString *str) {
    switch (result) {
    case SCINumberParsingResultSuccess:
        NSCAssert(NO, @"must not return an error from SCINumberParsingResultSuccess");
        return nil;

    case SCINumberParsingResultNoConversion:
        return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                     format:@"numeric string '%@' is invalid for the specified base", str];

    case SCINumberParsingResultOverflow:
        return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                     format:@"can't parse '%@' as a number because it overflows", str];

    default:
        NSCAssert(NO, @"unreachable (invalid SCINumberParsingResult: %lu)", (unsigned long)result);
        return nil;
    }
}

static long long SCIStringToLongLong(NSString *str, SCINumberParsingResult *result) {
    NSCParameterAssert(str);
    NSCParameterAssert(result);

    if (str.sci_isString == NO) {
        *result = SCINumberParsingResultNoConversion;
        return 0;
    }

    NSCharacterSet *wsCharset = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    NSString *trimmed = [str stringByTrimmingCharactersInSet:wsCharset];
    const char *cstr = trimmed.UTF8String;
    const char *endExpected = cstr + strlen(cstr);
    char *endActual = NULL;
    errno = 0;

    long long num = strtoll(cstr, &endActual, 10);

    if (errno == ERANGE) {
        // Over- or underflow
        *result = SCINumberParsingResultOverflow;
    } else if (num == 0 && (endActual != endExpected || cstr == endExpected)) {
        // No conversion could be performed.
        // (we test for an empty string using "cstr == endExpected" because for an
        // empty string, strtoll sets endActual to cstr, so endActual == endExpected,
        // therefore an empty string would go undetected without this additional check.)
        *result = SCINumberParsingResultNoConversion;
    } else {
        // Conversion succeeded
        *result = SCINumberParsingResultSuccess;
    }

    return num;
}

static unsigned long long SCIStringToUnsignedLongLong(
    NSString *str,
    unsigned base,
    SCINumberParsingResult *result
) {
    NSCParameterAssert(str);
    NSCParameterAssert(result);

    if (str.sci_isString == NO) {
        *result = SCINumberParsingResultNoConversion;
        return 0;
    }

    NSCharacterSet *wsCharset = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    NSString *trimmed = [str stringByTrimmingCharactersInSet:wsCharset];
    const char *cstr_prefixed = trimmed.UTF8String;
    const char *cstr = SCISkipBasePrefix(cstr_prefixed, base);
    const char *endExpected = cstr + strlen(cstr);
    char *endActual = NULL;
    errno = 0;

    unsigned long long num = strtoull(cstr, &endActual, base);

    if (errno == ERANGE) {
        // Overflow
        *result = SCINumberParsingResultOverflow;
    } else if (num == 0 && (endActual != endExpected || cstr == endExpected)) {
        // No conversion could be performed.
        // (we test for an empty string using "cstr == endExpected" because for an
        // empty string, strtoull sets endActual to cstr, so endActual == endExpected,
        // therefore an empty string would go undetected without this additional check.)
        *result = SCINumberParsingResultNoConversion;
    } else {
        // Conversion succeeded
        *result = SCINumberParsingResultSuccess;
    }

    return num;
}

// I wish C had generics
static double SCIStringToDouble(NSString *str, SCINumberParsingResult *result) {
    NSCParameterAssert(str);
    NSCParameterAssert(result);

    if (str.sci_isString == NO) {
        *result = SCINumberParsingResultNoConversion;
        return NAN;
    }

    NSCharacterSet *wsCharset = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    NSString *trimmed = [str stringByTrimmingCharactersInSet:wsCharset];
    const char *cstr = trimmed.UTF8String;
    const char *endExpected = cstr + strlen(cstr);
    char *endActual = NULL;
    errno = 0;

    double num = strtod(cstr, &endActual);

    if (errno == ERANGE) {
        *result = SCINumberParsingResultOverflow;
    } else if (num == 0.0 && (endActual != endExpected || cstr == endExpected)) {
        *result = SCINumberParsingResultNoConversion;
    } else {
        *result = SCINumberParsingResultSuccess;
    }

    return num;
}

NS_ASSUME_NONNULL_END

id SCIStringToDecimal(NSString *str) {
    SCINumberParsingResult result = SCINumberParsingResultSuccess;

    // First, try parsing a signed number (in order to allow negatives)
    long long signedNum = SCIStringToLongLong(str, &result);

    switch (result) {
    case SCINumberParsingResultSuccess:
        return @(signedNum);

    case SCINumberParsingResultOverflow: {
        // if the result overflows as a signed number, try parsing it as unsigned
        unsigned long long unsignedNum = SCIStringToUnsignedLongLong(str, 10, &result);

        if (result == SCINumberParsingResultSuccess) {
            return @(unsignedNum);
        } else {
            return SCIErrorFromNumberParsingResult(result, str);
        }
    }

    default:
        return SCIErrorFromNumberParsingResult(result, str);
    }
}

id SCIStringToUnsigned(NSString *str, unsigned base) {
    NSCParameterAssert(str);

    SCINumberParsingResult result = SCINumberParsingResultSuccess;
    unsigned long long num = SCIStringToUnsignedLongLong(str, base, &result);

    if (result == SCINumberParsingResultSuccess) {
        return @(num);
    } else {
        return SCIErrorFromNumberParsingResult(result, str);
    }
}

id SCIStringToInteger(NSString *str) {
    NSCParameterAssert(str);

    // First, try parsing it as a binary, octal or hexadecimal
    // unsigned integer, deducing the base from its prefix
    if (str.sci_isString == NO) {
        return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                     format:@"'%@' isn't parseable as an integer", str];
    }

    NSDictionary<NSString *, NSNumber *> *prefixes = @{
        @"0b": @2,
        @"0o": @8,
        @"0x": @16,
    };

    for (NSString *prefix in prefixes) {
        if ([str.lowercaseString hasPrefix:prefix]) {
            unsigned base = prefixes[prefix].unsignedIntValue;
            return SCIStringToUnsigned(str, base);
        }
    }

    // Otherwise, try parsing it as a decimal signed or unsigned integer
    return SCIStringToDecimal(str);
}

id SCIStringToFloating(NSString *str) {
    NSCParameterAssert(str);

    SCINumberParsingResult result = SCINumberParsingResultSuccess;
    double num = SCIStringToDouble(str, &result);

    if (result == SCINumberParsingResultSuccess) {
        return @(num);
    } else {
        return SCIErrorFromNumberParsingResult(result, str);
    }
}

id SCIStringToNumber(NSString *str) {
    NSCParameterAssert(str);

    // First, try parsing the string as an integer
    id numOrError = SCIStringToInteger(str);

    // return it if the conversion succeeded
    if ([numOrError sci_isNumber]) {
        return numOrError;
    }

    // If it failed, however, try again assuming floating-point
    return SCIStringToFloating(str);
}

BOOL SCIDictionaryHasExactKeys(
    NSDictionary<NSString *, id> *dictionary,
    NSArray<NSString *> *keys
) {
    NSSet<NSString *> *requiredKeySet = [NSSet setWithArray:keys];
    NSSet<NSString *> *actualKeySet = [NSSet setWithArray:dictionary.allKeys];
    return [actualKeySet isEqualToSet:requiredKeySet];
}
