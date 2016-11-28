//
//  TcpConnection.m
//  ping
//
//  Created by Olga Grineva on 18/11/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//

#import "TcpConnection.h"
#import "Token.h"
#import "LogQueue.h"

#define LATITUDE @"latitude"
#define LONGITUDE @"longitude"
#define ACCURACY @"theAccuracy"

@interface TcpConnection()

@property (nonatomic) NSInputStream *inputStream;
@property (nonatomic) NSOutputStream *outputStream;
@property (nonatomic) NSTimer *runner;
@property (nonatomic) LogQueue * sharedLog;
@property (nonatomic) NSString * trackerId;

@property (nonatomic) NSMutableArray * coordinates;

@end

@implementation TcpConnection

@synthesize inputStream;
@synthesize outputStream;
@synthesize runner;
@synthesize sharedLog;
@synthesize connected;
@synthesize sessionOpened;
@synthesize sessionUrl;

-(id) init{
    
    if(self = [super init]) {
        sharedLog = [LogQueue sharedLogQueue];
    }
    return self;

}

-(void) createConnection: (Token*) token {
    
    //self.runner = [NSTimer scheduledTimerWithTimeInterval: 0.1 target:self selector:@selector(stream:handleEvent:) userInfo:nil repeats:YES];
    
    
//    dispatch_queue_t qt = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//    dispatch_async(qt, ^{
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocketToHost(NULL, (CFStringRef)@"osmo.mobi", token.port, &readStream, &writeStream);
        
        
    inputStream = (__bridge NSInputStream *)readStream;
    outputStream = (__bridge NSOutputStream *)writeStream;
        
    NSRunLoop *loop = [NSRunLoop currentRunLoop];
        
    [inputStream setDelegate:self];
    [outputStream setDelegate:self];
        
    [inputStream scheduleInRunLoop:loop forMode:NSDefaultRunLoopMode];
    [outputStream scheduleInRunLoop:loop forMode:NSDefaultRunLoopMode];
        
    [inputStream open];
    [outputStream open];
    
    [self connect: token];
        
}

-(void) connect: (Token*) token {
    
    NSString *someResponce  = [NSString stringWithFormat:@"TOKEN|%@", token.token];
    
    NSData *data = [[NSData alloc] initWithData:[someResponce dataUsingEncoding:NSASCIIStringEncoding]];
    [outputStream write:[data bytes] maxLength:[data length]];
    
}

-(NSDictionary*) getDictionary: (NSString*) fromTag{
    
    NSString *json = [[fromTag componentsSeparatedByString: @"|"] objectAtIndex:1];
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    
    return jsonDictionary;
}


- (void) parseToken: (NSString*) tokenResponce{
    
    self.trackerId = [[self getDictionary: tokenResponce] objectForKey:@"tracker_id"];
}

-(void) sendPing{
    NSString *someResponce  = [NSString stringWithFormat:@"PP"];
    
    NSData *data = [[NSData alloc] initWithData:[someResponce dataUsingEncoding:NSASCIIStringEncoding]];
    [outputStream write:[data bytes] maxLength:[data length]];
    
}

// make coordinates queue
-(void) sendCoordinates: (NSArray*) coordinatesToSend{
    if(self.coordinates == nil)
        self.coordinates = [[NSMutableArray alloc] init];
    
    [self.coordinates addObjectsFromArray: coordinatesToSend];
    
    [self sendNextCoordinate];
}

-(void) sendNextCoordinate{
    
    if (self.coordinates.count > 0 && self.sessionOpened)
    {
        NSMutableDictionary* theCoordinate = [self.coordinates objectAtIndex: 0];
        [theCoordinate objectForKey: LATITUDE];

        NSString *someResponce  = [NSString stringWithFormat:@"T|L%@:%@", [theCoordinate objectForKey: LATITUDE], [theCoordinate objectForKey: LONGITUDE]];
    
        NSData *data = [[NSData alloc] initWithData:[someResponce dataUsingEncoding:NSASCIIStringEncoding]];
        [outputStream write:[data bytes] maxLength:[data length]];
    }
}


-(void) openSession{
    NSString *someResponce  = [NSString stringWithFormat:@"TRACKER_SESSION_OPEN"];
    
    NSData *data = [[NSData alloc] initWithData:[someResponce dataUsingEncoding:NSASCIIStringEncoding]];
    [outputStream write:[data bytes] maxLength:[data length]];
   
}

-(void) closeSession{
    NSString *someResponce  = [NSString stringWithFormat:@"TRACKER_SESSION_CLOSE"];
    
    NSData *data = [[NSData alloc] initWithData:[someResponce dataUsingEncoding:NSASCIIStringEncoding]];
    [outputStream write:[data bytes] maxLength:[data length]];
    
}

-(void) parseSession: (NSString*)sessionTag{
    
    NSDictionary* sessionValues = [self getDictionary: sessionTag];
    
    sessionUrl = [sessionValues objectForKey: @"url"];
    
    [self.sharedLog enqueue: [NSString stringWithFormat: @"parse session: url %@", sessionUrl]];
    NSLog(@"parse session: url %@", sessionUrl);
    
    [self setValue:[NSNumber numberWithBool:YES]  forKey:@"sessionOpened"];
    
}

