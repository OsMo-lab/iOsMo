//
//  FirstViewController.swift
//  iOsmo
//
//  Created by Olga Grineva on 07/12/14.
//  Copyright (c) 2014 Olga Grineva, (c) 2016 Alexey Sirotkin. All rights reserved.
//


import UIKit
import CoreLocation
import FirebaseAnalytics

class MonitoringViewController: UIViewController, UIActionSheetDelegate/*, RMMapViewDelegate*/{
    
    required init(coder aDecoder: NSCoder) {
        
        log = LogQueue.sharedLogQueue
        connectionManager = ConnectionManager.sharedConnectionManager
        sendingManger = SendingManager.sharedSendingManager
        groupManager = GroupManager.sharedGroupManager

        super.init(coder: aDecoder)!
    }

    var connectionManager: ConnectionManager
    var sendingManger: SendingManager
    var sessionTimer: SessionTimer?
    let groupManager: GroupManager
   
    var log: LogQueue
    var isMonitoringOn = false

    var isSessionPaused = false
    var isTracked = true
    
    var onMessageOfTheDayUpdated: ObserverSetEntry<(Int, String)>?
    var onSessionPaused: ObserverSetEntry<(Int)>?
    var onSessionStarted: ObserverSetEntry<(Int)>?
    var onGroupListUpdated: ObserverSetEntry<[Group]>?
    
    @IBOutlet weak var userLabel: UILabel!
    @IBOutlet weak var trackerID: UIButton!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var avgSpeedLabel: UILabel!
    @IBOutlet weak var MDView: UITextView!
    
    @IBOutlet weak var osmoImage: UIImageView!
    @IBOutlet weak var osmoStatus: UIImageView!
    @IBOutlet weak var gpsConnectionImage: UIImageView!
    @IBOutlet weak var playStopBtn: UIButton!

    @IBOutlet weak var pauseBtn: UIButton!
    @IBOutlet weak var slider: UIScrollView!
    @IBOutlet weak var link: UIButton!
    
    @IBOutlet weak var sliderImg: UIView!
    @IBOutlet weak var fronSliderImg: UIView!
    
    @IBOutlet weak var trackingModeBtn: UIButton!

    @IBAction func pauseClick(_ sender: AnyObject) {
        
        isSessionPaused = !isSessionPaused
        
        if isMonitoringOn {
            Analytics.logEvent("trip_pause", parameters: nil)
            sendingManger.pauseSendingCoordinates("")
        } else {
            sendingManger.startSendingCoordinates("")
        }
    }
    
    @IBAction func GoByLink(_ sender: UIButton) {
        if let sessionUrl = connectionManager.sessionUrl, let url = sessionUrl.addingPercentEncoding (withAllowedCharacters: CharacterSet.urlQueryAllowed) {
            
            if let checkURL = URL(string: url) {
                let safariActivity = SafariActivity()
                let activityViewController = UIActivityViewController(activityItems: [checkURL], applicationActivities: [safariActivity])
                activityViewController.popoverPresentationController?.sourceView = sender
                self.present(activityViewController, animated: true, completion: {})
            }
        } else {
            log.enqueue("error: invalid url")
        }

    }
    
    @IBAction func MonitoringAction(_ sender: AnyObject) {
        if isSessionPaused || isMonitoringOn {
            Analytics.logEvent("trip_stop", parameters: nil)
            sendingManger.stopSendingCoordinates("")
            
            //UIApplication.shared.isIdleTimerDisabled = false
        } else {
            Analytics.logEvent("trip_start", parameters: nil)
            sendingManger.startSendingCoordinates("")
            
            //UIApplication.shared.isIdleTimerDisabled = SettingsManager.getKey(SettingKeys.isStayAwake)!.boolValue
        }
    }

    func uiSettings(){
        //TODO: make for different iPhoneSizes
        //slider.contentSize = CGSize(width: 640, height: 458)
        slider.contentSize = CGSize(width: self.view.frame.width * 2, height: self.view.frame.height)
        MDView.text = ""

        //UITabBar.appearance().tintColor = UIColor(red: 255/255, green: 102/255, blue: 0/255, alpha: 1.0)

        //sliderImg.roundCorners([.TopRight , .BottomRight], radius: 2)
        //fronSliderImg.roundCorners([.TopLeft , .BottomLeft], radius: 2)
    }
    
