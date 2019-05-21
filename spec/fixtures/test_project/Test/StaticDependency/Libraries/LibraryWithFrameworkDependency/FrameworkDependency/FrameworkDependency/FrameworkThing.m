//
//  FrameworkThing.m
//  FrameworkDependency
//
//  Created by Ilya Dyakonov on 5/21/19.
//  Copyright © 2019 xcode-archive-cache. All rights reserved.
//

#import "FrameworkThing.h"

@implementation FrameworkThing

-(NSString *) somethingThatOnlyFrameworkKnows {
    return @"I'm a framework dependency";
}

@end
