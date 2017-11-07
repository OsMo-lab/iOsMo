//
//  Point.swift
//  iOsMo
//
//  Created by Alexey Sirotkin on 03.03.17.
//  Copyright © 2017 Alexey Sirotkin. All rights reserved.
//

import Foundation
import MapKit


public class Point: NSObject, MKAnnotation {
    var u: Int
    var lat: Double
    var lon: Double
    var descr: String = ""
    var color: String = "#ffffff"
    var name: String = ""
    var url: String = ""
    var start: Date?
    var finish: Date?
    
    public var subtitle: String?   //MKAnnonation protocol

    init(json: Dictionary<String, AnyObject>) {
        print(json)
        self.u = json["u"] as! Int
        self.lat = atof(json["lat"] as! String)
        self.lon = atof(json["lon"] as! String)
        self.name = json["name"] as! String
        self.descr = json["description"] as! String
        self.color = json["color"] as! String
        
        self.subtitle = self.descr
    }
    
    public static func == (left: Point, right: Point) -> Bool {
        return left.u == right.u
    }
    
    
    //MKAnnonation protocol
    open var title: String? {
        return name;
    }
    
    
    open var coordinate : CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: lat, longitude: lon);
    }
}

