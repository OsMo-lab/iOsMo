//
//  MapViewController.swift
//  iOsMo
//
//  Created by Alexey Sirotkin on 30.10.17.
//  Copyright © 2018 Alexey Sirotkin. All rights reserved.
//

import Foundation

import FirebaseAnalytics
import CoreLocation
import MapKit




class OSMMapKitPolyline: MKPolyline {
    // Because this is a subclass of MGLPolyline, there is no need to redeclare its properties.
    
    // Custom property that we will use when drawing the polyline.
    var color: UIColor?
    var objId: String = ""

}

class OSMOMKAnnotationView: MKAnnotationView {
    override init(annotation: MKAnnotation!, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        
        /*
        if #available(iOS 11.0, *) {
            if self.reuseIdentifier == "user" {
                clusteringIdentifier = "user"
            }
        }
        */
        
        self.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        var lWidth : CGFloat = 20;
        
        let aView = UIView(frame: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
        var lX : CGFloat = 0;
        var lY : CGFloat = 0;
        if self.reuseIdentifier == "point" {
            layer.cornerRadius = 0
            layer.borderWidth = 1
        } else {
            layer.cornerRadius = frame.width / 2
            layer.borderWidth = 2
        }
        
        if let longNames = SettingsManager.getKey(SettingKeys.longNames) {
            if (longNames.boolValue) {
                lWidth = 150;
                lY = -16;
                lX = (self.frame.width - lWidth)/2;
            }
        }
        let letter = UILabel(frame: CGRect(x: lX, y: lY, width: lWidth, height: self.frame.height))
        letter.textAlignment = NSTextAlignment.center
        
        letter.baselineAdjustment = UIBaselineAdjustment.alignCenters
        letter.tag = 1

        aView.addSubview(letter);
        self.addSubview(aView);
        self.canShowCallout = true
        

        if self.reuseIdentifier == "point" {
            let width = 300
            let height = 200
            
            let snapshotView = UIView()
            let views = ["snapshotView": snapshotView]
            snapshotView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:[snapshotView(\(width))]", options: [], metrics: nil, views: views))
            snapshotView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[snapshotView(\(height))]", options: [], metrics: nil, views: views))
            
            let textView = UITextView(frame: CGRect(x: 0, y: 0, width: width, height: height))
            textView.tag = 10;
            textView.isEditable = false;
            textView.dataDetectorTypes = UIDataDetectorTypes.all
            snapshotView.addSubview(textView)
            
            self.detailCalloutAccessoryView = snapshotView;
        } else {
            //Speed
            let lblSpeed = UILabel(frame: CGRect(x: (self.frame.width - 200)/2, y: 16, width: 200, height: self.frame.height))
            lblSpeed.textAlignment = NSTextAlignment.center
            lblSpeed.font = lblSpeed.font.withSize(12)
            
            lblSpeed.baselineAdjustment = UIBaselineAdjustment.alignCenters
            lblSpeed.tag = 2
            
            aView.addSubview(lblSpeed);
        }
        
    }

    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if self.annotation is Point {
            print("OSMOMKAnnotationView layoutSubviews for point")
            
        } else {
            print("OSMOMKAnnotationView layoutSubviews for \(reuseIdentifier!)")
        }
        
        // Use CALayer’s corner radius to turn this view into a circle.
        layer.borderColor = UIColor.white.cgColor
        
        if let letter = self.viewWithTag(1) as? UILabel{
            if self.reuseIdentifier == "point" {
                letter.font = letter.font.withSize(10)
            } else {
                letter.font = letter.font.withSize(14)
            }
        }
    }
}

