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
    
  
    static func getKey(_ forKey: SettingKeys) -> NSString?{
        
        getKeyFromSettings(forKey)
        
        return key
    }
    
    static func clearKeys() {
        SettingsManager.setKey("", forKey: SettingKeys.device)
        SettingsManager.setKey("", forKey: SettingKeys.user)
        SettingsManager.setKey("", forKey: SettingKeys.trackerId)
        GroupManager.sharedGroupManager.clearCache()

    }
    static func setKey(_ key: NSString, forKey: SettingKeys){
        if let getPath = getSettingPath as String?, let fileData = NSMutableDictionary(contentsOfFile: getPath){
            
            fileData.setValue(key, forKey: forKey.rawValue)
            fileData.write(toFile: getPath, atomically: true)
        }
    }
    
    fileprivate static func getKeyFromSettings(_ forKey: SettingKeys){

        let fileManager = FileManager.default
       
        if let getPath = getSettingPath as String? {
            
            if !fileManager.fileExists(atPath: getPath){
                
                if let bundle = Bundle.main.path(forResource: "settings", ofType: "plist"){
                    do {
                        try fileManager.copyItem(atPath: bundle, toPath: getPath)
                    }catch {
                    }
                }
            }
            
            if let savedKey = NSMutableDictionary(contentsOfFile: getPath){
                key = savedKey.object(forKey: forKey.rawValue) as? NSString
            }
        }
    }
    
    fileprivate static var getSettingPath: NSString? {
        
        get {
            
            if let path = settingPath {
                return path
            } else {
                
                let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
                let documentDirectory = paths[0] as NSString
                settingPath = documentDirectory.appendingPathComponent("settings.plist") as NSString?
                return settingPath
            }
        }
    }
    
    
}
