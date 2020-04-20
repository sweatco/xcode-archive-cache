//
//  ClassNameReporter.m
//  StaticLibModules
//
//  Created by Ilya Dyakonov on 4/10/20.
//  Copyright © 2020 xcode-archive-cache. All rights reserved.
//

#import "ClassNameReporter.h"

@import Lottie;

@implementation ClassNameReporter

+(NSString *) reportedClassName {
    return NSStringFromClass([AnimatedButton class]);
}

@end
