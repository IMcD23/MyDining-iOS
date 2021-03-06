//
//  MenuViewController.swift
//  MyDining
//
//  Created by Arun Kumar Sondhi on 9/12/14.
//  Copyright (c) 2014 Ian McDowell. All rights reserved.
//

import UIKit
import Alamofire

let reuseIdentifier = "cell"


class MenuViewController: UITableViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    var stations: Array<MenuStation>!
    var allCondiments: Dictionary<String, CondimentGroup>!
    var location: Location!
    var appDelegate: AppDelegate!
    @IBOutlet var alocation: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        self.stations = Array<MenuStation>()
        self.allCondiments = Dictionary<String, CondimentGroup>()
        
        self.title = self.location.name;
        
        self.tableView.registerClass(UITableViewHeaderFooterView.classForCoder(), forHeaderFooterViewReuseIdentifier: "header");
        
        self.loadMenu()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func loadMenu() {
        Alamofire.request(.GET, "\(Utils.getBaseURL())/xmlstoremenu.dca?dx=123456789&s=\(location.id)&op=0", parameters: nil, encoding: ParameterEncoding.URL).responseString { (request: NSURLRequest, response: NSHTTPURLResponse?, data: String?, error: NSError?) -> Void in
            if (error != nil) {
                // something bad happened!!
                NSLog("Error loading menu. \(error?.localizedDescription).");
                return;
            }
            NSLog("Request complete.");
            self.parseMenu(data!);
        }
    }
    
    func parseMenu(menuitems: String) {
        // form valid XML string
        var info: NSData = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<xml>\n\(menuitems)\n</xml>".dataUsingEncoding(NSUTF8StringEncoding)!
        
        // load into parser
        var doc: TFHpple = TFHpple(HTMLData: info)
        
        // find root
        var elements = doc.searchWithXPathQuery("//menu")
        
        // parse condiments
        var condimentsElements: TFHppleElement = elements[1] as TFHppleElement
        var condimentGroups = condimentsElements.childrenWithTagName("cc") as Array<TFHppleElement>
        
        for item in condimentGroups{
            var i = CondimentGroup()
            i.name = item.objectForKey("cond")
            i.id = item.objectForKey("cclass")
            i.min = item.objectForKey("cmin").toInt()
            i.max = item.objectForKey("cdisp").toInt()
            
            var items = item.childrenWithTagName("cond") as Array<TFHppleElement>
            for cond in items {
                var j = Condiment()
                j.name = cond.objectForKey("cname")
                j.id = cond.objectForKey("cid").toInt()
                if let cost = cond.objectForKey("ccost"){
                    j.cost = NSString(string: cost).doubleValue
                }
                i.condiments.append(j)
            }
            self.allCondiments[i.id] = i
            
        }
        
        
        // find station element
        var stationElement: TFHppleElement = elements[0] as TFHppleElement
        var stationsItems = stationElement.childrenWithTagName("station") as Array<TFHppleElement>
        
        NSLog("There were \(stationsItems.count) stations found.")
        
        // parse stations
        for station in stationsItems {
            var st = MenuStation()
            
            // parse station info
            st.name = station.objectForKey("name");
            st.id = station.objectForKey("id").toInt();
            
            var stationItems = station.childrenWithTagName("item") as Array<TFHppleElement>
            for item in stationItems {
                var menuItem = MenuItem();
                
                // parse each item info
                menuItem.name = item.objectForKey("idesc");
                menuItem.id = item.objectForKey("iid").toInt();
                menuItem.imageName = item.objectForKey("igroup");
                menuItem.cost = NSString(string: item.objectForKey("icost")).doubleValue
                menuItem.info = item.objectForKey("ifdesc");
                
                // get condiments for each item
                var condimentStr = item.objectForKey("icond")
                if (condimentStr != nil) {
                    var cstr = condimentStr as NSString
                    var length = cstr.length
                    
                    for (var i = 0; i < length; i += 2) {
                        var str = cstr.substringWithRange(NSMakeRange(i, 2)).lowercaseString
                        
                        var condimentGroup = self.allCondiments[str];
                        if (condimentGroup != nil) {
                            menuItem.condimentGroups.append(condimentGroup!)
                        }
                    }
                    
                }
                
                
                st.items.append(menuItem);
            }
            self.stations.append(st);
            
        }
        
        self.tableView.reloadData()
    }
    
    // MARK: UITableViewDataSource
    
    override func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterViewWithIdentifier("header") as UITableViewHeaderFooterView
        
        var titleLabel = header.contentView.viewWithTag(1) as UILabel?;
        if (titleLabel == nil) {
            var backgroundColor = UIColor(red: 229/255, green: 141/255, blue: 56/255, alpha: 1.0);
            header.contentView.backgroundColor = backgroundColor;
            titleLabel = UILabel(frame: CGRectMake(10.0, 0.0, 300.0, 40.0))
            titleLabel!.textColor = UIColor.whiteColor();
            titleLabel!.backgroundColor = UIColor.clearColor();
            titleLabel!.shadowOffset = CGSizeMake(0.0, 0.0);
            titleLabel!.tag = 1;
            titleLabel!.font = UIFont(name: "Helvetica-Neue-Light", size: 18.0);
            header.contentView.addSubview(titleLabel!)
        }
        
        var sectionTitle = self.stations[section].name
        
        titleLabel!.text = sectionTitle;
        
        return header
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("cell") as MenuSectionCell
        
        cell.setCollectionViewDelegate(self, dataSource: self);
        
        cell.collectionView.tag = indexPath.section;
        
        cell.collectionView.reloadData()
        
        return cell
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return self.stations.count
    }
    

    // MARK: UICollectionViewDataSource

    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        var stationNumber = collectionView.tag;
        var items = self.stations[stationNumber]
        
        //NSLog("numberOfItemsInSection: \(stationNumber) = \(items.items.count)")
        return items.items.count
    }

    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath) as MenuItemCell
    
        var stationNumber = collectionView.tag
        var menuItem = self.stations[stationNumber].items[indexPath.item];
        
       // NSLog("cellForItemAtIndexPath: \(stationNumber) = \(menuItem.name)")
        
        // Configure the cell
        cell.name.text = menuItem.name
        cell.image.image = nil;
        cell.price.text = NSString(format: "$%.02f",menuItem.cost)
        
        var pre = appDelegate.configuration["uplImagePre"]!
        var url = "\(pre)\(menuItem.imageName).png";
        Alamofire.request(.GET, url, parameters: nil, encoding: ParameterEncoding.URL).response { (request, response, data, error) -> Void in
            if (error != nil) {
                NSLog("Failed to load image at url \(url)")
                cell.image.image = nil
                return;
            }
            var image = UIImage(data: data as NSData)
            cell.image.image = image
            cell.image.alpha = 0.0
            UIView.animateWithDuration(0.5, animations: { () -> Void in
                cell.image.alpha = 1.0
            })
        }
    
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        var stationNumber = collectionView.tag
        var menuItem = self.stations[stationNumber].items[indexPath.item]
        
        var navController = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("ItemSummaryViewController") as UINavigationController
        var itemSummaryViewController = navController.viewControllers.first as ItemSummaryViewController
        
        var order = Order();
        order.item = menuItem;
        order.location = location
        
        itemSummaryViewController.order = order;
        
        self.presentViewController(navController, animated: true, completion: nil);
    }

    // MARK: UICollectionViewDelegate

    /*
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    func collectionView(collectionView: UICollectionView!, shouldHighlightItemAtIndexPath indexPath: NSIndexPath!) -> Bool {
        return true
    }
    */

    /*
    // Uncomment this method to specify if the specified item should be selected
    func collectionView(collectionView: UICollectionView!, shouldSelectItemAtIndexPath indexPath: NSIndexPath!) -> Bool {
        return true
    }
    */

    /*
    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
    func collectionView(collectionView: UICollectionView!, shouldShowMenuForItemAtIndexPath indexPath: NSIndexPath!) -> Bool {
        return false
    }

    func collectionView(collectionView: UICollectionView!, canPerformAction action: String!, forItemAtIndexPath indexPath: NSIndexPath!, withSender sender: AnyObject!) -> Bool {
        return false
    }

    func collectionView(collectionView: UICollectionView!, performAction action: String!, forItemAtIndexPath indexPath: NSIndexPath!, withSender sender: AnyObject!) {
    
    }
    */

}
