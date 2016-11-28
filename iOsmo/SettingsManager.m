//
//  SettingsManager.m
//  ping
//
//  Created by Olga Grineva on 10/11/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//

#import "SettingsManager.h"
#import "ConnectionManager.h"

@implementation SettingsManager

NSString * key;
NSString *settingsPath;


+ (NSString*) authenticate {
    
    if(key != nil)
        return key;
    
    [self getKeyFromSettings];
    
    if (key == nil || [key length] == 0)
    {
        key = [ConnectionManager authenticate];
        
        NSMutableDictionary *data = [[NSMutableDictionary alloc] initWithContentsOfFile: settingsPath];
        
        
        [data setObject: key forKey:@"deviceKey"];
        [data writeToFile: settingsPath atomically:YES];
        
    }

    return key;
}

+(NSString*) getSettingsPath {
    
    if(settingsPath == nil)
    {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        settingsPath = [documentsDirectory stringByAppendingPathComponent:@"settings.plist"];
    }
    return settingsPath;
}


+(void) getKeyFromSettings{
    
    NSError *error;
    
    [SettingsManager getSettingsPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath: settingsPath])
    {
        NSString *bundle = [[NSBundle mainBundle] pathForResource:@"settings" ofType: @"plist"];
        
        [fileManager copyItemAtPath:bundle toPath: settingsPath error:&error];
    }
    
    NSMutableDictionary *savedKey = [[NSMutableDictionary alloc] initWithContentsOfFile: settingsPath];
    
    //load from savedStock example int value
    key =[savedKey objectForKey:@"deviceKey"];
    
    
    
}
@end
