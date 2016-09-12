
//
//  LocationTracker.swift
//  iOsmo
//
//  Created by Olga Grineva on 16/12/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//

import Foundation
import CoreLocation

public class LocationTracker: NSObject, CLLocationManagerDelegate {
    
    private let log = LogQueue.sharedLogQueue
    
    private var allSessionLocations = [LocationModel]()
    private var lastLocations = [LocationModel]()
    public var distance = 0.0;
    
    
    class var sharedLocationManager : CLLocationManager {
        struct Static {
            static let instance: CLLocationManager = CLLocationManager()
        }
        
        return Static.instance
    }
    
    override init(){
        super.init()
    }
    
    public func turnMonitorinOn(){
       
        if CLLocationManager.locationServicesEnabled() == false {
        
            print("location services enabled false!")
            log.enqueue("location services enabled FALSE!")
        
        }
        else
        {
            let authorizationStatus = CLLocationManager.authorizationStatus()
            if (authorizationStatus ==  CLAuthorizationStatus.Restricted ||
                authorizationStatus == CLAuthorizationStatus.Denied){
                    print("authorization failed")
                    log.enqueue("authorization failed")
            }
            else {
                
                print("authorization status authorized")
                log.enqueue("authorization status authorized")
                
                let locationManager = LocationTracker.sharedLocationManager
                locationManager.delegate = self
                locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
                locationManager.distanceFilter = kCLDistanceFilterNone
                locationManager.pausesLocationUpdatesAutomatically = false
                
                let aSelector : Selector = #selector(NSProcessInfo.isOperatingSystemAtLeastVersion(_:))
                let higher8 = NSProcessInfo.instancesRespondToSelector(aSelector)
                
                if higher8 {
                    
                    locationManager.requestAlwaysAuthorization()
                    if #available(iOS 9, *){
                        locationManager.allowsBackgroundLocationUpdates = true
                    }
                    log.enqueue("request always authorization was sent to user")
                }
                
                locationManager.startUpdatingLocation()
                
                print("start coordinate monitoring")
                log.enqueue("start coordinate monitoring")
            }
        }
        
    }
    
    
    public func turnMonitoringOff(){
        print("monitoring was stopped")
        log.enqueue("montoring was stopped")
        
        LocationTracker.sharedLocationManager.stopUpdatingLocation()
    }
    
    
    public func getLastLocations() -> [LocationModel]{
        
        let getLastLocations = self.lastLocations
        self.lastLocations = [LocationModel]()
        
        return getLastLocations
    }
    
    public func locationManager(manager: CLLocationManager,
        didChangeAuthorizationStatus status: CLAuthorizationStatus){
        
        print("didChangeAuthorizationStatus")
        log.enqueue("didChangeAuthorizationStatus")
    }
    
    public func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]){
        print("didUpdateLocation")
        log.enqueue("didUpdateLocation")
        var prev_loc = locations.first
        if ((lastLocations.last) != nil) {
            prev_loc = CLLocation(latitude: (lastLocations.last?.lat)!, longitude: (lastLocations.last?.lon)!)
        }
        for loc in locations {
                let theCoordinate = loc.coordinate
                let theAccuracy = loc.horizontalAccuracy
                let theAltitude = loc.altitude
            
            
                let locationAge = -loc.timestamp.timeIntervalSinceNow
            
                if locationAge > 30 {continue}
                
                //select only valid location and also location with good accuracy
                if (theAccuracy > 0 && theAccuracy < 2000 && !(theCoordinate.latitude==0.0 && theCoordinate.longitude==0.0)){
                    var locationModel:LocationModel = LocationModel(lat: theCoordinate.latitude, lon: theCoordinate.longitude)
                    //add others values
                    locationModel.accuracy = Int(theAccuracy)
                    locationModel.speed = loc.speed as Double
                    locationModel.alt = (loc.verticalAccuracy > 0) ? Int(theAltitude) : 0
                    
                    let distanceInMeters = loc.distanceFromLocation(prev_loc!)
                    distance = distance + distanceInMeters
                    prev_loc = loc
                    
                    self.lastLocations.append(locationModel)
                    self.allSessionLocations.append(locationModel)
                    
                }
        }

    }
    
    public func locationManager(manager: CLLocationManager, didFailWithError error: NSError){
        print("locationManager error \(error)")
        log.enqueue("locationManager error \(error)")
        
        switch (error.code){
        	case CLError.Network.rawValue:
                print("network")
            case CLError.Denied.rawValue:
                print("denied")
            default:
                print("some error")
        }
    }
    
    
}