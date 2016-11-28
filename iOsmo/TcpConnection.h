//
//  TcpConnection.h
//  ping
//
//  Created by Olga Grineva on 18/11/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Token.h"

@interface TcpConnection : NSObject<NSStreamDelegate>
- (void) createConnection: (Token*) token;
- (void) connect: (Token*) token;
-(void) sendCoordinates: (NSArray*) coordinates;
-(void) openSession;
-(void) closeSession;
@property (nonatomic) BOOL connected;
@property (nonatomic) BOOL sessionOpened;
@property (nonatomic) NSString * sessionUrl;
@end
