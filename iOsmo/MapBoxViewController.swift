//
//  MapBoxViewController.swift
//  iOsmo
//
//  Created by Alexey Sirotkin on 23.08.16.
//  Copyright © 2015 Olga Grineva, © 2017 Alexey Sirotkin. All rights reserved.
//

import UIKit
import Mapbox
import FirebaseAnalytics





class OSMOCalloutView: UIView, MGLCalloutView {
    var representedObject: MGLAnnotation
    
    // Lazy initialization of optional vars for protocols causes segmentation fault: 11s in Swift 3.0. https://bugs.swift.org/browse/SR-1825
    
    var leftAccessoryView = UIView() /* unused */
    var rightAccessoryView = UIView() /* unused */
    
    weak var delegate: MGLCalloutViewDelegate?
    
    let tipHeight: CGFloat = 10.0
    let tipWidth: CGFloat = 20.0
    
    let mainBody: UITextView //UIButton
    
    required init(representedObject: MGLAnnotation) {
        self.representedObject = representedObject
        
        let ann = representedObject as! OSMOAnnotation
        print ("Init callout view for \(ann.objId)")
        
        if ann.type == AnnotationType.user {
            self.mainBody = UITextView(frame: CGRect(x: 0, y: 0, width: 80, height: 20))
        } else {
            self.mainBody = UITextView(frame: CGRect(x: 0, y: 0, width: 200, height: 160))
        }
        
        super.init(frame: .zero)
        
        guard representedObject is OSMOAnnotation else {
            return
        }
        mainBody.textColor = .white
        if let title = representedObject.title, let subtitle = representedObject.subtitle {
            if ann.type == AnnotationType.user {
                mainBody.text = title;
            } else {
                mainBody.text = "\(title!)\n\(subtitle!)";
                mainBody.dataDetectorTypes = [UIDataDetectorTypes.link, UIDataDetectorTypes.phoneNumber]
            }
        }
        backgroundColor = .clear
        mainBody.backgroundColor = .darkGray
        mainBody.tintColor = .white
        //mainBody.contentEdgeInsets = UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)
        mainBody.layer.cornerRadius = 4.0
        
        addSubview(mainBody)
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - MGLCalloutView API
    func presentCallout(from rect: CGRect, in view: UIView, constrainedTo constrainedView: UIView, animated: Bool) {
        if !representedObject.responds(to: Selector("title")) {
            return
        }
        view.addSubview(self)

        // Prepare title label
        //mainBody.text = representedObject.title!;
        
        //mainBody.setTitle(representedObject.title!, for: .normal)
        //mainBody.frame = CGRect(x: 0, y: 0, width: 200, height: 300)
        
        print("\(mainBody.frame.width)x\(mainBody.frame.height) -\(view.frame.width)x\(view.frame.height) - \(constrainedView.frame.width)x\(constrainedView.frame.height)")
        //mainBody.sizeToFit()
        
        /* if isCalloutTappable() {
            // Handle taps and eventually try to send them to the delegate (usually the map view)
            mainBody.addTarget(self, action: #selector(OSMOCalloutView.calloutTapped), for: .touchUpInside)
        } else {
            // Disable tapping and highlighting
            mainBody.isUserInteractionEnabled = false
        }*/
        
        // Prepare our frame, adding extra space at the bottom for the tip
        //let frameWidth = CGFloat(150)
        //let frameHeight = CGFloat(100)
        
        let frameWidth = mainBody.bounds.size.width
        let frameHeight = mainBody.bounds.size.height + tipHeight
        
        let frameOriginX = rect.origin.x + (rect.size.width/2.0) - (frameWidth/2.0)
        let frameOriginY = rect.origin.y - frameHeight
        frame = CGRect(x: frameOriginX, y: frameOriginY, width: frameWidth, height: frameHeight)
        
        if animated {
            alpha = 0
            
            UIView.animate(withDuration: 0.2) { [weak self] in
                self?.alpha = 1
            }
        }
    }
    
    func dismissCallout(animated: Bool) {
        if (superview != nil) {
            if animated {
                UIView.animate(withDuration: 0.2, animations: { [weak self] in
                    self?.alpha = 0
                    }, completion: { [weak self] _ in
                        self?.removeFromSuperview()
                })
            } else {
                removeFromSuperview()
            }
        }
    }
    
    // MARK: - Callout interaction handlers
    
    func isCalloutTappable() -> Bool {
        if let delegate = delegate {
            if delegate.responds(to: #selector(MGLCalloutViewDelegate.calloutViewShouldHighlight)) {
                return delegate.calloutViewShouldHighlight!(self)
            }
        }
        return false
    }
    
    func calloutTapped() {
        if isCalloutTappable() && delegate!.responds(to: #selector(MGLCalloutViewDelegate.calloutViewTapped)) {
            delegate!.calloutViewTapped!(self)
        }
    }
    
    // MARK: - Custom view styling
    
    override func draw(_ rect: CGRect) {
        // Рисуем стрелку под тултипом маркера
        let fillColor : UIColor = .darkGray
        
        let tipLeft = rect.origin.x + (rect.size.width / 2.0) - (tipWidth / 2.0)
        let tipBottom = CGPoint(x: rect.origin.x + (rect.size.width / 2.0), y: rect.origin.y + rect.size.height)
        let heightWithoutTip = rect.size.height - tipHeight
        
        let currentContext = UIGraphicsGetCurrentContext()!
        
        let tipPath = CGMutablePath()
        tipPath.move(to: CGPoint(x: tipLeft, y: heightWithoutTip))
        tipPath.addLine(to: CGPoint(x: tipBottom.x, y: tipBottom.y))
        tipPath.addLine(to: CGPoint(x: tipLeft + tipWidth, y: heightWithoutTip))
        tipPath.closeSubpath()
        
        fillColor.setFill()
        currentContext.addPath(tipPath)
        currentContext.fillPath()
    }
}
// MGLAnnotation protocol reimplementation
class OSMOAnnotation: NSObject, MGLAnnotation {
    
