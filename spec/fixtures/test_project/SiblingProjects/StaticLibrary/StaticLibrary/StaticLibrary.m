//
//  StaticLibrary.m
//  StaticLibrary
//
//  Created by Ilya Dyakonov on 14.09.2022.
//

#import "StaticLibrary.h"
#import "AnotherStaticLibrary.h"

@implementation StaticLibrary

-(NSString *) something {
    return [NSString stringWithFormat:@"Here is %@", [[AnotherStaticLibrary new] something]];
}

@end
