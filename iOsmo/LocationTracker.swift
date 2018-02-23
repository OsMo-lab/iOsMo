
//
//  LocationTracker.swift
//  iOsmo
//
//  Created by Olga Grineva on 16/12/14.
//  Copyright (c) 2014 Olga Grineva, (c) 2017 Alexey Sirotkin All rights reserved.
//


import CoreLocation
import CoreMotion

open class LocationTracker: NSObject, CLLocationManagerDelegate {
    
    fileprivate let log = LogQueue.sharedLogQueue
    private let motionManager = CMMotionActivityManager()
    
    
    fileprivate var allSessionLocations = [LocationModel]()
    open var lastLocations = [LocationModel]()
    open var distance = 0.0;
    var isDeferingUpdates = false;
    var isGettingLocationOnce = false;
    
    class var sharedLocationManager : CLLocationManager {
        struct Static {
            static let instance: CLLocationManager = CLLocationManager()
        }
        
        return Static.instance
    }
    
    override init(){
        super.init()
        
        let locationManager = LocationTracker.sharedLocationManager
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.allowsBackgroundLocationUpdates = true

    }
    
    private func setActiveMode(_ moving: Bool) {
        log.enqueue("CMMotionActivityManager moving \(moving)")
        if moving {
            LocationTracker.sharedLocationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            LocationTracker.sharedLocationManager.distanceFilter = kCLDistanceFilterNone
        } else {
            LocationTracker.sharedLocationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            LocationTracker.sharedLocationManager.distanceFilter = 100
        }
    }
    
    open func turnMonitorinOn(once : Bool){
        self.distance = 0
        self.isDeferingUpdates = false
        self.isGettingLocationOnce = once
       
        if CLLocationManager.locationServicesEnabled() == false {
            log.enqueue("Location services enabled FALSE!")
        } else {
            let authorizationStatus = CLLocationManager.authorizationStatus()
            if (authorizationStatus ==  CLAuthorizationStatus.restricted ||
                authorizationStatus == CLAuthorizationStatus.denied){
                    log.enqueue("Location authorization failed")
            } else {
                log.enqueue("Location authorization status authorized")

                if #available(iOS 8, *){
                    LocationTracker.sharedLocationManager.requestAlwaysAuthorization()
                    log.enqueue("Location request always authorization was sent to user")
                }
                
                if (once) {
                    log.enqueue("requestLocation")
                    LocationTracker.sharedLocationManager.requestLocation()
                } else {
                    log.enqueue("startUpdatingLocation")
                    LocationTracker.sharedLocationManager.startUpdatingLocation()
                    //LocationTracker.sharedLocationManager.startMonitoringSignificantLocationChanges()
                    
                    motionManager.startActivityUpdates(to: .main, withHandler: { [weak self] activity in
                        self?.setActiveMode((activity?.stationary)! ? false : true)
                    })
                
                }
                
                
            }
        }
        
    }
    
    
    open func turnMonitoringOff(){
        LocationTracker.sharedLocationManager.stopUpdatingLocation()
        LocationTracker.sharedLocationManager.disallowDeferredLocationUpdates()
        log.enqueue("stopUpdatingLocation")
        self.isDeferingUpdates = false
    }
    
    
    open func getLastLocations() -> [LocationModel]{
        let getLastLocations = self.lastLocations
        self.lastLocations = [LocationModel]()
        
        return getLastLocations
    }
    
    open func locationManager(_ manager: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus){
        log.enqueue("Location didChangeAuthorizationStatus to \(status.rawValue)")
    }
    
    open func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]){
        log.enqueue("didUpdateLocation")
        var prevLM = allSessionLocations.last
        var prev_loc = locations.first
        /*
        if ((lastLocations.last) != nil) {
            //prev_loc = CLLocation(latitude: (lastLocations.last?.lat)!, longitude: (lastLocations.last?.lon)!)
            
            prev_loc = CLLocation(coordinate: CLLocationCoordinate2D(latitude: (lastLocations.last?.lat)!, longitude: (lastLocations.last?.lon)!), altitude: CLLocationDistance((lastLocations.last?.alt)!), horizontalAccuracy: CLLocationAccuracy((lastLocations.last?.accuracy)!), verticalAccuracy: 0, timestamp: (lastLocations.last?.time)!)
 
        }*/
        if (prevLM != nil) {
            //prev_loc = CLLocation(latitude: (lastLocations.last?.lat)!, longitude: (lastLocations.last?.lon)!)
            
            prev_loc = CLLocation(coordinate: CLLocationCoordinate2D(latitude: (prevLM?.lat)!, longitude: (prevLM?.lon)!), altitude: CLLocationDistance((prevLM?.alt)!), horizontalAccuracy: CLLocationAccuracy((prevLM?.accuracy)!), verticalAccuracy: 0, timestamp: (prevLM?.time)!)
            
        }
        
        let locInterval = SettingsManager.getKey(SettingKeys.sendTime)!.doubleValue;
        let locDistance = SettingsManager.getKey(SettingKeys.locDistance)!.doubleValue;
        
        for loc in locations {
            let theCoordinate = loc.coordinate
            let theAccuracy = loc.horizontalAccuracy
            let theAltitude = loc.altitude

            if (-loc.timestamp.timeIntervalSinceNow > 60){
                continue
            }
            //let locationAge = loc.timestamp.timeIntervalSince((prev_loc?.timestamp)!)
            let prevAge = (prevLM != nil ? loc.timestamp.timeIntervalSince((prevLM?.time)!):0)
            
            //select only valid location and also location with good accuracy
            if (theAccuracy > 0 && theAccuracy < 2000 && !(theCoordinate.latitude==0.0 && theCoordinate.longitude==0.0) && (((prev_loc?.coordinate.latitude != loc.coordinate.latitude && prev_loc?.coordinate.longitude != loc.coordinate.longitude) || lastLocations.last == nil || self.isGettingLocationOnce))){
                if ((prevAge >= locInterval) || (lastLocations.last == nil) || self.isGettingLocationOnce) {
                    var locationModel:LocationModel = LocationModel(lat: theCoordinate.latitude, lon: theCoordinate.longitude)
                    //add others values
                    locationModel.accuracy = Int(theAccuracy)
                    locationModel.speed = loc.speed as Double
                    locationModel.course = Float(loc.course)
                    locationModel.alt = (loc.verticalAccuracy > 0) ? Int(theAltitude) : 0
                    locationModel.time = loc.timestamp
                    
                    let distanceInMeters = loc.distance(from: prev_loc!)
                    distance = distance + distanceInMeters / 1000
                    prev_loc = loc
                    self.lastLocations.append(locationModel)
                    if !(self.isGettingLocationOnce) {
                        self.allSessionLocations.append(locationModel)
                    }
                    
                    prevLM = locationModel;
                }
            }
        }
        
        //Копим изменения координат в фоне более 100 метров или 60 секунд
        if (isDeferingUpdates == false && (locInterval > 10 || locDistance > 50 )) {
            self.isDeferingUpdates = true
            manager.allowDeferredLocationUpdates(untilTraveled: locDistance, timeout: locInterval)
        }
    }

    open func locationManager(_ manager: CLLocationManager, didFailWithError error: Error){
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
    
    open func locationManager(_ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: Error?) {
        if (error != nil) {
            log.enqueue("locationManager didFinishDeferredUpdatesWithError \(error)")
        }
        self.isDeferingUpdates = false
    }
    
}
