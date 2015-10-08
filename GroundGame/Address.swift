//
//  Address.swift
//  GroundGame
//
//  Created by Josh Smith on 10/2/15.
//  Copyright © 2015 Josh Smith. All rights reserved.
//

import Foundation
import MapKit
import SwiftyJSON
import UIKit

enum VisitResult {
    case NotVisited, NotHome, NotInterested, NotSure, Interested
}

struct PinImage {
    static let Blue = UIImage(named: "blue-pin")
    static let Gray = UIImage(named: "grey-pin")
    static let LightBlue = UIImage(named: "light-blue-pin")
    static let Pink = UIImage(named: "pink-pin")
    static let Red = UIImage(named: "red-pin")
    static let White = UIImage(named: "white-pin")
}

struct Address {
    let id: String?
    let latitude: CLLocationDegrees?
    let longitude: CLLocationDegrees?
    let street1: String?
    let street2: String?
    let city: String?
    let stateCode: String?
    let zipCode: String?
    let coordinate: CLLocationCoordinate2D?

    var result: VisitResult = .NotVisited

    var title: String {
        get {
            if let street1 = street1, street2 = street2 {
                return street1 + ", " + street2
            } else if let street1 = street1 {
                return street1
            } else {
                return ""
            }
        }
    }
    
    var subtitle: String {
        get {
            switch result {
            case .NotVisited:
                return "Not visited yet"
            case .NotHome:
                return "No one was home"
            case .NotInterested:
                return "Not interested"
            case .NotSure:
                return "Not sure"
            case .Interested:
                return "Feelin' the Bern"
            }
        }
    }
    
    var image: UIImage? {
        get {
            switch result {
            case .NotVisited:
                return PinImage.Gray
            case .NotSure:
                return PinImage.White
            case .NotInterested:
                return PinImage.Red
            case .Interested:
                return PinImage.Blue
            default:
                return PinImage.Gray
            }
        }
    }

    init(id: String?, addressJSON: JSON) {
        self.id = id
        latitude = addressJSON["latitude"].number as? CLLocationDegrees
        longitude = addressJSON["longitude"].number as? CLLocationDegrees
        street1 = addressJSON["street_1"].string
        street2 = addressJSON["street_2"].string
        city = addressJSON["city"].string
        stateCode = addressJSON["state_code"].string
        zipCode = addressJSON["zip_code"].string
        
        if let resultString = addressJSON["result"].string {
            switch resultString {
            case "not_visited":
                result = .NotVisited
            case "not_home":
                result = .NotHome
            case "not_interested":
                result = .NotInterested
            case "interested":
                result = .Interested
            case "unsure":
                result = .NotSure
            default:
                result = .NotVisited
            }
        }
        
        if let latitude = latitude, let longitude = longitude {
            coordinate = CLLocationCoordinate2D.init(latitude: latitude, longitude: longitude)
        } else {
            coordinate = nil
        }
    }
}