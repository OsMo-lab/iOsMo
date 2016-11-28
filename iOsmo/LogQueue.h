//
//  LogQueue.h
//  ping
//
//  Created by Olga Grineva on 17/11/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LogQueue : NSMutableArray{

}

+ (instancetype) sharedLogQueue;


-(id) dequeue;
-(void) enqueue:(id)obj;
-(id) peek:(int)index;
-(id) peekHead;
-(id) peekTail;
-(BOOL) empty;
-(NSUInteger) count;
-(NSArray*) getArray: (NSInteger) startIndex
             toCount: (NSInteger) count;
@end