#pragma mark - NSStreamDelegate
- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
    
    NSLog(@"stream event %lu", streamEvent);
    [sharedLog enqueue:[NSString stringWithFormat:@"stream event %lu", streamEvent]];
    
    switch (streamEvent) {
        case NSStreamEventOpenCompleted:
        {
            NSLog(@"Stream opened");
            [sharedLog enqueue: [NSString stringWithFormat:@"stream opened"]];
            
        }
            break;
            
        case NSStreamEventErrorOccurred:
        {
            NSLog(@"Can not connect to the host!");
            [sharedLog enqueue:[NSString stringWithFormat:@"Can not connect to the host!"]];
            [self setValue:[NSNumber numberWithBool:NO]  forKey:@"connected"];
            [self setValue:[NSNumber numberWithBool:NO]  forKey:@"sessionOpened"];
        }
            break;
            
        case NSStreamEventHasSpaceAvailable:
        {
            uint8_t buffer[1024];
            int len;
            
            while ([inputStream hasBytesAvailable]) {
                len = [inputStream read:buffer maxLength:sizeof(buffer)];
                if (len > 0) {
                    NSString *output = [[NSString alloc] initWithBytes:buffer length:len encoding:NSASCIIStringEncoding];
                    
                    if (nil != output) {
                        NSLog(@"server said: %@", output);
                        [sharedLog enqueue:[NSString stringWithFormat:@"server said: %@", output]];
                        if([output containsString:@"TOKEN|"])
                        {
                            [self setValue:[NSNumber numberWithBool:YES]  forKey:@"connected"];
                        }
                        if([output containsString:@"TRACKER_SESSION_OPEN|"])
                        {
                            
                            [self parseSession: output];
                        }
                        if([output containsString:@"TRACKER_SESSION_CLOSE|"])
                        {
                            [self setValue:[NSNumber numberWithBool:NO]  forKey:@"sessionOpened"];
                            
                        }
                        if([output containsString:@"KICK|"])
                        {
                            [self setValue:[NSNumber numberWithBool:NO]  forKey:@"connected"];
                            [self setValue:[NSNumber numberWithBool:NO]  forKey:@"sessionOpened"];
                        }
                        if([output containsString:@"REMOTE_CONTROL|PP"])
                        {
                            [self sendPing];
                        }
                        if([output containsString:@"T|"])
                        {
                            if(self.coordinates.count > 0)
                            {
                                [self.coordinates removeObjectAtIndex: 0];
                                [self sendNextCoordinate];
                            }
                        }
                    }
                }
            }
        }
            break;
            
        case NSStreamEventHasBytesAvailable:
        {
            
            uint8_t buffer[1024];
            int len;
            
            while ([inputStream hasBytesAvailable]) {
                len = [inputStream read:buffer maxLength:sizeof(buffer)];
                if (len > 0) {
                    
                    NSString *output = [[NSString alloc] initWithBytes:buffer length:len encoding:NSASCIIStringEncoding];
                    
                    if (nil != output) {
                        NSLog(@"server said at has bytes: %@", output);
                        [sharedLog enqueue:[NSString stringWithFormat:@"server said at has bytes: %@", output]];
                        
                        NSLog(@"server said: %@", output);
                        [sharedLog enqueue:[NSString stringWithFormat:@"server said: %@", output]];
                        if([output containsString:@"TOKEN|"])
                        {
                            [self setValue:[NSNumber numberWithBool:YES]  forKey:@"connected"];
                        }
                        if([output containsString:@"TRACKER_SESSION_OPEN|"])
                        {
                            [self parseSession: output];
                        }
                        if([output containsString:@"TRACKER_SESSION_CLOSE|"])
                        {
                            [self setValue:[NSNumber numberWithBool:NO]  forKey:@"sessionOpened"];
                            
                        }
                        if([output containsString:@"KICK|"])
                        {
                            [self setValue:[NSNumber numberWithBool:NO]  forKey:@"connected"];
                            [self setValue:[NSNumber numberWithBool:NO]  forKey:@"sessionOpened"];
                        }
                        if([output containsString:@"REMOTE_CONTROL|PP"])
                        {
                            [self sendPing];
                        }
                        if([output containsString:@"T|"])
                        {
                            if(self.coordinates.count > 0)
                            {
                                [self.coordinates removeObjectAtIndex: 0];
                                [self sendNextCoordinate];
                            }                        }
                    }
                }
            }
            
            //}
            
        }
        break;
            
            
        default:
        {            
            uint8_t buffer[1024];
            int len;
            
            while ([inputStream hasBytesAvailable]) {
                len = [inputStream read:buffer maxLength:sizeof(buffer)];
                if (len > 0) {
                    NSString *output = [[NSString alloc] initWithBytes:buffer length:len encoding:NSASCIIStringEncoding];
                    
                    if (nil != output) {
                        NSLog(@"server said at unknown event: %@", output);
                        [sharedLog enqueue:[NSString stringWithFormat:@"server said at unknown event: %@", output]];
                        
                        NSLog(@"server said: %@", output);
                        [sharedLog enqueue:[NSString stringWithFormat:@"server said: %@", output]];
                        if([output containsString:@"TOKEN|"])
                        {
                            [self setValue:[NSNumber numberWithBool:YES]  forKey:@"connected"];
                        }
                        if([output containsString:@"TRACKER_SESSION_OPEN|"])
                        {
                            [self parseSession: output];
                        }
                        if([output containsString:@"TRACKER_SESSION_CLOSE|"])
                        {
                            [self setValue:[NSNumber numberWithBool:NO]  forKey:@"sessionOpened"];
                           
                        }
                        if([output containsString:@"KICK|"])
                        {
                            [self setValue:[NSNumber numberWithBool:NO]  forKey:@"connected"];
                            [self setValue:[NSNumber numberWithBool:NO]  forKey:@"sessionOpened"];
                        }
                        if([output containsString:@"REMOTE_CONTROL|PP"])
                        {
                            [self sendPing];
                        }
                        if([output containsString:@"T|"])
                        {
                            if(self.coordinates.count > 0)
                            {
                                [self.coordinates removeObjectAtIndex: 0];
                                [self sendNextCoordinate];
                            }
                        }
                                           }
                }
            }
            
        }
            
    }
    
}
@end