    // As a reimplementation of the MGLAnnotation protocol, we have to add mutable coordinate and (sub)title properties ourselves.
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    var polyline: OSMPolyline?

    // Custom properties that we will use to customize the annotation's image.
    var image: UIImage?
    var objId: String?
    var type: AnnotationType;
    var color: String? = "#ff0000"
    var labelColor: String? = "#000000"
    
    init(type: AnnotationType, coordinate: CLLocationCoordinate2D, title: String?, objId: String) {
        self.type = type
        self.coordinate = coordinate
        self.title = title
        self.objId = objId
    }
}

// MGLAnnotationView subclass
class OSMOAnnotationView: MGLAnnotationView {
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        let letter = UILabel(frame: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
        letter.textAlignment = NSTextAlignment.center
        letter.baselineAdjustment = UIBaselineAdjustment.alignCenters
        letter.tag = 1
        if self.reuseIdentifier == "type\(AnnotationType.point)" {
            layer.cornerRadius = 0
            layer.borderWidth = 1
        } else {
            layer.cornerRadius = frame.width / 2
            layer.borderWidth = 2
        }
        self.addSubview(letter);
    }
    
    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let ann = self.annotation as? OSMOAnnotation {
            print("OSMOAnnotationView layoutSubviews \(ann.objId)")
            
        } else {
            print("OSMOAnnotationView layoutSubviews for \(reuseIdentifier!)")
        }
        
        // Force the annotation view to maintain a constant size when the map is tilted.
        scalesWithViewingDistance = false
        
        // Use CALayer’s corner radius to turn this view into a circle.
        layer.borderColor = UIColor.white.cgColor
       
        if let letter = self.viewWithTag(1) as? UILabel{
            if self.reuseIdentifier == "type\(AnnotationType.point)" {
                letter.font = letter.font.withSize(10)
            } else {
                letter.font = letter.font.withSize(14)
            }
        }
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        print ("OSMOAnnotationView setSelected")

