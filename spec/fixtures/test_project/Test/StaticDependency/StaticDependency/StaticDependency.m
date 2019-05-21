//
//  StaticDependency.m
//  StaticDependency
//
//  Created by Ilya Dyakonov on 5/21/19.
//  Copyright © 2019 xcode-archive-cache. All rights reserved.
//

#import "StaticDependency.h"
#import "LibraryWithFrameworkDependency.h"

@implementation StaticDependency

-(NSString *) libraryWithFrameworkDependencyDescription {
    LibraryWithFrameworkDependency *library = [[LibraryWithFrameworkDependency alloc] init];
    return [NSString stringWithFormat:@"%@ AND %@",
            [library somethingThatIsDefinedInThisLibrary],
            [library somethingThatComesFromFramework]];
}

-(NSString *) ownDescription {
    return @"I'm a static dependency";
}

@end
