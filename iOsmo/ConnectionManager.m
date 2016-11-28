//
//  ConnectionManager.m
//  ping
//
//  Created by Olga Grineva on 26/10/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//

//some useful at example about http://stackoverflow.com/questions/10980874/how-to-properly-open-and-close-a-nsstream-on-another-thread?rq=1


#import "ConnectionManager.h"

#import "SettingsManager.h"
#import "LogQueue.h"
#import "Token.h"
#import "TcpConnection.h"
#import "MonitoringManager.h"

@interface ConnectionManager()


@property (nonatomic) NSString * key;




@property (nonatomic) int tries;

@property (nonatomic) LogQueue* sharedLog;

@property (nonatomic) TcpConnection* connection;
@property (nonatomic) MonitoringManager* monitoring;
@property (nonatomic, retain) NSTimer* connectingTimer;

@end
@implementation ConnectionManager
@synthesize connectionOpened;
@synthesize sessionStarted;

NSTimer *openSessionRunner;


+ (ConnectionManager *) sharedConnectionManager{
    static ConnectionManager *_connectionManager;
    
    @synchronized(self) {
        if(_connectionManager == nil){
            _connectionManager = [[ConnectionManager alloc] init];
        }
    }
    
    return _connectionManager;
}

-(id) init{
    if(self = [super init])
    {
        _connection = [[TcpConnection alloc] init];
        _sharedLog = [LogQueue sharedLogQueue];
        _monitoring = [MonitoringManager alloc];
    }
    
    return self;
}

//
+(NSString *) authenticate {
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://api.osmo.mobi/auth"]];
    
    [request setHTTPMethod:@"POST"];
    NSString *body = [NSString stringWithFormat:@"model=Iphone&imei=0&client=iOsmo&android_id=unknown"];
    NSData *data = [body dataUsingEncoding:NSUTF8StringEncoding];
    
    [request setHTTPBody:data];
    
    NSError *err;
    NSURLResponse *response;
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request  returningResponse:&response error:&err];
    NSString *resSrt = [[NSString alloc]initWithData:responseData encoding:NSASCIIStringEncoding];
    
    //This is Response
    NSLog(@"auth: got response==%@", resSrt);
    //[_sharedLog enqueue: [NSString stringWithFormat:@"auth got response==%@",resSrt]];
    
    //2.1 parse response
    NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
    NSString* key = [jsonDictionary objectForKey:@"key"];
    
    return key;
    
}

- (NSString*) getSessionUrl{
    
    return (self.sessionStarted)? [self.connection sessionUrl] : nil;
}

-(Token*) getToken{
    
    //1. auth!
    _key  = [SettingsManager authenticate];
    
    //2. prepare

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://api.osmo.mobi/prepare"]];
    
    [request setHTTPMethod:@"POST"];
    
    NSString *body = [NSString stringWithFormat:@"key=%@&protocol=1", _key];
    
    NSData *data = [body dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPBody:data];
    
   
    NSError *err;
    NSURLResponse *response;
        
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request  returningResponse:&response error:&err];
        
    NSString *resSrt = [[NSString alloc]initWithData:responseData encoding:NSASCIIStringEncoding];
        
        
    //This is for Response
    NSLog(@"get token: got response==%@", resSrt);
    [_sharedLog enqueue:[NSString stringWithFormat:@"get token: got response==%@", resSrt]];
        
        
    //parse response
    NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
    
    Token *token = [[Token alloc] init];
    NSArray *server = [[jsonDictionary objectForKey:@"address"] componentsSeparatedByString:@":"];
    
    token.token = [jsonDictionary objectForKey:@"token"];
    token.address = [server objectAtIndex: 0];
    token.port = [[server objectAtIndex: 1] integerValue];
    
    return token;
}

-(void) tryConnect{
    Token* token = [self getToken];
    
    //3. create tcp communication
   
    [self setHandlerOnConnection];
    [self.connection createConnection: token];
    
}


- (void)setHandlerOnConnection {
    
    [self.connection addObserver:self forKeyPath: @"connected" options:NSKeyValueObservingOptionNew context:nil];
 
}
- (void)setHandlerOnOpenSession {
    
    [self.connection addObserver:self forKeyPath: @"sessionOpened" options:NSKeyValueObservingOptionNew context:nil];
    
}


-(void) openSession{
    if(self.connection.connected)
    {
        [self setHandlerOnOpenSession];
        [self.connection openSession];
    }
}

-(void) closeSession{
    if(self.connection.connected)
    {
        [self.connection closeSession];
    }
}



-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    
    if ([keyPath isEqualToString:@"connected"]) {
        NSLog(@"The connection status was changed.");
        NSLog(@"connected? %@", change);
        
        
        [_sharedLog enqueue: [NSString stringWithFormat: @"connected? %@", change]];
        
        
        if([[change valueForKey:@"new"] boolValue]) [self setValue:[NSNumber numberWithBool:YES]  forKey:@"connectionOpened"];
        else [self setValue:[NSNumber numberWithBool:NO]  forKey:@"connectionOpened"];
        
        //[self.connection openSession];
        
    }
    
    if ([keyPath isEqualToString:@"sessionOpened"]) {
        
        [_sharedLog enqueue: [NSString stringWithFormat: @"sessionOpened? %@", change]];
        if([[change valueForKey:@"new"] boolValue]) [self setValue:[NSNumber numberWithBool:YES]  forKey:@"sessionStarted"];
        else [self setValue:[NSNumber numberWithBool:NO]  forKey:@"sessionStarted"];
        
        

        if([[change valueForKey:@"new"] boolValue])
        {
            
            [self.monitoring initWith: self.connection];
            [self.monitoring turnMonitoringOn];
        }
        else [self.monitoring turnMonitoringOff];
        
    }
   
}


@end
