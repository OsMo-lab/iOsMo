//
//  FirstViewController.swift
//  iOsmo
//
//  Created by Olga Grineva on 07/12/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//


import UIKit
import Mapbox


class MonitoringViewController: UIViewController, UIActionSheetDelegate, MGLMapViewDelegate/*, RMMapViewDelegate*/{
    
    required init(coder aDecoder: NSCoder) {
        
        log = LogQueue.sharedLogQueue
        connectionManager = ConnectionManager.sharedConnectionManager
        sendingManger = SendingManager.sharedSendingManager
        
        groupManager = GroupManager.sharedGroupManager
        
        super.init(coder: aDecoder)!

                //fatalError("init(coder:) has not been implemented")
    }


    var connectionManager: ConnectionManager
    var sendingManger: SendingManager
    var sessionTimer: SessionTimer?
    let groupManager: GroupManager
   
    var log: LogQueue
    var isMonitoringOn = false
    var mainAnnotation: MGLPointAnnotation?
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
    @IBOutlet weak var mapView: MGLMapView!
    @IBOutlet weak var copyButton: UIButton!
    @IBOutlet weak var connectionResult: UILabel!
    @IBOutlet weak var monitoringResult: UILabel!
    @IBOutlet weak var link: UIButton!
    
    @IBOutlet weak var sliderImg: UIView!
    @IBOutlet weak var fronSliderImg: UIView!
    
    @IBOutlet weak var trackingModeBtn: UIButton!

    @IBAction func selectGroupsClick(sender: AnyObject) {
        
        //let selectedGroupName = (selectedGroupIndex != nil) ? inGroup?[selectedGroupIndex!].name : nil
        
        let actionSheet = UIActionSheet(title: "select group", delegate: self, cancelButtonTitle: "cancel", destructiveButtonTitle: nil)
        
        if selectedGroupIndex != nil {
            
            actionSheet.destructiveButtonIndex = selectedGroupIndex! + 1
        }
        
        if let groups = inGroup {
            
            for group in groups{
                
                actionSheet.addButtonWithTitle(group.name)
            }
            
            if selectedGroupIndex != nil { actionSheet.addButtonWithTitle("clear all") }
        }
        
        actionSheet.showInView(self.mapView)
    }
    @IBAction func locateClick(sender: AnyObject) {
        if let location = mapView.userLocation?.location {
            mapView.setCenterCoordinate(location.coordinate, animated: true)
        }
    }
    
    @IBAction func CopyLink(sender: AnyObject) {
        
        UIPasteboard.generalPasteboard().string = connectionManager.sessionUrl
    }
    
    @IBAction func changeTrackingModeClick(sender: AnyObject) {
        
        isTracked = !isTracked
        setupLocationTrackingSettings()
    }
    
    @IBAction func pauseClick(sender: AnyObject) {
        
        isSessionPaused = !isSessionPaused
        
        if isMonitoringOn {
            
            sendingManger.pauseSendingCoordinates()
            isMonitoringOn = false
            pauseBtn.setImage(UIImage(named: "play-32"), forState: UIControlState.Normal)
            self.monitoringResult.text = "is PAUSED"
            if let sessionTimer = self.sessionTimer { sessionTimer.stop()}
        }
        else {
            
            sendingManger.startSendingCoordinates()
            isMonitoringOn = true
            pauseBtn.setImage(UIImage(named: "pause-32"), forState: UIControlState.Normal)
            self.monitoringResult.text = "is ON"
            if let sessionTimer = self.sessionTimer { sessionTimer.start()}
        }

    
    }
    