    fileprivate func updateSessionValues(_ elapsedTime: Int){
    
        let (h, m, s) = durationBySecond(seconds: elapsedTime)
        let strH: String = h > 9 ? "\(h):" : h == 0 ? "" : "0\(h):"
        let strM: String = m > 9 ? "\(m):" : "0\(m):"
        let strS: String = s > 9 ? "\(s)" : "0\(s)"
        
        if let timeLabel = self.timeLabel {
            timeLabel.text = "\(strH)\(strM)\(strS)"
            
        }
        let distance = sendingManger.locationTracker.distance;
        if let distanceLabel = self.distanceLabel {
            distanceLabel.text = String(format:"%.2f", distance)
        }
        
        let locs: [LocationModel] = sendingManger.locationTracker.lastLocations

        if let loc = locs.last {
            var speed = loc.speed * 3.6
            if speed < 0 {
                speed = 0
            }
            if let speedLabel = self.avgSpeedLabel {
                speedLabel.text = String(format:"%.0f", speed)
            }
           
        }

    }
    
    fileprivate func durationBySecond(seconds s:Int) -> (hours: Int, minutes: Int, seconds: Int){
        
        return ((s % (24*3600))/3600, s%3600/60, s%60)
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(false)
        
    }
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
                
        sendingManger.sentObservers.add(self, type(of: self).onSentCoordinate)
       
        sessionTimer = SessionTimer(handler: updateSessionValues)
        
        uiSettings()
        //setup handler for open connection
        connectionManager.dataSendStart.add {
            DispatchQueue.main.async {
                self.osmoImage.image = UIImage(named:"small-blue")
            }
        }
        connectionManager.dataSendEnd.add {
            DispatchQueue.main.async {
                self.osmoImage.image = UIImage(named:"small-green")
            }
        }
        connectionManager.connectionStart.add{
            DispatchQueue.main.async {
                self.osmoImage.image = UIImage(named:"small-yellow")
            }
        }
        connectionManager.connectionClose.add{
            DispatchQueue.main.async {
                self.osmoImage.image = UIImage(named:"small-red")
            }
        }
        connectionManager.connectionRun.add{
            let theChange = ($0.0 == 0)
            
            if theChange {
                self.onMessageOfTheDayUpdated = self.connectionManager.messageOfTheDayReceived.add{
                    self.MDView.text = $1
                }
                self.groupManager.groupList(true)
                self.connectionManager.getMessageOfTheDay()
                
            } else if let glUpdated = self.onGroupListUpdated {
                
                self.groupManager.groupListUpdated.remove(glUpdated)
            }
            DispatchQueue.main.async {
                if let user = SettingsManager.getKey(SettingKeys.user) {
                    if user.length > 0 {
                        self.userLabel.text = user as String
                    } else {
                        self.userLabel.text = ""
                    }
                } else {
                    self.userLabel.text = ""
                }
                
                if let trackerId = self.connectionManager.TrackerID{
                    self.trackerID.setTitle("TrackerID:\(trackerId)", for: UIControlState())
                } else {
                    self.trackerID.setTitle("", for: UIControlState())
                }
                self.osmoImage.image = theChange ? UIImage(named:"small-green")! : UIImage(named:"small-red")!
                
            }
            
            self.log.enqueue("MVC: The connection status was changed: \(theChange)")
            
            //self.osmoStatus.isHidden = !theChange
            
            if !theChange && !$0.1.isEmpty {
                self.alert(NSLocalizedString("Error", comment:"Error title for alert"), message: $0.1)
            }
        }
        
        connectionManager.sessionRun.add{
            let theChange = ($0.0 == 0)
            
            self.isMonitoringOn = theChange
            
            
            if theChange {
                if let sUrl = self.connectionManager.sessionUrl {
                    self.link.setTitle(sUrl, for: UIControlState())
                    self.link.isEnabled = true
                }
                
                self.log.enqueue("MVC: The session was opened")
                
                self.playStopBtn.setImage(UIImage(named: "stop-100"), for: UIControlState())
                self.pauseBtn.isHidden = false
                
                if self.sessionTimer != nil && !self.sessionTimer!.IsStarted {
                    self.sessionTimer!.reset()
                }
                
            } else {
                
                self.link.setTitle($0.1.isEmpty ? NSLocalizedString("session was closed", comment:"session was closed") : $0.1, for: UIControlState())
                self.link.isEnabled = false
                
                self.log.enqueue("MVC: The session was closed")
                
                self.pauseBtn.isHidden = true
                self.playStopBtn.setImage(UIImage(named: "play-100"), for: UIControlState())
                self.isSessionPaused = false
                self.pauseBtn.setImage(UIImage(named: "pause-32"), for: UIControlState())
                //if self.mainAnnotation != nil {self.mapView.removeAnnotation(self.mainAnnotation!)}
                //self.mainAnnotation = nil
                
                if let sessionTimer = self.sessionTimer {
                    sessionTimer.stop()
                }
            }
        }
        
