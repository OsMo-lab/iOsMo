//
//  SettingManager.swift
//  iOsmo
//
//  Created by Olga Grineva on 14/12/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//

import Foundation

struct SettingsManager {

    static var key: NSString?
    static var settingPath: NSString?
    
    
    static func getKey(forKey: SettingKeys) -> NSString?{
        
        getKeyFromSettings(forKey)
        
        return key
    }
        
    static func setKey(key: NSString, forKey: SettingKeys){
       
        
        if let getPath = getSettingPath as? String, fileData = NSMutableDictionary(contentsOfFile: getPath){
            
            fileData.setValue(key, forKey: forKey.rawValue)
            fileData.writeToFile(getPath, atomically: true)
        }
    }
    
    private static func getKeyFromSettings(forKey: SettingKeys){

        let fileManager = NSFileManager.defaultManager()
       
        if let getPath = getSettingPath as? String {
            
            if !fileManager.fileExistsAtPath(getPath){
                
                if let bundle = NSBundle.mainBundle().pathForResource("settings", ofType: "plist"){
                    do {
                        try fileManager.copyItemAtPath(bundle, toPath: getPath)
                    }catch {
                    }
                }
                
            }
            
            if let savedKey = NSMutableDictionary(contentsOfFile: getPath){
                
                key = savedKey.objectForKey(forKey.rawValue) as? NSString
            }
            
        }
        
        
    }
    
    private static var getSettingPath: NSString? {
        
        get {
            
            if let path = settingPath {
                return path
            }
        else {
                
                let paths = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)
                if let documentDirectory = paths[0] as? NSString {
                    
                    settingPath = documentDirectory.stringByAppendingPathComponent("settings.plist")
                    return settingPath
                }
                
                return nil
        }
        }
    }
    
    
}