    @IBAction func GoByLink(sender: AnyObject) {
      
        
        if let sessionUrl = connectionManager.sessionUrl, url = sessionUrl.stringByAddingPercentEncodingWithAllowedCharacters (NSCharacterSet.URLQueryAllowedCharacterSet()) {
            
            if let checkURL = NSURL(string: url) {
                
                if UIApplication.sharedApplication().openURL(checkURL) {
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
    
    @IBAction func MonitoringAction(sender: AnyObject) {
               
        if isSessionPaused || isMonitoringOn {
            
            sendingManger.stopSendingCoordinates()
            UIApplication.sharedApplication().idleTimerDisabled = false
            
        }
        else {
            
            sendingManger.startSendingCoordinates()
            UIApplication.sharedApplication().idleTimerDisabled = SettingsManager.getKey(SettingKeys.isStayAwake)!.boolValue
        }
    }
    
    
    func setupMapView(){
        
        //let tileSource = RMOpenStreetMapSource()
        //self.mapView.tileSource = tileSource
        //var hello = tileSource.shortAttribution
        //self.mapView.styleURL = MGLStyle.outdoorsStyleURLWithVersion(9)
        self.mapView.delegate = self
        self.mapView.showsUserLocation = true
        //self.mapView.zoom = 20
        //self.mapView.hideAttribution = true
        //self.mapView.adjustTilesForRetinaDisplay = true
      
    }
    
    func setupLocationTrackingSettings()
    {
        
        let trackingMode: MGLUserTrackingMode = (isTracked) ? MGLUserTrackingMode.Follow : MGLUserTrackingMode.None
        mapView.setUserTrackingMode(trackingMode, animated: true)
        
    }
    
    func uiSettings(){
        //TODO: make for different iPhoneSizes
        //slider.contentSize = CGSize(width: 640, height: 458)
        slider.contentSize = CGSize(width: self.view.frame.width, height: self.view.frame.height)

        UITabBar.appearance().tintColor = UIColor(red: 35/255, green: 159/255, blue: 151/255, alpha: 1.0)

        sliderImg.roundCorners([.TopRight , .BottomRight], radius: 2)
        fronSliderImg.roundCorners([.TopLeft , .BottomLeft], radius: 2)
    }
    
    private func updateSessionValues(elapsedTime: Int){
    
        let (h, m, s) = durationBySecond(seconds: elapsedTime)
        let strH: String = h > 9 ? "\(h):" : h == 0 ? "" : "0\(h):"
        let strM: String = m > 9 ? "\(m):" : "0\(m):"
        let strS: String = s > 9 ? "\(s)" : "0\(s)"
        
        if let timeLabel = self.timeLabel {
            timeLabel.text = "\(strH)\(strM)\(strS)"
        }
    }
    
    private func durationBySecond(seconds s:Int) -> (hours: Int, minutes: Int, seconds: Int){
        
        return ((s % (24*3600))/3600, s%3600/60, s%60)
    }
    
    
    override func viewDidAppear(animated: Bool) {
        
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
                        self.link.setTitle(sUrl, forState: UIControlState.Normal)
                        self.link.enabled = true
                        self.copyButton.enabled = true
                    }
                    
                    self.log.enqueue("Monitoring View Controller: The session was opened")
                    
                    self.playStopBtn.setImage(UIImage(named: "stop-64"), forState: UIControlState.Normal)
                    self.pauseBtn.hidden = false
                    
                    if self.sessionTimer != nil && !self.sessionTimer!.IsStarted {
                        self.sessionTimer!.reset()
                        self.sessionTimer!.start()
                    }
                }
                    
                else {
                    
                    self.link.setTitle($0.1.isEmpty ? "session was closed" : $0.1, forState: UIControlState.Normal)
                    self.link.enabled = false
                    self.copyButton.enabled = false
                    
                    self.log.enqueue("Monitoring View Controller: The session was closed")
                    
                    
                    self.pauseBtn.hidden = true
                    self.playStopBtn.setImage(UIImage(named: "play-100"), forState: UIControlState.Normal)
                    self.isSessionPaused = false
                    self.pauseBtn.setImage(UIImage(named: "pause-32"), forState: UIControlState.Normal)
                    if self.mainAnnotation != nil {self.mapView.removeAnnotation(self.mainAnnotation!)}
                    self.mainAnnotation = nil
                    
                    if let sessionTimer = self.sessionTimer { sessionTimer.stop()}
                }
                
            }
            
            connectionManager.connect()
            isLoaded = true
            // Do any additional setup after loading the view, typically from a nib.
            
        }
    }
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
                
