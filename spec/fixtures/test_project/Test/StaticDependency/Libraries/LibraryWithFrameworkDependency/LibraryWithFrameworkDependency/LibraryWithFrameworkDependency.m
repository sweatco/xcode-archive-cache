//
//  LibraryWithFrameworkDependency.m
//  LibraryWithFrameworkDependency
//
//  Created by Ilya Dyakonov on 5/21/19.
//  Copyright © 2019 xcode-archive-cache. All rights reserved.
//

#import "LibraryWithFrameworkDependency.h"
#import <FrameworkDependency/FrameworkDependency.h>

@implementation LibraryWithFrameworkDependency

-(NSString *) somethingThatComesFromFramework {
    return [[[FrameworkThing alloc] init] somethingThatOnlyFrameworkKnows];
}

-(NSString *) somethingThatIsDefinedInThisLibrary {
    return @"I'm a static library with a framework dependency";
}

@end
