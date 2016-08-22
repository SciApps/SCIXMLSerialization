//
// SCIXMLUtils.h
// SCIXMLSerialization
//
// Created by Arpad Goretity
// on 21/08/2016
//
// Copyright (C) SciApps.io, 2016.
//

#import <stdlib.h>
#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

id SCIStringToDecimal(NSString *str);
id SCIStringToUnsigned(NSString *str, unsigned base);
id SCIStringToInteger(NSString *str);
id SCIStringToFloating(NSString *str);
id SCIStringToNumber(NSString *str);

BOOL SCIDictionaryHasExactKeys(
    NSDictionary<NSString *, id> *dictionary,
    NSArray<NSString *> *keys
);

NS_ASSUME_NONNULL_END