        sendingManger.sentObservers.add(self, self.dynamicType.onSentCoordinate)
       
        sessionTimer = SessionTimer(handler: updateSessionValues)
        
        uiSettings()
        setupMapView()
        
        setupLocationTrackingSettings()
        
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        // Dispose of any resources that can be recreated.
    }

    //handler for sent coordinate
    func onSentCoordinate(location: LocationModel){
        
        moveToPosition(location)
        drawLocationOnMap([location])
    }
    
    
//MARK:  MapViewInteraction
    
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
    func mapView(mapView: MGLMapView, viewForAnnotation annotation: MGLAnnotation) -> MGLAnnotationView? {
        
        return nil
    
    }
    
    func drawLocationOnMap(locationModels: [LocationModel]){
        
        
        var locations = [CLLocation]()
        var coordinates: [CLLocationCoordinate2D] = []
        
        for loc in locationModels{
            let clLocation = CLLocation(latitude: loc.lat, longitude: loc.lon)
            locations.append(clLocation)
            
            let coordinate = CLLocationCoordinate2DMake(loc.lat, loc.lon)
            
            // Add coordinate to coordinates array
            coordinates.append(coordinate)
        }
        
        if (mainAnnotation == nil){
            
            if let f = locations.first {
                let ann = MGLPointAnnotation();
                ann.coordinate = f.coordinate;
                ann.title = ""
                //ann.userInfo = locations
                
                //mapView.addAnnotation(ann)
                mainAnnotation = ann
            }
        }
        else {
            
            let line = MGLPolyline(coordinates: &coordinates, count: UInt(coordinates.count))
            mapView.addAnnotation(line)
            
            /*
            var shape: MGLPolyline()
            
            
            if let lay = layer {
                shape = lay
            }
            else {
                shape = RMShape(view: mapView)
                
                mainAnnotation?.layer = shape
                shape.lineColor = UIColor.orangeColor()
                shape.lineWidth = 5.0
                
            }
            
            for location in locations {
                
                shape.addLineToCoordinate(location.coordinate)
                shape.moveToCoordinate(location.coordinate)
                
            }*/
        }
 
    
    }
    
    func drawPeoples(location: UserGroupCoordinate){
        
        let clLocation = CLLocationCoordinate2D(latitude: location.location.lat, longitude: location.location.lon)
        if self.mapView != nil {
            
            let user = groupManager.getUser(location.groupId, user: location.userId)
            let userName = user?.name ?? "\(location.userId)"
            /*
                let ann = self.mapView.annotations.filter{$0.title == userName}
                if let existedAnn = ann.first as? RMAnnotation{
                    existedAnn.coordinate = clLocation
                }
                else {
                    
                    let annotation = RMAnnotation(mapView: self.mapView, coordinate: clLocation, andTitle: userName)
                    annotation.userInfo = user
                    self.mapView.addAnnotation(annotation)
 
                    onMapNow.append(userName)
                    
                }
            */
                //clearPeople("\(user.name)")
            
        }
    }
    
    func clearPeople(people: String){
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
    func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int) {
        
        if actionSheet.buttonTitleAtIndex(buttonIndex) == "clear all" {
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
                        
                        self.drawPeoples(coord)
                        
                    }
                }
                
                for p in onMapNow {
                    clearPeople("\(p)")
                }
                
                self.selectedGroupIndex = buttonIndex - 1

            }
        }
        
        
    }
    
    func alert(title: String, message: String) {
        if let getModernAlert: AnyClass = NSClassFromString("UIAlertController") { // iOS 8
            let myAlert: UIAlertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
            myAlert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
            self.presentViewController(myAlert, animated: true, completion: nil)
        } else { // iOS 7
            let alert: UIAlertView = UIAlertView()
            alert.delegate = self
            
            alert.title = title
            alert.message = message
            alert.addButtonWithTitle("OK")
            
            alert.show()
        }
    }

}



