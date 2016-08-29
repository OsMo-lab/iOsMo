//
//  Token.h
//  ping
//
//  Created by Olga Grineva on 18/11/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Token : NSObject

@property (nonatomic, retain) NSString *token;
@property (nonatomic, retain) NSString *address;
@property (nonatomic) UInt32 port;

@end
