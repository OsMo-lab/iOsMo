//
//  LogQueue.m
//  ping
//
//  Created by Olga Grineva on 17/11/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//

#import "LogQueue.h"



@implementation LogQueue
BOOL isCut;
NSInteger count;
NSMutableArray *innerQueue;


+ (LogQueue *) sharedLogQueue{
    static LogQueue *_queue;
    
    @synchronized(self) {
        if(_queue == nil){
            _queue = [[LogQueue alloc] init];
            
        }
    }
    
    return _queue;
}



- (id) init{

        if(self == [super init]) {
            innerQueue = [[NSMutableArray alloc] init];

    }
    return self;
}

-(NSUInteger) count{
    return [innerQueue count];
}


// Add to the tail of the queue
-(void) enqueue: (id) anObject {
    // Push the item in
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"HH:mm:ss"];
    NSString *timeOfEvent = [dateFormat stringFromDate:[NSDate date]];
    //NSString *event = [anObject stringValue];
    NSString *message = [NSString stringWithFormat:@"%@: %@", timeOfEvent, anObject];
    
    
    [innerQueue addObject: message];
    // Notify that queue was changed
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NewLogMessageWasAdded" object:self];
    
}

-(NSArray*) getArray: (NSInteger) startIndex
            toCount: (NSInteger) count{
    
    NSMutableArray* result = [[NSMutableArray alloc] init];
    for (int i = startIndex; i < startIndex + count;  i++) {
        
        id value = [innerQueue objectAtIndex: i];
        [result addObject: value];
        
    }
    return [result copy];
}

// Grab the next item in the queue, if there is one
-(id) dequeue {
    // Set aside a reference to the object to pass back
    id queueObject = nil;
    
    // Do we have any items?
    if ([innerQueue lastObject]) {
        // Pick out the first one
#if !__has_feature(objc_arc)
        queueObject = [[[innerQueue objectAtIndex: 0] retain] autorelease];
#else
        queueObject = [innerQueue objectAtIndex: 0];
#endif
        // Remove it from the queue
        [innerQueue removeObjectAtIndex: 0];
    }
    
    // Pass back the dequeued object, if any
    return queueObject;
}

// Takes a look at an object at a given location
-(id) peek: (int) index {
    // Set aside a reference to the peeked at object
    id peekObject = nil;
    // Do we have any items at all?
    if ([innerQueue lastObject]) {
        // Is this within range?
        if (index < [innerQueue count]) {
            // Get the object at this index
            peekObject = [innerQueue objectAtIndex: index];
        }
    }
    
    // Pass back the peeked at object, if any
    return peekObject;
}

// Let's take a look at the next item to be dequeued
-(id) peekHead {
    // Peek at the next item
    return [self peek: 0];
}

// Let's take a look at the last item to have been added to the queue
-(id) peekTail {
    // Pick out the last item
    return [innerQueue lastObject];
}

// Checks if the queue is empty
-(BOOL) empty {
    return ([innerQueue lastObject] == nil);
}


@end