class MapViewController: UIViewController, MKMapViewDelegate {
    required init(coder aDecoder: NSCoder) {
        print("MapViewController init")
        
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
    var trackedUser: User?
    
    var pointAnnotations = [MKAnnotation]()
    var trackAnnotations = [OSMMapKitPolyline]()
    var tileSource = TileSource.Mapnik
    @IBOutlet weak var mapView:MKMapView!;
    
    var tileRenderer: MKTileOverlayRenderer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("MapViewController viewDidLoad")
        
        self.setupTileRenderer()

        self.mapView.showsCompass = true
        self.mapView.showsUserLocation = true
        if let lat = SettingsManager.getKey(SettingKeys.lat)?.doubleValue, let lon = SettingsManager.getKey(SettingKeys.lon)?.doubleValue,let lon_delta = SettingsManager.getKey(SettingKeys.lon_delta)?.doubleValue, let lat_delta = SettingsManager.getKey(SettingKeys.lat_delta)?.doubleValue {
            if ((lat != 0) && (lon != 0)) {
                
                if ((lat_delta != 0) && (lon_delta != 0)) {
                    let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lon), span: MKCoordinateSpan(latitudeDelta: lat_delta, longitudeDelta: lon_delta))
                    self.mapView.setRegion(region, animated: false)
                }else {
                    self.mapView.setCenter(CLLocationCoordinate2D(latitude: lat, longitude: lon), animated: true)
                }
            }
        }
        self.onMonitoringGroupsUpdated = self.groupManager.monitoringGroupsUpdated.add{
            for coord in $0 {
                DispatchQueue.main.async {
                    self.drawPeoples(location: coord)
                }
            }
        }
        //Информация об изменениях в группе
        _ = self.groupManager.groupsUpdated.add{
            let g = $1 as! Dictionary<String, AnyObject>
            //let group = $0
            //let foundGroup = self.groupManager.allGroups.filter{$0.u == "\(group)"}.first
            DispatchQueue.main.async {
                self.updateGroupsOnMap(groups: self.groupManager.allGroups, GP:g )
            }
        }
        //Обновление списка групп
        _ = self.groupManager.groupListUpdated.add{
            let groups = $0
            DispatchQueue.main.async {
                self.updateGroupsOnMap(groups: groups, GP:nil)
            }
        }
        self.mapView.delegate = self
        self.addObserver(self, forKeyPath: #keyPath(User.subtitle), options: [.old,.new], context: nil)
    }
    
    
    deinit {
        removeObserver(self, forKeyPath: #keyPath(User.subtitle))
    }
    
    
    override func viewWillAppear(_ animated:Bool) {
        super.viewWillAppear(animated)
        
        print("MapViewController viewWillAppear")
        Analytics.logEvent("map_open", parameters: nil)

        self.setupTileRenderer()
        
        if (groupManager.allGroups.count) > 0 {
            self.updateGroupsOnMap(groups: groupManager.allGroups, GP:nil )
        }
    }
    
    
    override func viewWillDisappear(_ animated: Bool){
        super.viewWillDisappear(animated)
        print("MapViewController viewWillDisappear")
        
        SettingsManager.setKey("\(self.mapView.centerCoordinate.latitude)" as NSString, forKey: SettingKeys.lat)
        SettingsManager.setKey("\(self.mapView.centerCoordinate.longitude)" as NSString, forKey: SettingKeys.lon)
        SettingsManager.setKey("\(self.mapView.region.span.latitudeDelta)" as NSString, forKey: SettingKeys.lat_delta)
        SettingsManager.setKey("\(self.mapView.region.span.longitudeDelta)" as NSString, forKey: SettingKeys.lon_delta)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func updateGroupsOnMap(groups: [Group], GP: Dictionary<String, AnyObject>?) {
        print("updateGroupsOnMap")
        var curAnnotations = [String]()
        var curTracks = [String]()
        var idx = 0;
        let removeAll : Bool = groups.count == groupManager.allGroups.count ? true : false
        
        //Удаляем пользователей с карты т.к. после обновления групп по команде GROUP сформированы новые экземпляры объектов пользователей и старые маркеры не будут обновлятся
        if removeAll == true {
            for ann in pointAnnotations {
                if (ann is User)  {
                    print("removing user \((ann as! User).u!)")
                    self.mapView.removeAnnotation(ann)
                    pointAnnotations.remove(at: idx)
                    continue
                }
                idx = idx + 1;
            }
        }
        
        for group in groups{
            if group.active {
                for user in group.users {
                    if user.coordinate.latitude > -3000 && user.coordinate.longitude > -3000 {
                        let location = LocationModel(lat: user.coordinate.latitude, lon: user.coordinate.longitude)
                        let gid = Int(group.u)
                        let uid = Int(user.u)
                        let ugc: UserGroupCoordinate = UserGroupCoordinate(group: gid!, user: uid!,  location: location)
                        idx = 0;
                        
                        let gpUsers = GP?["users"] as? Array<AnyObject>

                        //Удаляем пользователей с карты т.к. после обновления групп по команде GROUP сформированы новые экземпляры объектов пользователей и старые маркеры не будут обновлятся
                        /*
                        if removeAll == true {
                            for ann in pointAnnotations {
                                if (ann is User)  {
                                    if (user.u == (ann as! User).u ) {
                                        print("removing user \(user.u!)")
                                        self.mapView.removeAnnotation(ann)
                                        pointAnnotations.remove(at: idx)
                                        break
                                    }
                                }
                                idx = idx + 1;
                            }
                        }
                         */
                        
                        if (gpUsers != nil || GP == nil){
                            self.drawPeoples(location: ugc)
                        }
                        
                        curAnnotations.append("u\(uid!)")
                    }
                }
                let points = GP?["point"] as? Array<AnyObject>
                for point in group.points {
                    if (points != nil || GP == nil) {
                        drawPoint(point: point, group:group)
                    }
                    curAnnotations.append("p\(point.u)")
                }
                let tracks = GP?["track"] as? Array<AnyObject>
                for track in group.tracks {
                    if (tracks != nil || GP == nil) {
                        drawTrack(track: track)
                    }
                    curTracks.append("t\(track.u)")
                }
            }
        }
        idx = 0;
        for ann in pointAnnotations {
            var delete = true;
            var annObjId:String! = ""
            
            if (ann is User)  {
                annObjId = (ann as! User).mapId
            } else if (ann is Point) {
                annObjId = (ann as! Point).mapId
            }
            
            if curAnnotations.count > 0 {
                for objId in curAnnotations {
                    if annObjId == objId {
                        delete = false;
                        break;
                    }
                }
            }
            
            if (delete == true && annObjId != "") {
                if !(annObjId.contains("wpt")) {
                    self.mapView.removeAnnotation(ann)
                    pointAnnotations.remove(at: idx)
                    print("removing \(annObjId!)")
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
                    if objId == ann.objId {
                        delete = false;
                        break;
                    }
                }
            }
            
            if (delete == true) {
                self.mapView.removeOverlay(ann)
                trackAnnotations.remove(at: idx)
                print("removing track \(ann.objId)")
                
                //Удаляем Waypoint-ы трека
                var wpt_idx = 0;
                for wpt in pointAnnotations {
                    if (wpt is Point && (wpt as! Point).mapId == "wp\(ann.objId)") {
                        self.mapView.removeAnnotation(wpt)
                        
                        pointAnnotations.remove(at: wpt_idx)
                        print("removing waypoint for \(ann.objId)")
                    } else {
                        wpt_idx = wpt_idx + 1;
                    }
                }
            } else {
                idx = idx + 1
            }
        }
    }
    
    func drawTrack(track:Track) {
        print ("MapViewController drawTrack")
        /*
        var annVisible = false;
        for ann in self.trackAnnotations {
            if (ann is OSMMapKitPolyline) {
                if ((ann as! OSMMapKitPolyline).objId == "t\(track.u)") {
                    annVisible = true;
                    return;
                    
                }
            }
        }
        */
        
        if let xml = track.getTrackData() {
            let gpx = xml.children[0]
            for trk in gpx.children {
                if trk.name == "trk" {
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
                                let polyline = OSMMapKitPolyline(coordinates: &coordinates, count: coordinates.count)
                                polyline.color = track.color.hexColor.withAlphaComponent(0.8)
                                polyline.title = track.name
                                polyline.objId = "t\(track.u)"
                                
                                self.mapView.addOverlay(polyline)
                                self.trackAnnotations.append(polyline)
                                print("adding track \(track.u)")

                            }
                        }
                        
                    }
                }
                
                if trk.name == "wpt" {
                    let lat = atof(trk.attributes["lat"])
                    let lon = atof(trk.attributes["lon"])
                    let name = trk["name"]?.text
                    
                    let pointDict : NSDictionary  =
                        ["u": track.u, "name": name ?? "", "description": "Waypoint", "color": track.color, "lat": "\(lat)", "lon": "\(lon)"];
                    
                    let point = Point(json: pointDict as! Dictionary<String, AnyObject>)
                    point.mapId = "wpt\(track.u)"
                    point.groupId = track.groupId
                    self.mapView.addAnnotation(point);
                    self.pointAnnotations.append(point)
                    print ("adding waipont \(track.u)")

                }
            }
            
        }
    }
    
    func drawPoint(point: Point, group: Group){
        print("MapViewController drawPoint")
        if (self.mapView) != nil {
            var annVisible = false;
            for ann in self.pointAnnotations {
                if (ann is Point) {
                    if ((ann as! Point).u == point.u) {
                        annVisible = true;
                        break;
                    }
                }
            }
            if !annVisible {
                point.subtitle = "\(group.name)\n\(point.descr)\n\(point.url)"
                self.mapView.addAnnotation(point);
                self.pointAnnotations.append(point)
                print("adding point \(point.u)")
            }
        }
    }
    
    func updateAnotation(view: MKAnnotationView, user: User) {
        var longNames: Bool = false;
        var recent : Bool = false;
        if user.speed >= 0 {
            if user.time.timeIntervalSinceNow > -120 {
                recent = true
            }
        }
        if let sLongNames = SettingsManager.getKey(SettingKeys.longNames) {
            longNames = sLongNames.boolValue
        }
        
        if let title = user.title {
            if let letter = view.viewWithTag(1) as? UILabel{
                if recent == true {
                    letter.textColor = UIColor.black
                } else {
                    letter.textColor = UIColor.gray
                }
                if (longNames) {
                    letter.text = title;
                } else {
                    letter.text = title.substring(to: title.index(title.startIndex, offsetBy: title.count>2 ? 2 : title.count))
                }
            }
        }
        view.backgroundColor = user.color.hexColor;
        if user == self.trackedUser {
            view.layer.borderColor =  UIColor.red.cgColor
        } else {
            view.layer.borderColor = UIColor.white.cgColor
        }
        if let lblSpeed = view.viewWithTag(2) as? UILabel{
            if recent == true {
                let formatedSpeed =  (NSString(format:"%.0f", (user.speed * 3.6)))
                lblSpeed.text = "\(formatedSpeed)";
                lblSpeed.textColor = UIColor.black
            } else {
                let dateFormat = DateFormatter()
                dateFormat.dateFormat = "yyyy-MM-dd"
                if dateFormat.string(from: user.time) == dateFormat.string(from: Date()) {
                    dateFormat.dateFormat = "HH:mm:ss"
                } else {
                    dateFormat.dateFormat = "yyyy-MM-dd HH:mm:ss"
                }
                
                let formatedTime = dateFormat.string(from: user.time)
                lblSpeed.textColor = UIColor.gray
                lblSpeed.text = "\(formatedTime)";
            }
        }
    }
    
    func drawPeoples(location: UserGroupCoordinate){
        print("MapViewController drawPeoples \(location.userId)")
        if (self.mapView) != nil {
            if let user = groupManager.getUser(location.groupId, user: location.userId){
                var annVisible = false;
                var exTrack: OSMMapKitPolyline? = nil;
            
                for ann in trackAnnotations {
                    if ann.objId == "utrk\(location.userId)" {
                        exTrack = ann;
                        break;
                    }
                }
                if user.track.count > 0 {
                    let polyline = OSMMapKitPolyline(coordinates: &user.track, count: user.track.count)
                    polyline.color = user.color.hexColor.withAlphaComponent(0.8)
                    polyline.title = user.name
                    polyline.objId = "utrk\(location.userId)"
                    
                    self.mapView.addOverlay(polyline)
                    if (exTrack == nil) {
                        self.trackAnnotations.append(polyline)
                    }
                }
                if (exTrack != nil) {
                    print("removing prev usertrack")
                    self.mapView.removeOverlay(exTrack!)
                }
                
                for ann in self.pointAnnotations {
                    if (ann is User) {
                        if ((ann as! User).mapId == "u\(location.userId)") {
                            annVisible = true;
                            break;
                            
                        }
                    }
                }
                if !annVisible {
                    self.mapView.addAnnotation(user);
                    self.pointAnnotations.append(user);
                    print("add user \(location.userId)")
                    
                } else {
                    if let userView : OSMOMKAnnotationView = self.mapView.view(for: user) as? OSMOMKAnnotationView {
                        self.updateAnotation(view: userView, user:user)
                    }
                    //userView.setNeedsDisplay()
                }
                
                if user == self.trackedUser {
                    self.mapView.setCenter(CLLocationCoordinate2D(latitude: user.coordinate.latitude, longitude: user.coordinate.longitude), animated: true )
                }

            } 
        }
    }
    
    func setupTileRenderer() {
        if let mapStyle = SettingsManager.getKey(SettingKeys.tileSource)?.intValue{
            tileSource = TileSource(rawValue: mapStyle)!
        }
        // 1
        var template: String;
        
        switch self.tileSource {
            case TileSource.Hotosm:
                template = "https://tile-{s}.openstreetmap.fr/hot/{z}/{x}/{y}.png";
            case TileSource.Sputnik:
                template = "http://{s}.tiles.maps.sputnik.ru/{z}/{x}/{y}.png"
            case TileSource.wiki:
                template = "https://maps.wikimedia.org/osm-intl/{z}/{x}/{y}.png"
            default:
                template = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
        }
        
        if (tileRenderer != nil) {
            let curOverlay = tileRenderer.overlay
            if (curOverlay as! OSMTileOverlay).urlTemplate == template {
                return
            }
            self.mapView.removeOverlays([curOverlay])
            
        }
        // 2
        let overlay = OSMTileOverlay(urlTemplate: template)
        overlay.canReplaceMapContent = true
        //overlay.tileSize = CGSize(width: 128, height: 128)
        //overlay.maximumZ = 19
        
        
        // 4
        self.mapView.addOverlay(overlay, level: .aboveLabels)
        
        //5
        tileRenderer = MKTileOverlayRenderer(tileOverlay: overlay)
    }
   
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is OSMMapKitPolyline {
            let lineView = MKPolylineRenderer(overlay: overlay)
            lineView.strokeColor = (overlay as! OSMMapKitPolyline).color
            lineView.lineWidth = 2
            return lineView
        }
        if (overlay is OSMTileOverlay) {
            let renderer = MKTileOverlayRenderer(overlay: overlay)
            return renderer
        } else {
            return MKOverlayRenderer(overlay: overlay)
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        var longNames: Bool = false;
        
        if let sLongNames = SettingsManager.getKey(SettingKeys.longNames) {
            longNames = sLongNames.boolValue
        }
        if annotation is Point {
            let reuseIdentifier = "point"
            var pointView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier)
            
            if pointView == nil {
                pointView = OSMOMKAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
                pointView?.canShowCallout = true
            } else {
                pointView?.annotation = annotation
            }
            pointView?.backgroundColor = (annotation as! Point).color.hexColor;
            if let subtitle = pointView?.detailCalloutAccessoryView!.viewWithTag(10) as? UITextView {
                subtitle.text = annotation.subtitle!
            }

            
            if let title = annotation.title {
                if let letter = pointView!.viewWithTag(1) as? UILabel{
                    letter.textColor = "#000000".hexColor
                    if (longNames) {
                        letter.text = title;
                    } else {
                        letter.text = title!.substring(to: title!.index(title!.startIndex, offsetBy: title!.count>2 ? 2 : title!.count))
                    }
                }
            }
           
            return pointView
        }
        if annotation is User {
            let user = (annotation as! User)
            let reuseIdentifier = "user"
            var userView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier)
            
            if userView == nil {
                userView = OSMOMKAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
                userView?.canShowCallout = false
            } else {
                userView?.annotation = annotation
            }
            self.updateAnotation(view: userView!, user:user)
            
            return userView
        }
        return nil
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if view.annotation is User {
            let user : User = (view.annotation as! User)
            if (self.trackedUser == user) {
                self.trackedUser = nil
                self.connectionManager.sendTrackUser("-1")
            } else {
                if (self.trackedUser != nil) {
                    self.mapView.removeAnnotation(self.trackedUser! )
                    self.mapView.addAnnotation(self.trackedUser! )
                }
                self.trackedUser = user
                self.connectionManager.sendTrackUser("\(self.trackedUser!.u ?? "-1")")
            }
            self.mapView.deselectAnnotation(user, animated: false)

            self.updateAnotation(view: view, user:user)
            
            view.setNeedsDisplay()
            //mapView.setNeedsDisplay()
            if let annotationTitle = view.annotation?.title
            {
                print("User tapped on annotation with title: \(annotationTitle!)")
            }
        }
    }
    
    @IBAction func locateClick(sender: AnyObject) {
        
        self.trackedUser = nil //Перестаем следить за выбранным пользователем
        switch self.mapView.userTrackingMode {
            case .follow:
                self.mapView.setUserTrackingMode(MKUserTrackingMode.followWithHeading, animated: true) //Следим за собой
                break
        default:
            self.mapView.setUserTrackingMode(MKUserTrackingMode.follow, animated: true) //Следим за собой

        }
        mapView.setNeedsDisplay()
    }
}