        self.onSessionPaused = sendingManger.sessionPaused.add{
            if $0 == 0 {
                self.isMonitoringOn = false
                self.isSessionPaused = true
                self.pauseBtn.setImage(UIImage(named: "play-32"), for: UIControlState())
                if let sessionTimer = self.sessionTimer {
                    sessionTimer.stop()
                }
            }
        }
        
        self.onSessionStarted = sendingManger.sessionStarted.add{
            if $0 == 0 {
                self.isMonitoringOn = true
                self.isSessionPaused = false
                self.pauseBtn.setImage(UIImage(named: "pause-32"), for: UIControlState())
                if let sessionTimer = self.sessionTimer {
                    sessionTimer.start()
                }
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        // Dispose of any resources that can be recreated.
    }

    //handler for sent coordinate
    func onSentCoordinate(_ location: LocationModel){
        
        //moveToPosition(location)
        //drawLocationOnMap([location])
    }
    
    
//MARK:  MapViewInteraction
   /*
    func moveToPosition(location: LocationModel){
        //self.mapView.setCenterCoordinate(CLLocationCoordinate2D(latitude: location.lat, longitude: location.lon), animated: true)
//        
//        if (mainAnnotation == nil){
//            
//            let degreeRadius = 9000.0 / 110000.0 // (9000m / 110km per degree latitude)
//            
//            
//            let southWest = CLLocationCoordinate2D(latitude: location.lat - degreeRadius, longitude: location.lon - degreeRadius)
//            let northEast = CLLocationCoordinate2D(latitude: location.lat + degreeRadius, longitude: location.lon + degreeRadius)
//            
//            var zoomBounds = RMSphericalTrapezium(southWest: southWest, northEast: northEast)
//            
//            self.mapView.zoomWithLatitudeLongitudeBoundsSouthWest(zoomBounds.southWest, northEast: zoomBounds.northEast, animated: true)
//            
//            self.mapView.zoom = 20
//        }
    }
  */
//
//    func mapView(mapView: RMMapView!, layerForAnnotation annotation: RMAnnotation!) -> RMMapLayer!{
//        
//        
//        if let ann = annotation {
//            if ann.isUserLocationAnnotation { return nil }
//        }
//        
//        var shape: RMShape
//        
//        if let layer = annotation.layer as? RMShape {
//            shape = layer
//        }
//        else { shape = RMShape(view: mapView) }
//        
//
//        shape.lineColor = UIColor.orangeColor()
//        shape.lineWidth = 5.0
//        
//        var locations = annotation.userInfo as! Array<CLLocation>
//        
//        
//        for location in locations {
//            
//            shape.addLineToCoordinate(location.coordinate)
//            shape.moveToCoordinate(location.coordinate)
//        }
//        
//        return shape
//    }

    //do not delete, useful for debugging
//    func mapView(mapView: RMMapView!, didUpdateUserLocation userLocation: RMUserLocation!) {
//        
//        LogQueue.sharedLogQueue.enqueue("map box update location lat: \(userLocation.location.coordinate.latitude) and lon:\(userLocation.location.coordinate.longitude)")
//        
//    }
    

    /*
    func mapView(mapView: RMMapView!, layerForAnnotation annotation: RMAnnotation!) -> RMMapLayer! {
        
        if annotation.isUserLocationAnnotation { return nil }
        if let info = annotation.userInfo as? User {
           
            let marker = RMMarker(mapboxMarkerImage: "circle-stroked", tintColorHex: info.color)
            
            marker!.changeLabelUsingText(info.name, position: CGPoint(x: 0, y: -18))
            return marker
            
        }
        return nil
    }
    */

    
    
    
    /*
    func mapView(mapView: RMMapView!, didChangeUserTrackingMode mode: RMUserTrackingMode, animated: Bool) {
        
        let isTrack = (mode.rawValue == RMUserTrackingModeFollow.rawValue) ? true : false
        
        if isTrack {
            trackingModeBtn.setImage(UIImage(named: "lock-25"), forState: UIControlState.Normal)
        }
        else {
            trackingModeBtn.setImage(UIImage(named: "unlock-25"), forState: UIControlState.Normal)
        }
        
        isTracked = isTrack
        
    }
    */
    
    
    func alert(_ title: String, message: String) {
        if let getModernAlert: AnyClass = NSClassFromString("UIAlertController") { // iOS 8
            let myAlert: UIAlertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            myAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(myAlert, animated: true, completion: nil)
        } else { // iOS 7
            let alert: UIAlertView = UIAlertView()
            alert.delegate = self
            
            alert.title = title
            alert.message = message
            alert.addButton(withTitle: "OK")
            
            alert.show()
        }
    }

}



