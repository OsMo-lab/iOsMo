//
//  FirstViewController.swift
//  iOsmo
//
//  Created by Olga Grineva on 07/12/14.
//  Copyright (c) 2014 Olga Grineva, (c) 2016 Alexey Sirotkin. All rights reserved.
//


import UIKit
import CoreLocation

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
    
    var onGroupListUpdated: ObserverSetEntry<[Group]>?
    var onMonitoringGroupsUpdated: ObserverSetEntry<[UserGroupCoordinate]>?
    var inGroup: [Group]?
    var selectedGroupIndex: Int?
    var onMapNow = [String]()
    
    var isLoaded = false
    
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var avgSpeedLabel: UILabel!
    
    @IBOutlet weak var gpsConnectionImage: UIImageView!
    @IBOutlet weak var serverConnectionImg: UIImageView!
    @IBOutlet weak var playStopBtn: UIButton!

    @IBOutlet weak var pauseBtn: UIButton!
    @IBOutlet weak var slider: UIScrollView!
    @IBOutlet weak var copyButton: UIButton!
    @IBOutlet weak var connectionResult: UILabel!
    @IBOutlet weak var monitoringResult: UILabel!
    @IBOutlet weak var link: UIButton!
    
    @IBOutlet weak var sliderImg: UIView!
    @IBOutlet weak var fronSliderImg: UIView!
    
    @IBOutlet weak var trackingModeBtn: UIButton!

    @IBAction func selectGroupsClick(_ sender: AnyObject) {
        
        //let selectedGroupName = (selectedGroupIndex != nil) ? inGroup?[selectedGroupIndex!].name : nil
        
        let actionSheet = UIActionSheet(title: "select group", delegate: self, cancelButtonTitle: "cancel", destructiveButtonTitle: nil)
        
        if selectedGroupIndex != nil {
            
            actionSheet.destructiveButtonIndex = selectedGroupIndex! + 1
        }
        
        if let groups = inGroup {
            
            for group in groups{
                
                actionSheet.addButton(withTitle: group.name)
            }
            
            if selectedGroupIndex != nil { actionSheet.addButton(withTitle: "clear all") }
        }
        
        //actionSheet.showInView(self.mapView)
    }

    
    @IBAction func CopyLink(_ sender: AnyObject) {
        
        UIPasteboard.general.string = connectionManager.sessionUrl
    }

    
    @IBAction func pauseClick(_ sender: AnyObject) {
        
        isSessionPaused = !isSessionPaused
        
        if isMonitoringOn {
            
            sendingManger.pauseSendingCoordinates()
            isMonitoringOn = false
            pauseBtn.setImage(UIImage(named: "play-32"), for: UIControlState())
            self.monitoringResult.text = "is PAUSED"
            if let sessionTimer = self.sessionTimer { sessionTimer.stop()}
        }
        else {
            
            sendingManger.startSendingCoordinates()
            isMonitoringOn = true
            pauseBtn.setImage(UIImage(named: "pause-32"), for: UIControlState())
            self.monitoringResult.text = "is ON"
            if let sessionTimer = self.sessionTimer { sessionTimer.start()}
        }

    
    }
    
    @IBAction func GoByLink(_ sender: AnyObject) {
      
        
        if let sessionUrl = connectionManager.sessionUrl, let url = sessionUrl.addingPercentEncoding (withAllowedCharacters: CharacterSet.urlQueryAllowed) {
            
            if let checkURL = URL(string: url) {
                
                if UIApplication.shared.openURL(checkURL) {
                    print("url succefully opened")
                    log.enqueue("url successfully opened")
                }
            }
        }
        
        else {
        
            print("error: invalid url")
            log.enqueue("error: invalid url")
        }

    }
    
    @IBAction func MonitoringAction(_ sender: AnyObject) {
               
        if isSessionPaused || isMonitoringOn {
            
            sendingManger.stopSendingCoordinates()
            UIApplication.shared.isIdleTimerDisabled = false
            
        }
        else {
            
            sendingManger.startSendingCoordinates()
            UIApplication.shared.isIdleTimerDisabled = SettingsManager.getKey(SettingKeys.isStayAwake)!.boolValue
        }
    }
    
    
    func uiSettings(){
        //TODO: make for different iPhoneSizes
        //slider.contentSize = CGSize(width: 640, height: 458)
        slider.contentSize = CGSize(width: self.view.frame.width * 2, height: self.view.frame.height)

        UITabBar.appearance().tintColor = UIColor(red: 35/255, green: 159/255, blue: 151/255, alpha: 1.0)

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
            var speed = loc.speed
            if speed < 0 {
                speed = 0
            }
            if let speedLabel = self.avgSpeedLabel {
                speedLabel.text = String(format:"%.2f", speed)
            }
           
        }
        
        
        
    }
    
    fileprivate func durationBySecond(seconds s:Int) -> (hours: Int, minutes: Int, seconds: Int){
        
        return ((s % (24*3600))/3600, s%3600/60, s%60)
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(false)
        if !isLoaded {
            
            //setup handler for open connection
            connectionManager.connectionRun.add{
                
                
                let theChange = $0.0
                
                if theChange {
                    
                    self.onGroupListUpdated = self.groupManager.groupListUpdated.add{
                        self.inGroup = $0
                    }
                    self.groupManager.groupList()
                }
                else if let glUpdated = self.onGroupListUpdated {
                    
                    self.groupManager.groupListUpdated.remove(glUpdated)
                }
                
                
                print("MonitoringViewController: The connection status was changed: \(theChange)")
                self.log.enqueue("MonitoringViewController: The connection status was changed: \(theChange)")
                
                
                self.connectionResult.text = theChange ? "connection is ON" :  "connection is OFF"
                self.serverConnectionImg.image = theChange ? UIImage(named:"online-32")! : UIImage(named:"offline-32")!
                
                if !theChange && !$0.1.isEmpty {
                    
                    self.alert("Error", message: $0.1)
                }
                
            }
            
            connectionManager.sessionRun.add{
                
                let theChange = $0.0
                
                self.monitoringResult.text = theChange ? "is ON" : "is OFF"
                self.isMonitoringOn = theChange
                print("MonitoringViewController: The session was opened/closed.\(theChange)")
                
                if theChange {
                    
                    if let sUrl = self.connectionManager.sessionUrl {
                        self.link.setTitle(sUrl, for: UIControlState())
                        self.link.isEnabled = true
                        self.copyButton.isEnabled = true
                    }
                    
                    self.log.enqueue("Monitoring View Controller: The session was opened")
                    
                    self.playStopBtn.setImage(UIImage(named: "stop-100"), for: UIControlState())
                    self.pauseBtn.isHidden = false
                    
                    if self.sessionTimer != nil && !self.sessionTimer!.IsStarted {
                        self.sessionTimer!.reset()
                        self.sessionTimer!.start()
                    }
                }
                    
                else {
                    
                    self.link.setTitle($0.1.isEmpty ? "session was closed" : $0.1, for: UIControlState())
                    self.link.isEnabled = false
                    self.copyButton.isEnabled = false
                    
                    self.log.enqueue("Monitoring View Controller: The session was closed")
                    
                    
                    self.pauseBtn.isHidden = true
                    self.playStopBtn.setImage(UIImage(named: "play-100"), for: UIControlState())
                    self.isSessionPaused = false
                    self.pauseBtn.setImage(UIImage(named: "pause-32"), for: UIControlState())
                    //if self.mainAnnotation != nil {self.mapView.removeAnnotation(self.mainAnnotation!)}
                    //self.mainAnnotation = nil
                    
                    if let sessionTimer = self.sessionTimer { sessionTimer.stop()}
                }
                
            }
            
            connectionManager.connect()
            isLoaded = true
            
        }
    }
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
                
        sendingManger.sentObservers.add(self, type(of: self).onSentCoordinate)
       
        sessionTimer = SessionTimer(handler: updateSessionValues)
        
        uiSettings()
        //setupMapView()
        
        //setupLocationTrackingSettings()
        
        
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
    
    // This delegate method is where you tell the map to load a view for a specific annotation. To load a static MGLAnnotationImage, you would use `-mapView:imageForAnnotation:`.
    
    
    func clearPeople(_ people: String){
        /*
        let ann = mapView.annotations.filter{$0.title == "\(people)"}
        
        if ann.count > 0 {
            
            mapView.removeAnnotations(ann)
            if let element = onMapNow.indexOf("\(people)") {
                
                onMapNow.removeAtIndex(element)
            }
        }
 */
    }
    
    
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
    func actionSheet(_ actionSheet: UIActionSheet, clickedButtonAt buttonIndex: Int) {
        
        if actionSheet.buttonTitle(at: buttonIndex) == "clear all" {
            self.selectedGroupIndex = nil
            
            groupManager.updateGroupsOnMap([])
            
            if self.onMonitoringGroupsUpdated != nil {
                
                groupManager.monitoringGroupsUpdated.remove(self.onMonitoringGroupsUpdated!)
                self.onMonitoringGroupsUpdated = nil
            }
            for p in onMapNow {
                clearPeople("\(p)")
            }
            
            return
        }
        
        if buttonIndex != actionSheet.cancelButtonIndex {
            /*
            let group = inGroup?[buttonIndex - 1];
            let intValue = group!.id as Int;
            */
            if let group = inGroup?[buttonIndex - 1]  {
            
                let intValue = Int (group.id);
            
                groupManager.updateGroupsOnMap([intValue!])
                self.onMonitoringGroupsUpdated = groupManager.monitoringGroupsUpdated.add{
                    
                    for coord in $0 {
                        
                        //self.drawPeoples(coord)
                        
                    }
                }
                
                for p in onMapNow {
                    clearPeople("\(p)")
                }
                
                self.selectedGroupIndex = buttonIndex - 1

            }
        }
        
        
    }
    
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