        let animation = CABasicAnimation(keyPath: "borderWidth")
        animation.duration = 0.1
        if self.reuseIdentifier == "type\(AnnotationType.point)" {
            layer.borderWidth = selected ? 3 : 1
        } else {
            layer.borderColor = selected ? UIColor.red.cgColor : UIColor.white.cgColor
            layer.borderWidth = selected ? 3 : 2

        }
        layer.add(animation, forKey: "borderWidth")
    }
}
// MGLPolyline subclass
class OSMPolyline: MGLPolyline {
    // Because this is a subclass of MGLPolyline, there is no need to redeclare its properties.
    
    // Custom property that we will use when drawing the polyline.
    var color: UIColor?
    var objId: String = ""
}

class OSMMultiPolyline: MGLMultiPolyline {
    var objId: String = ""
}

class MapBoxViewController: UIViewController, UIActionSheetDelegate, MGLMapViewDelegate {
    required init(coder aDecoder: NSCoder) {
        print("mapBox init")
        connectionManager = ConnectionManager.sharedConnectionManager
        groupManager = GroupManager.sharedGroupManager
        
        super.init(coder: aDecoder)!
    }
    
    var isTracked = true
    let connectionManager: ConnectionManager
    let groupManager: GroupManager
    var onMapNow = [String]()
    
    var onMonitoringGroupsUpdated: ObserverSetEntry<[UserGroupCoordinate]>?
    var onUserLeave: ObserverSetEntry<User>?
    var selectedGroupIndex: Int?
    var trackedUser: String = ""
    
    var pointAnnotations = [OSMOAnnotation]()
    var trackAnnotations = [OSMPolyline]()
    

