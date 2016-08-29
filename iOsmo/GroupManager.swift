//
//  GroupsManager.swift
//  iOsmo
//
//  Created by Olga Grineva on 08/04/15.
//  Copyright (c) 2015 Olga Grineva. All rights reserved.
//

import Foundation
public class GroupManager{

    
    var groupsOnMap: [Int] = [Int]()
    var allGroups: [Group]?
    var monitoringGroupsHandler: ObserverSetEntry<[UserGroupCoordinate]>?
    var monitoringGroupsUpdated = ObserverSet<[UserGroupCoordinate]>()
    
    
    var groupListUpdated = ObserverSet<[Group]>()
    var groupEntered = ObserverSet<(Bool, String)>()
    var groupLeft = ObserverSet<(Bool, String)>()
    
    var onGroupListUpdated: ObserverSetEntry<[Group]>?
    
    private let log = LogQueue.sharedLogQueue
    
    class var sharedGroupManager : GroupManager {
    
        struct Static {
            static let instance: GroupManager = GroupManager()
        }
        
        return Static.instance
    }
    
    let connection = ConnectionManager.sharedConnectionManager
    
    public func activateAllGroups(){
        
        connection.activateAllGroups()
    }
    
    public func deactivateAllGroups(){
    
        connection.deactivateAllGroups()
    }
    
    public func activateGroup(name: String){}
    
    public func deactivateGroup(name: String) {}
    

    
    var onEnterGroup : ObserverSetEntry<(Bool, String)>?
    var onLeaveGroup : ObserverSetEntry<(Bool, String)>?
    
    public func enterGroup(name: String, nick: String){
    
        self.onEnterGroup = connection.groupEntered.add{
        
            self.groupEntered.notify($0, $1)
            
            print("ENTERED! \($0) ")
            
            self.connection.groupEntered.remove(self.onEnterGroup!)
        }
        connection.enterGroup(name, nick: nick)
    }
    
    public func leaveGroup(u: String) {
        
        self.onLeaveGroup = connection.groupLeft.add{
            
            self.groupLeft.notify($0, $1)
            
            print("LEFT! \($0) ")
            
            self.connection.groupLeft.remove(self.onLeaveGroup!)
        }
        connection.leaveGroup(u)
    }
    
    public func groupList(){
        
        if self.onGroupListUpdated == nil {
            self.onGroupListUpdated = connection.groupList.add{
                
                self.allGroups = $0
                self.groupListUpdated.notify($0)
               
            }
        }
        
        connection.getGroups()
    }
    
    public func createGroup(){
        
        
        
    }
    
   
    
    public func updateGroupsOnMap(groups: [Int]){
        
        groupsOnMap = groups
        connection.monitoringGroups = groups
        
        if groups.count > 0 && self.monitoringGroupsHandler == nil {
            
            self.monitoringGroupsHandler = connection.monitoringGroupsUpdated.add({self.monitoringGroupsUpdated.notify($0)})
        }
        if groups.count == 0 && self.monitoringGroupsHandler != nil {
            
            connection.monitoringGroupsUpdated.remove(self.monitoringGroupsHandler!)
            self.monitoringGroupsHandler = nil
        }
    }
    

    public func getUser(group:  Int, user: Int) -> User? {
        
        let foundGroup = allGroups?.filter{$0.id == "\(group)"}.first
        return foundGroup?.users.filter{$0.device == "\(user)"}.first
    }
}
