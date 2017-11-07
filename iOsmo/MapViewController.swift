//
//  MapViewController.swift
//  iOsMo
//
//  Created by Alexey Sirotkin on 30.10.17.
//  Copyright © 2017 Alexey Sirotkin. All rights reserved.
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
        print ("OSMOMKAnnotationView Init")
        self.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        //let letter = UILabel(frame: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
        
        let letter = UILabel(frame: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))

        letter.textAlignment = NSTextAlignment.center
        letter.baselineAdjustment = UIBaselineAdjustment.alignCenters
        letter.tag = 1
        if self.reuseIdentifier == "point" {
            layer.cornerRadius = 0
            layer.borderWidth = 1
        } else {
            layer.cornerRadius = frame.width / 2
            layer.borderWidth = 2
        }
        
        self.canShowCallout = true
        
        let label1 = UILabel(frame: CGRect(x:0, y:0, width:200, height:21))
        label1.tag = 10
        
        label1.numberOfLines = 0
        self.detailCalloutAccessoryView = label1;
        
        let width = NSLayoutConstraint(item: label1, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.lessThanOrEqual, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 200)
        label1.addConstraint(width)
        
        
        let height = NSLayoutConstraint(item: label1, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 90)
        label1.addConstraint(height)
        
        self.addSubview(letter);
        
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
    var trackedUser: String = ""
    
    var pointAnnotations = [MKAnnotation]()
    var trackAnnotations = [OSMMapKitPolyline]()
    @IBOutlet weak var mapView:MKMapView!;
    
    var tileRenderer: MKTileOverlayRenderer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("MapViewController viewDidLoad")
        self.setupTileRenderer()

        self.mapView.showsCompass = true
        self.mapView.showsUserLocation = true
        if let lat = SettingsManager.getKey(SettingKeys.lat)?.doubleValue, let lon = SettingsManager.getKey(SettingKeys.lon)?.doubleValue,let zoom = SettingsManager.getKey(SettingKeys.zoom)?.doubleValue {
            if ((lat != 0) && (lon != 0) && (zoom != 0)) {
                self.mapView.setCenter(CLLocationCoordinate2D(latitude: lat, longitude: lon), animated: true)
                
            }
        }
        self.onMonitoringGroupsUpdated = self.groupManager.monitoringGroupsUpdated.add{
            for coord in $0 {
                DispatchQueue.main.async {
                    self.drawPeoples(location: coord)
                }
            }
        }
        _ = self.groupManager.groupsUpdated.add{
            _ = $0
            _ = $1
            DispatchQueue.main.async {
                self.updateGroupsOnMap(groups: self.groupManager.allGroups )
            }
        }
        _ = self.groupManager.groupListUpdated.add{
            let groups = $0
            DispatchQueue.main.async {
                self.updateGroupsOnMap(groups: groups)
            }
        }
        _ = self.connectionManager.connectionRun.add{
            let theChange = $0.0
            
            if theChange {
                DispatchQueue.main.async {
                    self.connectionManager.activatePoolGroups(1)
                }
            }
        }

        self.mapView.delegate = self
    }
    
    override func viewWillAppear(_ animated:Bool) {
        super.viewWillAppear(animated)
        
        print("MapViewController viewWillAppear")
        Analytics.logEvent("map_open", parameters: nil)
        
        if (groupManager.allGroups.count) > 0 {
            self.connectionManager.activatePoolGroups(1)
            
            groupManager.updateGroupsOnMap([1])
            
            self.updateGroupsOnMap(groups: groupManager.allGroups )
        }
    }
    
    
    override func viewWillDisappear(_ animated: Bool){
        super.viewWillDisappear(animated)
        print("MapViewController viewWillDisappear")
        groupManager.updateGroupsOnMap([])
        
        SettingsManager.setKey("\(self.mapView.centerCoordinate.latitude)" as NSString, forKey: SettingKeys.lat)
        SettingsManager.setKey("\(self.mapView.centerCoordinate.longitude)" as NSString, forKey: SettingKeys.lon)

    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func updateGroupsOnMap(groups: [Group]) {
        print("updateGroupsOnMap")
        var curAnnotations = [String]()
        var curTracks = [String]()
        
        for group in groups{
            for user in group.users {
                if user.lat > -3000 && user.lon > -3000 {
                    let location = LocationModel(lat: user.lat, lon: user.lon)
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
            var annObjId:String?
            
            if (ann is User)  {
                annObjId = "u\(ann as! User).id)"
            } else if (ann is Point) {
                annObjId = "p\((ann as! Point).u)"
            }
            

            if curAnnotations.count > 0 {
                for objId in curAnnotations {
                    if annObjId == objId {
                        delete = false;
                        break;
                    }
                }
            }
            
            if (delete == true) {
                
                if !(ann is Point && ann.subtitle! == "Waypoint") {
                    do {
                        self.mapView.removeAnnotation(ann)

                    } catch {
                        
                    }
                    pointAnnotations.remove(at: idx)
                    print("removing \(annObjId)")
                }
            } else {
                idx = idx + 1
            }
        }
        idx = 0;
        /*
         for ann in trackAnnotations {
         var delete = true;
         if curTracks.count > 0 {
         for objId in curTracks {
         if annObjId == objId {
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
         */
    }
    
    func drawTrack(track:Track) {
        print ("MapViewController drawTrack")
        
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
                                let polyline = OSMMapKitPolyline(coordinates: &coordinates, count: coordinates.count)
                                // Set the custom `color` property, later used in the `mapView:strokeColorForShapeAnnotation:` delegate method.
                                polyline.color = track.color.hexColor.withAlphaComponent(0.8)
                                polyline.title = track.name
                                polyline.objId = "t\(track.u)"
                                
                                self.mapView.add(polyline)
                                self.trackAnnotations.append(polyline)

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
                    self.mapView.addAnnotation(point);
                    self.pointAnnotations.append(point)

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
    func drawPoint(point: Point, group: Group){
        print("MapViewController drawPoint")
        let clLocation = CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon)
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
                point.subtitle = "\(group.name)\n\(point.descr)"
                self.mapView.addAnnotation(point);
                self.pointAnnotations.append(point)
                print("adding point \(point.u)")
            }
        }
    }
    
    func drawPeoples(location: UserGroupCoordinate){
        print("MapViewController drawPeoples")
        let clLocation = CLLocationCoordinate2D(latitude: location.location.lat, longitude: location.location.lon)
        if (self.mapView) != nil {
            if let user = groupManager.getUser(location.groupId, user: location.userId){
                let userName = user.name
                var annVisible = false;
                for ann in self.pointAnnotations {
                    if (ann is User) {
                        
                        if ((ann as! User).id == "\(location.userId)") {
                            annVisible = true;
                            break;
                            
                        }
                    }
                    
/*

                    let annObjId = ann.data?["objId"] as? String
                    if annObjId == "u\(location.userId)" {
                        /*
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
                         
                         ann.labelColor = "#000000";
                         */
                        annVisible = true;
                        break;
                    }
 */
                }
                if !annVisible {
                    self.mapView.addAnnotation(user);
                    self.pointAnnotations.append(user);
                    print("add user \(location.userId)")
                }
            }
        }
    }
    
    func setupTileRenderer() {
        // 1
        let template = "https://tile-{s}.openstreetmap.fr/hot/{z}/{x}/{y}.png"//"https://tile.openstreetmap.org/{z}/{x}/{y}.png"
        
        // 2
        let overlay = OSMTileOverlay(urlTemplate: template)

        
        // 4
        self.mapView.add(overlay, level: .aboveLabels)
        
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
        return tileRenderer
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is Point {
            let reuseIdentifier = "point"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier)
            
            if annotationView == nil {
                annotationView = OSMOMKAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            annotationView?.backgroundColor = (annotation as! Point).color.hexColor;
            if let subtitle: UILabel = annotationView?.detailCalloutAccessoryView!.viewWithTag(10) as! UILabel {
                subtitle.text = annotation.subtitle!
            }

            
            if let title = annotation.title {
                let v = annotationView!.viewWithTag(1)
                if let letter = v as? UILabel{
                    letter.textColor = "#000000".hexColor
                    letter.text = title!.substring(to: title!.index(title!.startIndex, offsetBy: title!.characters.count>2 ? 2 : title!.characters.count))
                }
            }
           
            return annotationView
        }
        if annotation is User {
            let reuseIdentifier = "point"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier)
            
            if annotationView == nil {
                annotationView = OSMOMKAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            annotationView?.backgroundColor = (annotation as! User).color.hexColor;
            if let subtitle: UILabel = annotationView?.detailCalloutAccessoryView!.viewWithTag(10) as! UILabel {
                subtitle.text = annotation.subtitle!
            }
            if let title = annotation.title {
                let v = annotationView!.viewWithTag(1)
                if let letter = v as? UILabel{
                    letter.textColor = "#000000".hexColor
                    letter.text = title!.substring(to: title!.index(title!.startIndex, offsetBy: title!.characters.count>2 ? 2 : title!.characters.count))
                }
            }
            
            return annotationView
        }
        return nil
    }
}

class OSMTileOverlay: MKTileOverlay {
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
        //print(sUrl)

        return URL(string: sUrl!)!
    }
}
