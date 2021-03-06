//
//  Location.swift
//  MyDining
//
//  Created by Ian McDowell on 9/12/14.
//  Copyright (c) 2014 Ian McDowell. All rights reserved.
//

import UIKit

class Location: NSObject {
    
    var name: String!
    var id: Int!
    var addr1: String!
    var addr2: String!
    var schedule: Dictionary<Int, (NSDate, NSDate)>?
    
    var active: Bool!
   
}
