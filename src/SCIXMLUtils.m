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

typedef NS_ENUM(NSUInteger, SCINumberParsingType) {
    SCINumberParsingTypeSignedLongLong,
    SCINumberParsingTypeUnsignedLongLong,
    SCINumberParsingTypeDouble,
};

typedef NS_ENUM(NSUInteger, BlockFlags) {
    BLOCK_HAS_COPY_DISPOSE = 1 << 25,
    BLOCK_HAS_CTOR         = 1 << 26, // helpers have C++ code
    BLOCK_IS_GLOBAL        = 1 << 28,
    BLOCK_HAS_STRET        = 1 << 29, // iff BLOCK_HAS_SIGNATURE
    BLOCK_HAS_SIGNATURE    = 1 << 30,
};


typedef struct {
    unsigned long reserved;
    unsigned long size;
    const char *signature;
} Block_descriptor_unmanaged;

typedef struct {
    unsigned long reserved;
    unsigned long size;
    void (*copy_helper)(void *dst, void *src);
    void (*dispose_helper)(void *src);
    const char *signature;
} Block_descriptor_copy_dispose;

typedef union {
    Block_descriptor_unmanaged u;
    Block_descriptor_copy_dispose c;
} Block_descriptor;

typedef struct {
    void *isa;
    int flags;
    int reserved;
    void (*invoke)(void *, ...);
    void *descriptor;
} Block_literal;


NS_ASSUME_NONNULL_BEGIN

static NSMethodSignature *_Nullable SCISignatureForBlock(id block) {
    if (block == nil || [block isKindOfClass:NSClassFromString(@"NSBlock")] == NO) {
        return nil;
    }

    Block_literal *block_struct = (__bridge Block_literal *)block;
    Block_descriptor *descriptor = block_struct->descriptor;
    const char *signature = NULL;

    if (block_struct->flags & BLOCK_HAS_COPY_DISPOSE) {
        signature = descriptor->c.signature;
    } else {
        signature = descriptor->u.signature;
    }

    if (signature == NULL) {
        return nil;
    }

    return [NSMethodSignature signatureWithObjCTypes:signature];
}

BOOL SCIBlockIsParserSubtransform(id block) {
    id referenceBlock = ^id _Nullable (NSString *name, id value) {
        return nil;
    };

    NSMethodSignature *expectedSignature = SCISignatureForBlock(referenceBlock);
    NSMethodSignature *actualSignature   = SCISignatureForBlock(block);

    NSCAssert(expectedSignature != nil, @"reference block has no signature");

    // block has no signature or it's not even a block. Impostor!
    if (actualSignature == nil) {
        return NO;
    }

    if (expectedSignature.numberOfArguments != actualSignature.numberOfArguments) {
        return NO;
    }

    // The constraints on the signature of a parser block are the following:
    // 1. The return type must be an Objective-C object type (including id)
    // 2. The 0th argument (self) must be the same as that of the referenceBlock
    // 3. The 1st argument (name) must be an NSString *
    // 4. The 2nd argument (value) must also be an Objective-C object type

    NSString *expectedReturnType = @(@encode(id));
    NSString *expectedSelfType   = @([expectedSignature getArgumentTypeAtIndex:0]);
    NSString *expectedNameType   = @([expectedSignature getArgumentTypeAtIndex:1]);
    NSString *expectedValueType  = @(@encode(id));

    NSString *actualReturnType   = @(actualSignature.methodReturnType);
    NSString *actualSelfType     = @([actualSignature getArgumentTypeAtIndex:0]);
    NSString *actualNameType     = @([actualSignature getArgumentTypeAtIndex:1]);
    NSString *actualValueType    = @([actualSignature getArgumentTypeAtIndex:2]);

    return [actualReturnType hasPrefix:expectedReturnType]
        && [actualSelfType isEqualToString:expectedSelfType]
        && [actualNameType isEqualToString:expectedNameType]
        && [actualValueType hasPrefix:expectedValueType];
}