class OSMTileOverlay: MKTileOverlay {
    let cache = NSCache<NSString, NSData>()
    
    override init(urlTemplate:String?) {
        super.init(urlTemplate: urlTemplate)

        self.canReplaceMapContent = true

    }
    
    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        var sUrl = urlTemplate;
        var balance = "";
        if (sUrl?.contains("{s}"))! {
            switch ((path.x + path.y + path.z) % 3) {
                case 0:
                    balance = "a"
                    break;
                case 1:
                    balance = "b"
                    break;
                case 2:
                    balance = "c"
                    break;
            default:
                balance = ""
            }
            sUrl = sUrl?.replacingOccurrences(of: "{s}", with: balance)
        }
        sUrl = sUrl?.replacingOccurrences(of: "{z}", with: "\(path.z)")
        sUrl = sUrl?.replacingOccurrences(of: "{x}", with: "\(path.x)")
        sUrl = sUrl?.replacingOccurrences(of: "{y}", with: "\(path.y)")

        return URL(string: sUrl!)!
    }
    
    func cacheTile(for url:String, data: Data) {
        var paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true);
        let fullPath =  "\(paths[0])/\(url)"
        let path = URL(fileURLWithPath: fullPath).deletingLastPathComponent().path
        
        var isDir : ObjCBool = false
        let fileManager = FileManager.default;
        
        if !fileManager.fileExists(atPath: path, isDirectory:&isDir) {
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print ("can't create directory \(path)")
            }
        }
        
        do {
            try data.write(to: URL(fileURLWithPath: fullPath))
        } catch {
            print("Failed to cache \(fullPath)")
        }
    }
 
    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let url = self.url(forTilePath: path)
        
        let urlString = "\(url.host!)\(url.path)"
        var paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true);

        let path =  "\(paths[0])/\(urlString)"
        let fileManager = FileManager.default;
        
        if fileManager.fileExists(atPath: "\(path)") {
            do {
                let attr = try fileManager.attributesOfItem(atPath: "\(path)")
                let fileDate = attr[FileAttributeKey.modificationDate] as! Date;
                
                if fileDate.timeIntervalSinceNow < 60 * 60 * 24 * 3 {
                    do {
                        let file: FileHandle? = FileHandle(forReadingAtPath: "\(path)")
                        if file != nil {
                            // Read all the data
                            let data = file?.readDataToEndOfFile()
                            result(data, nil)
                            return
                        }
                     } catch {
                        
                    }
                }
            } catch {
                
            }
        }
 
        let urlReq = URLRequest(url: url);
        //urlReq.cachePolicy = URLRequest.CachePolicy.returnCacheDataElseLoad
        let session = URLSession.shared;
        
        /*
        //Запасной вариант с родным URLCache
        let urlCache = URLCache(memoryCapacity: 1024 * 1024 * 50, diskCapacity: 1024 * 1024 * 200, diskPath: "tiles/\(url.host ?? "")")
        session.configuration.urlCache = urlCache

        if let cachedResponse = urlCache.cachedResponse(for: urlReq) {
            print("found cached response")
            result(cachedResponse.data, nil)
            return
        }
        */
        let task = session.dataTask(with: urlReq as URLRequest) {(data, response, error) in
            guard let data = data, error == nil else {
                LogQueue.sharedLogQueue.enqueue("error: on getting tile")
                return
            }
            self.cacheTile(for: urlString, data: data)
            result (data, error)
        }
        task.resume()
            
        
        
    }
}
