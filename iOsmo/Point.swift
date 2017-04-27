//
//  Point.swift
//  iOsMo
//
//  Created by Alexey Sirotkin on 03.03.17.
//  Copyright © 2017 Alexey Sirotkin. All rights reserved.
//

import Foundation

open class Point: Equatable {
    var u: Int
    var lat: Double
    var lon: Double
    var descr: String = ""
    var color: String = "#ffffff"
    var name: String = ""
    var url: String = ""
    var start: Date?
    var finish: Date?

    init(u: Int, lat: Double, lon: Double, name: String, color: String){
        self.u = u;
        self.lat = lat
        self.lon = lon
        self.name = name;
        self.color = color;

    }
    
    public static func == (left: Point, right: Point) -> Bool {
        return left.u == right.u
    }

}