static const char *SCISkipBasePrefix(const char *str, unsigned base) {
    NSCParameterAssert(str);

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
    NSCParameterAssert(str);

    switch (result) {
    case SCINumberParsingResultSuccess:
        NSCAssert(NO, @"must not return an error from SCINumberParsingResultSuccess");
        return nil;

    case SCINumberParsingResultNoConversion:
        return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                     format:@"numeric string '%@' is invalid for the specified base or format",
                                            str];

    case SCINumberParsingResultOverflow:
        return [NSError SCIXMLErrorWithCode:SCIXMLErrorCodeMalformedTree
                                     format:@"can't parse '%@' as a number because it overflows", str];

    default:
        NSCAssert(NO, @"unreachable (invalid SCINumberParsingResult: %lu)", (unsigned long)result);
        return nil;
    }
}

static SCINumberParsingResult SCIStringToArithmetic(
    NSString *str,
    unsigned base,
    SCINumberParsingType type,
    void *outNumber
) {
    NSCParameterAssert(str);
    NSCParameterAssert(outNumber);

    if (str.sci_isString == NO) {
        return SCINumberParsingResultNoConversion;
    }

    // Trim whitespace from both ends of the string
    NSCharacterSet *wsCharset = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    NSString *trimmed = [str stringByTrimmingCharactersInSet:wsCharset];
    const char *cstr = trimmed.UTF8String;

    // If the number is expected to be parsed as an unsigned, then skip its potential base prefix
    if (type == SCINumberParsingTypeUnsignedLongLong) {
        // need a temporary object to avoid UB because assignment is unsequenced
        const char *cstr_noprefix = SCISkipBasePrefix(cstr, base);
        cstr = cstr_noprefix;
    }

    // Prepare the ground for the conversion functions
    const char *endExpected = cstr + strlen(cstr);
    char *endActual = NULL;
    errno = 0;

    // Perform the conversion
    switch (type) {
    case SCINumberParsingTypeSignedLongLong:
        *(long long *)outNumber = strtoll(cstr, &endActual, base);
        break;
    case SCINumberParsingTypeUnsignedLongLong:
        *(unsigned long long *)outNumber = strtoull(cstr, &endActual, base);
        break;
    case SCINumberParsingTypeDouble:
        *(double *)outNumber = strtod(cstr, &endActual);
        break;
    default:
        NSCAssert(NO, @"invalid SCINumberParsingType: %lu", (unsigned long)type);
        break;
    }

    // Check if it succeeded
    if (errno == ERANGE) {
        // Over- or underflow
        return SCINumberParsingResultOverflow;
    } else if (endActual != endExpected || cstr == endExpected) {
        // No conversion could be performed.
        // (we test for an empty string using "cstr == endExpected" because for an
        // empty string, conversion functions set endActual to cstr, so endActual == endExpected,
        // therefore an empty string would go undetected without this additional check.)
        return SCINumberParsingResultNoConversion;
    } else {
        // Conversion succeeded
        return SCINumberParsingResultSuccess;
    }
}

static long long SCIStringToLongLong(NSString *str, SCINumberParsingResult *result) {
    NSCParameterAssert(str);
    NSCParameterAssert(result);

    long long number = 0;
    *result = SCIStringToArithmetic(str, 10, SCINumberParsingTypeSignedLongLong, &number);

    return number;
}

static unsigned long long SCIStringToUnsignedLongLong(
    NSString *str,
    unsigned base,
    SCINumberParsingResult *result
) {
    NSCParameterAssert(str);
    NSCParameterAssert(result);

    unsigned long long number = 0;
    *result = SCIStringToArithmetic(str, base, SCINumberParsingTypeUnsignedLongLong, &number);

    return number;
}

static double SCIStringToDouble(NSString *str, SCINumberParsingResult *result) {
    NSCParameterAssert(str);
    NSCParameterAssert(result);

    double number = NAN;
    *result = SCIStringToArithmetic(str, 0 /* ignored */, SCINumberParsingTypeDouble, &number);

    return number;
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

    NSCharacterSet *wsCharset = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    NSString *trimmedLowercase = [str stringByTrimmingCharactersInSet:wsCharset].lowercaseString;

    NSDictionary<NSString *, NSNumber *> *prefixes = @{
        @"0b": @2,
        @"0o": @8,
        @"0x": @16,
    };

    for (NSString *prefix in prefixes) {
        if ([trimmedLowercase hasPrefix:prefix]) {
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
