//
//  ConnectionManager.h
//  ping
//
//  Created by Olga Grineva on 26/10/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ConnectionManager : NSObject<NSStreamDelegate> {
 }

+ (ConnectionManager *) sharedConnectionManager;
@property (nonatomic) BOOL connectionOpened;
@property (nonatomic) BOOL sessionStarted;
-(void) tryConnect;
-(void) openSession;
-(void) closeSession;
-(NSString*) getSessionUrl;

+(NSString *) authenticate;
@end
