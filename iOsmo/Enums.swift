//
//  Enums.swift
//  iOsmo
//
//  Created by Olga Grineva on 13/12/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//

import Foundation

enum TagsOld: String{
    case token = "TOKEN|"
    case openSession = "TRACKER_SESSION_OPEN|"
    case closeSession = "TRACKER_SESSION_CLOSE"
    case ping = "P"
    case pong = "PP"
    case kick = "KICK|"
    case remotePP = "REMOTE_CONTROL|PP"
    case coordinate = "T"
}

enum Tags: String {
    case token = "INIT|"
    case auth = "AUTH|"
    
    case openSession = "TO"
    case closeSession = "TC"
    case ping = "P"
    case getGroups = "GROUP"
    case enterGroup = "GE:"
    case leaveGroup = "GL:"
    case activateGroup = "GA:"
    case deactivateGroup = "GD:"
    case remoteCommandResponse = "RCR:"
    case activatePoolGroups = "PG"
    case groupSwitch = "GS"
}

enum KeysOld: String{
    case trackerId = "tracker_id"
    case sessionUrl = "url"
    case key = "key"
    case token = "token"
    case address = "address"
}

enum Keys: String{
    case token = "token"
    case address = "address"
    case uid = "uid"
    case name = "name"
    case key = "device"
    case error = "error"
    case errorDesc = "error_description"
}

enum ParseKeys: String{
    case sessionUrl = "url"
    case getGroups = "GROUP"
    case status = "status"
    case gda = "GDA"
    case gaa = "GAA"
    case id = "id"
}


enum AnswTags: String{
    case openedSession = "TO|"
    case getGroups = "GROUP"
    case activateGroup = "GA:"
    case deactivateGroup = "GD:"
    case enterGroup = "GE:"
    case leaveGroup = "GL:"
    case remoteCommand = "RC:"
    //case activatePG = "PG"
    case bye = "BYE|"
    case kick = "KICK|"
    case pong = "PP"
    case coordinate = "T|"
    case closeSession = "TC|"
    case token = "INIT|"
    case auth = "AUTH|"
    case gda = "GDA|"
    case gaa = "GAA|"
    case grCoord = "G:"
    
}

enum UpdatesEnum: String {
    
   // case OpenConnection = "connected"
    case SessionStarted = "sessionOpened"
    
}

enum SettingKeys: String {
    case device = "deviceKey"
    case auth = "authKey"
    case isStayAwake = "isStayAwake"
    case user = "user"
    case sendTime = "sendTime"
    case logView = "logView"
    case poolGroups = "poolGroups"
}

enum GroupActions: String {
    case view = "view" //default
    case enter = "enter"
    case new = "new"
    case leave = "leave"
}

enum RemoteCommand: String {
    case TRACKER_GCM_ID = "80"
    case TRACKER_BATTERY_INFO = "11"
    case TRACKER_SATELLITES_INFO = "13"
    case TRACKER_SYSTEM_INFO = "14"
    case TRACKER_WIFI_INFO = "20"
    case TRACKER_WIFI_ON = "21"
    case TRACKER_WIFI_OFF = "22"
    case TRACKER_VIBRATE = "41"
    case TRACKER_EXIT = "42"
    case TRACKER_GET_PREFS = "43"
    case TRACKER_SET_PREFS = "44"
    case TRACKER_SESSION_CONTINUE = "5"
    case TRACKER_SESSION_PAUSE = "6"
    case TRACKER_SESSION_START = "1"
    case TRACKER_SESSION_STOP = "2"
}
