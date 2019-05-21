//
//  StaticDependency.h
//  StaticDependency
//
//  Created by Ilya Dyakonov on 5/21/19.
//  Copyright © 2019 xcode-archive-cache. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface StaticDependency : NSObject

-(NSString *) libraryWithFrameworkDependencyDescription;
-(NSString *) ownDescription;

@end

NS_ASSUME_NONNULL_END