    @IBOutlet weak var mapView: MGLMapView!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        print ("mapBox viewDidLoad")
        if let lat = SettingsManager.getKey(SettingKeys.lat)?.doubleValue, let lon = SettingsManager.getKey(SettingKeys.lon)?.doubleValue,let zoom = SettingsManager.getKey(SettingKeys.zoom)?.doubleValue {
            if ((lat != 0) && (lon != 0) && (zoom != 0)) {
                
                mapView.setCenter(CLLocationCoordinate2D(latitude: lat,longitude: lon), zoomLevel: zoom, animated: false)
            }
        }
        self.onMonitoringGroupsUpdated = groupManager.monitoringGroupsUpdated.add{
            for coord in $0 {
                DispatchQueue.main.async {
                    self.drawPeoples(location: coord)
                }
            }
        }
        groupManager.groupsUpdated.add{
            _ = $0
            _ = $1
            DispatchQueue.main.async {
                self.updateGroupsOnMap(groups: self.groupManager.allGroups )
            }
        }
        groupManager.groupListUpdated.add{
            let groups = $0
            DispatchQueue.main.async {
                self.updateGroupsOnMap(groups: groups)
            }
        }
        connectionManager.connectionRun.add{
            let theChange = $0.0
            
            if theChange {
                DispatchQueue.main.async {
                    self.connectionManager.activatePoolGroups(1)
                }
            }
        }
        self.automaticallyAdjustsScrollViewInsets = false;
        setupMapView()
        setupLocationTrackingSettings()
        

        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated:Bool) {
        super.viewWillAppear(animated)
        
        print("MapBox viewWillAppear")
        Analytics.logEvent("map_open", parameters: nil)

        if (groupManager.allGroups.count) > 0 {
            self.connectionManager.activatePoolGroups(1)

            groupManager.updateGroupsOnMap([1])
            
            self.updateGroupsOnMap(groups: groupManager.allGroups )
        }
    }
    
    func updateGroupsOnMap(groups: [Group]) {
        print("updateGroupsOnMap")
        var curAnnotations = [String]()
        var curTracks = [String]()
        
        for group in groups{
            for user in group.users {
                if user.coordinate.latitude > -3000 && user.coordinate.longitude > -3000 {
                    let location = LocationModel(lat: user.coordinate.latitude, lon: user.coordinate.longitude)
                    let gid = Int(group.u)
                    let uid = Int(user.id)
                    let ugc: UserGroupCoordinate = UserGroupCoordinate(group: gid!, user: uid!,  location: location)
                    ugc.recent = false
                    self.drawPeoples(location: ugc)
                    curAnnotations.append("u\(uid!)")
                }
            }
            for point in group.points {
                drawPoint(point: point, group:group)
                curAnnotations.append("p\(point.u)")
            }
            for track in group.tracks {
                drawTrack(track: track)
                curTracks.append("t\(track.u)")
            }
        }
        var idx = 0;
        for ann in pointAnnotations {
            var delete = true;
            if curAnnotations.count > 0 {
                for objId in curAnnotations {
                    if ann.objId == objId {
                        delete = false;
                        break;
                    }
                }
            }
            
            if (delete == true) {
                
                if !(ann.objId?.contains("wpt"))! {
                    self.mapView.removeAnnotation(ann)
                    pointAnnotations.remove(at: idx)
                    print("removing \(ann.title)")
                }
            } else {
                idx = idx + 1
            }
        }
        idx = 0;
        for ann in trackAnnotations {
            var delete = true;
            if curTracks.count > 0 {
                for objId in curTracks {
                    if ann.objId == objId {
                        delete = false;
                        break;
                    }
                }
            }
            
            if (delete == true) {
                self.mapView.removeAnnotation(ann)
                trackAnnotations.remove(at: idx)
                print("removing \(ann.objId)")
            } else {
                idx = idx + 1
            }
        }
    }
    
    func drawTrack(track:Track) {
        print ("MapBox drawTrack")
        if (self.mapView != nil) {
            if let xml = track.getTrackData() {
                let gpx = xml.children[0]
                for trk in gpx.children {
                    if trk.name == "trk" {
                        //var polylines = [OSMPolyline]()
                        
                        for trkseg in trk.children {
                            if trkseg.name == "trkseg" {
                                var coordinates = [CLLocationCoordinate2D]()
                                
                                for trkpt in trkseg.children {
                                    if trkpt.name == "trkpt" {
                                        let lat = atof(trkpt.attributes["lat"])
                                        let lon = atof(trkpt.attributes["lon"])
                                        coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lon) )
                                    }
                                    
                                }
                                if coordinates.count > 0 {
                                    let polyline = OSMPolyline(coordinates: &coordinates, count: UInt(coordinates.count))
                                    // Set the custom `color` property, later used in the `mapView:strokeColorForShapeAnnotation:` delegate method.
                                    polyline.color = track.color.hexColor.withAlphaComponent(0.8)
                                    polyline.title = track.name
                                    polyline.objId = "t\(track.u)"
                                    
                                    self.mapView.addAnnotation(polyline)
                                    self.trackAnnotations.append(polyline)
                                    
                                    //polylines.append(polyline)
                                }
                                
                            }
                            
                        }
                    }
                    if trk.name == "wpt" {
                        let lat = atof(trk.attributes["lat"])
                        let lon = atof(trk.attributes["lon"])
                        let name = trk["name"]?.text
                        let clLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        let annotation = OSMOAnnotation(type:AnnotationType.point,  coordinate: clLocation, title: name, objId: "wpt\(track.u)");
                        annotation.subtitle = "Waypoint"
                        annotation.color = track.color

                        self.pointAnnotations.append(annotation)
                        self.mapView.addAnnotation(annotation)
                        

                    }
                    /*
                     let multiPolyline = OSMMultiPolyline(polylines: polylines)
                     multiPolyline.objId = "t\(track.u)"
                     multiPolyline.title = track.name
                     let source = MGLShapeSource(identifier: multiPolyline.objId, shapes: polylines, options: nil)
                     mapView.style?.addSource(source)
                     
                     let layer = MGLFillStyleLayer(identifier: multiPolyline.objId, source: source)
                     
                     layer.fillColor = MGLStyleValue<UIColor>(rawValue: track.color.hexColor.withAlphaComponent(0.8))
                     layer.fillOutlineColor = MGLStyleValue<UIColor>(rawValue:track.color.hexColor.withAlphaComponent(0.8))
                     mapView.style?.addLayer(layer)
                     
                     self.trackAnnotations.append(multiPolyline)
                     */
                }
                
            }
            
        }
    }
    func drawPoint(point: Point, group: Group){
        print("MapBox drawPoint")
        let clLocation = CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon)
        if (self.mapView) != nil {
            var annVisible = false;
            for ann in self.pointAnnotations {
                if ann.objId == "p\(point.u)" {
                    ann.coordinate = clLocation
                    annVisible = true;
                    break;
                }
            }
            if !annVisible {
                let annotation = OSMOAnnotation(type:AnnotationType.point,  coordinate: clLocation, title: point.name, objId: "p\(point.u)");
                annotation.color = point.color
                annotation.subtitle = "\(group.name)\n\(point.descr)"
                self.pointAnnotations.append(annotation)
                self.mapView.addAnnotation(annotation)
            }
        }
    }
    
    func drawPeoples(location: UserGroupCoordinate){
        print("MapBox drawPeoples")
        let clLocation = CLLocationCoordinate2D(latitude: location.location.lat, longitude: location.location.lon)
        if (self.mapView) != nil {
            if let user = groupManager.getUser(location.groupId, user: location.userId){
                let userName = user.name
                var annVisible = false;
                for ann in self.pointAnnotations {
                    if ann.objId == "u\(location.userId)" {
                        if ann.polyline == nil {
                            var coordinates = [ann.coordinate, clLocation]
                            
                            let polyline = OSMPolyline(coordinates: &coordinates, count: UInt(coordinates.count))
                            
                            // Set the custom `color` property, later used in the `mapView:strokeColorForShapeAnnotation:` delegate method.
                            polyline.color = user.color.hexColor.withAlphaComponent(0.8)
                            
                            // Add the polyline to the map. Note that this method name is singular.
                            mapView.addAnnotation(polyline)
                            ann.polyline = polyline;
                            
                        } else {
                            //Не добавляем в конец трека координаты пользователя из GROUP.users
                            if location.recent == true {
                                ann.polyline?.appendCoordinates([clLocation], count: 1)
                                if self.trackedUser == ann.objId {
                                    self.mapView.setCenter(clLocation, animated: true)
                                }
                            }
                        }
                        ann.coordinate = clLocation;
                        annVisible = true;
                        ann.labelColor = "#000000"
                        break;
                    }
                }
                if !annVisible {
                    let annotation = OSMOAnnotation(type:AnnotationType.user,  coordinate: clLocation, title: userName, objId: "u\(location.userId)");
                    annotation.color = user.color
                    if location.recent == false {
                        annotation.labelColor = "#AAAAAA"
                    }
                    self.pointAnnotations.append(annotation)
                    self.mapView.addAnnotation(annotation)

                    print("add u\(location.userId)")
                }
            }
        }
    }
 
    override func viewWillDisappear(_ animated: Bool){
        super.viewWillDisappear(animated)
        print("MapBox viewWillDisappear")
        groupManager.updateGroupsOnMap([])
        SettingsManager.setKey("\(self.mapView.centerCoordinate.latitude)" as NSString, forKey: SettingKeys.lat)
        SettingsManager.setKey("\(self.mapView.centerCoordinate.longitude)" as NSString, forKey: SettingKeys.lon)
        SettingsManager.setKey("\(self.mapView.zoomLevel)" as NSString, forKey: SettingKeys.zoom)
     }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func locateClick(sender: AnyObject) {
        
        self.trackedUser = "" //Перестаем следить за выбранным пользователем
        mapView.setUserTrackingMode(MGLUserTrackingMode.follow, animated: true)
        mapView.setNeedsDisplay()
        /*
        if let location = mapView.userLocation?.location {
            mapView.setCenter(location.coordinate, animated: true)
        }*/
    }

    @IBAction func changeTrackingModeClick(sender: AnyObject) {
        isTracked = !isTracked
        if isTracked {
            sender.setImage(UIImage(named: "unlock-25"), for: UIControlState.normal)
        } else {
            sender.setImage(UIImage(named: "lock-25"), for: UIControlState.normal)
        }
        setupLocationTrackingSettings()
    }
    
    func setupLocationTrackingSettings()
    {
        let trackingMode: MGLUserTrackingMode = (isTracked) ? MGLUserTrackingMode.follow : MGLUserTrackingMode.none
        print ("mapBox setupLocationTrackingSettings")
        mapView.setUserTrackingMode(trackingMode, animated: true)
    }
    
    func setupMapView(){
        self.mapView.styleURL = URL(string: MapStyle.Bright.rawValue)
        self.mapView.showsUserLocation = true
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    
    
    
    func mapView(_ mapView: MGLMapView, viewFor annotation: MGLAnnotation) -> MGLAnnotationView? {
        
        guard annotation is OSMOAnnotation else {
            return nil
        }
        let ann = annotation as! OSMOAnnotation
        print ("mapBox viewFor annotation \(ann.objId!)")
        let reuseIdentifier = "type\(ann.type)"
        
        // For better performance, always try to reuse existing annotations.
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier)
        
        // If there’s no reusable annotation view available, initialize a new one.
        if annotationView == nil {
            annotationView = OSMOAnnotationView(reuseIdentifier: reuseIdentifier)
            annotationView!.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        }

        annotationView!.backgroundColor = ann.color?.hexColor;
        
        if let title = ann.title {
            let v = annotationView!.viewWithTag(1)
            if let letter = v as? UILabel{
                
                letter.textColor = ann.labelColor?.hexColor
                if ann.type == AnnotationType.point {
                    letter.text = title.substring(to: title.index(title.startIndex, offsetBy: title.characters.count>2 ? 2 : 1))
                } else {
                    letter.text = title.substring(to: title.index(title.startIndex, offsetBy: 1))
                    if ann.objId == self.trackedUser {
                        annotationView!.layer.borderColor = UIColor.red.cgColor
                    } else {
                        annotationView!.layer.borderColor = UIColor.white.cgColor
                    }
                }
            }
        }
        
        return annotationView
    }
    
    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        print ("mapBox annotationCanShowCallout")
        return true
    }
    
    func mapView(_ mapView: MGLMapView, strokeColorForShapeAnnotation annotation: MGLShape) -> UIColor {
        print ("mapBox strokeColorForShapeAnnotation")
        if let annotation = annotation as? OSMPolyline {
            return annotation.color ?? .orange
        }
        
        // Fallback to the default tint color.
        return mapView.tintColor
    }
    
    func mapView(_ mapView: MGLMapView, didSelect annotation: MGLAnnotation) {
        guard annotation is OSMOAnnotation else {
            return
        }
        let ann = annotation as! OSMOAnnotation
        if (ann.type == AnnotationType.user) {
            if self.trackedUser != ann.objId! {
                self.trackedUser = ann.objId!
            } else {
                self.trackedUser = ""
            }
            mapView.setCenter(annotation.coordinate, animated: true)
            mapView.setNeedsDisplay()
        }
    }

    func mapView(_ mapView: MGLMapView, calloutViewFor annotation: MGLAnnotation) -> UIView? {
        guard annotation is OSMOAnnotation else {
            return nil
        }
        return OSMOCalloutView(representedObject: annotation)
    }
    
    func mapView(_ mapView: MGLMapView, tapOnCalloutFor annotation: MGLAnnotation) {
        // Optionally handle taps on the callout
        print("Tapped the callout for: \(annotation)")
        
        // Hide the callout
        mapView.deselectAnnotation(annotation, animated: true)
    }
}
