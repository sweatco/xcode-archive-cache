//
//  LibraryWithFrameworkDependency.h
//  LibraryWithFrameworkDependency
//
//  Created by Ilya Dyakonov on 5/21/19.
//  Copyright © 2019 xcode-archive-cache. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LibraryWithFrameworkDependency : NSObject

-(NSString *) somethingThatComesFromFramework;
-(NSString *) somethingThatIsDefinedInThisLibrary;

@end

NS_ASSUME_NONNULL_END
