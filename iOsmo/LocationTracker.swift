
//
//  LocationTracker.swift
//  iOsmo
//
//  Created by Olga Grineva on 16/12/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//

import Foundation
import CoreLocation

open class LocationTracker: NSObject, CLLocationManagerDelegate {
    
    fileprivate let log = LogQueue.sharedLogQueue
    
    fileprivate var allSessionLocations = [LocationModel]()
    open var lastLocations = [LocationModel]()
    open var distance = 0.0;
    
    
    class var sharedLocationManager : CLLocationManager {
        struct Static {
            static let instance: CLLocationManager = CLLocationManager()
        }
        
        return Static.instance
    }
    
    override init(){
        super.init()
    }
    
    open func turnMonitorinOn(){
       
        if CLLocationManager.locationServicesEnabled() == false {
        
            print("location services enabled false!")
            log.enqueue("location services enabled FALSE!")
        
        }
        else
        {
            let authorizationStatus = CLLocationManager.authorizationStatus()
            if (authorizationStatus ==  CLAuthorizationStatus.restricted ||
                authorizationStatus == CLAuthorizationStatus.denied){
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
               
                if #available(iOS 8, *){
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
    
    
    open func turnMonitoringOff(){
        print("monitoring was stopped")
        log.enqueue("montoring was stopped")
        
        LocationTracker.sharedLocationManager.stopUpdatingLocation()
    }
    
    
    open func getLastLocations() -> [LocationModel]{
        
        let getLastLocations = self.lastLocations
        self.lastLocations = [LocationModel]()
        
        return getLastLocations
    }
    
    open func locationManager(_ manager: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus){
        
        print("didChangeAuthorizationStatus")
        log.enqueue("didChangeAuthorizationStatus")
    }
    
    open func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]){
        //print("didUpdateLocation")
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
                    locationModel.course = Float(loc.course)
                    locationModel.alt = (loc.verticalAccuracy > 0) ? Int(theAltitude) : 0
                    
                    let distanceInMeters = loc.distance(from: prev_loc!)
                    distance = distance + distanceInMeters
                    prev_loc = loc
                    
                    self.lastLocations.append(locationModel)
                    self.allSessionLocations.append(locationModel)
                    
                }
        }

    }
    

    open func locationManager(_ manager: CLLocationManager, didFailWithError error: Error){
        print("locationManager error \(error)")
        log.enqueue("locationManager error \(error)")
        
        switch (error){
        	case CLError.Code.network:
                print("network")
            case CLError.Code.denied:
                print("denied")
            default:
                print("some error")
        }
    }
    
    
}
