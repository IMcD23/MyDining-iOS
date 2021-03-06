//
//  CheckOutViewController.swift
//  MyDining
//
//  Created by Ian McDowell on 9/13/14.
//  Copyright (c) 2014 Ian McDowell. All rights reserved.
//

import UIKit

class CheckOutViewController: UITableViewController, UIPickerViewDelegate, UIPickerViewDataSource{
    
    @IBOutlet var pickerView: UIPickerView!
    @IBOutlet var timePicker: UIDatePicker!
    
    var uniqueID: String!
    var auth: String!
    var loadedDate: NSDate?
    var totalPrice: String?
    var paymentMethods = Array<PaymentMethod>()
    
    var cart: Cart!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.pickerView.delegate = self;
        
        self.uniqueID = (UIApplication.sharedApplication().delegate as AppDelegate).configuration["ouniq"];
        self.auth = (UIApplication.sharedApplication().delegate as AppDelegate).account!.authID
        
        self.loadAvailableDates()
        
        // Do any additional setup after loading the view.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func processOrder(sender: AnyObject) {
        // get selected values of pickers
        var orderDate = timePicker.date
        
        var paymentMethod = self.paymentMethods[pickerView.selectedRowInComponent(0)]
        
        self.checkoutOrder(orderDate, paymentMethod: paymentMethod)

    }
    
    // MARK : Loading shit
    func loadAvailableDates() {
        var item = cart.items[0]
        
        var url = "\(Utils.getBaseURL())/qp.dca?nmout=1&dx=12345678"
        var params = "oGetAvailableDates~\(uniqueID!)~\(auth)~\(item.location.id)~0~~0"
        Networking.post(url, data: params) { (data, error) -> Void in
            if (error != nil) {
                NSLog("Error loading available dates: \(error?.localizedDescription)")
                return
            }
            if (data!.rangeOfString("410|OK|") == nil) {
                self.showErrorLoading()
                return;
            }
            // 410|OK|1|120140914
            var days = (data! as NSString).stringByReplacingOccurrencesOfString("410|OK|", withString: "");
            
            var daysArray = days.componentsSeparatedByString("|");
            var day = (daysArray[1] as NSString).substringFromIndex(1);
            
            var comps = NSDateComponents()
            comps.year = ((day as NSString).substringWithRange(NSMakeRange(0, 4)) as String).toInt()!
            comps.month = ((day as NSString).substringWithRange(NSMakeRange(4, 2)) as String).toInt()!
            comps.day = ((day as NSString).substringWithRange(NSMakeRange(6, 2)) as String).toInt()!
            self.loadedDate = NSCalendar.currentCalendar().dateFromComponents(comps)
            
            self.loadAvailableTimes()
        }
    }
    
    func loadAvailableTimes() {
        var item = cart.items[0]
        
        var formatter = NSDateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        var dateString = formatter.stringFromDate(self.loadedDate!)
        
        var url = "\(Utils.getBaseURL())/qp.dca?nmout=1&dx=12345678"
        var params = "oGetTimeSlots~\(uniqueID!)~\(auth)~\(item.location.id)~0~\(dateString)~~0";
        Networking.post(url, data: params) { (data, error) -> Void in
            if (error != nil) {
                NSLog("Error loading available dates: \(error?.localizedDescription)")
                return
            }
            if (data!.rangeOfString("420|OK|") == nil) {
                self.showErrorLoading()
                return;
            }
            // 420|OK|79|01615|01620|01625|01630|01635|01640|01645|01650|01655|01700|01705...
            
            var times = (data! as NSString).stringByReplacingOccurrencesOfString("420|OK|", withString: "");
            
            var timesArray = times.componentsSeparatedByString("|");
            
            // parse start (minimum) date
            var firstTime = (timesArray[1] as NSString).substringFromIndex(1);
            
            var firstComps = NSCalendar.currentCalendar().components(NSCalendarUnit.DayCalendarUnit | NSCalendarUnit.YearCalendarUnit | NSCalendarUnit.MonthCalendarUnit, fromDate: self.loadedDate!)
            firstComps.hour = ((firstTime as NSString).substringWithRange(NSMakeRange(0, 2)) as String).toInt()!
            firstComps.minute = ((firstTime as NSString).substringWithRange(NSMakeRange(2, 2)) as String).toInt()!
            
            var startDate = NSCalendar.currentCalendar().dateFromComponents(firstComps)
            self.timePicker.minimumDate = startDate
            
            // parse end (maximum) date
            
            var lastTime = (timesArray[timesArray.count - 1] as NSString).substringFromIndex(1);
            
            var lastComps = NSCalendar.currentCalendar().components(NSCalendarUnit.DayCalendarUnit | NSCalendarUnit.YearCalendarUnit | NSCalendarUnit.MonthCalendarUnit, fromDate: self.loadedDate!)
            lastComps.hour = ((lastTime as NSString).substringWithRange(NSMakeRange(0, 2)) as String).toInt()!
            lastComps.minute = ((lastTime as NSString).substringWithRange(NSMakeRange(2, 2)) as String).toInt()!
            
            var endDate = NSCalendar.currentCalendar().dateFromComponents(lastComps)
            self.timePicker.maximumDate = endDate
            
            // do a price check on the order
            self.loadPriceCheck();
        }
    }
    
    func loadPriceCheck() {
        var item = cart.items[0]
        
        var formatter = NSDateFormatter()
        formatter.dateFormat = "yyyyMMddHHmm"
        var dateTimeString = formatter.stringFromDate(self.timePicker.minimumDate!)
        
        var url = "\(Utils.getBaseURL())/qp.dca?nmout=1&dx=12345678"
        var params = "oMenuLevelPriceCheck~\(uniqueID!)~\(auth)~\(item.location.id)~\(dateTimeString)~1~\(item.stringify())";
        
        Networking.post(url, data: params) { (data, error) -> Void in
            if (error != nil) {
                NSLog("Error loading price check: \(error?.localizedDescription)")
                return
            }
            if (data!.rangeOfString("440|OK|") == nil) {
                self.showErrorLoading()
                return;
            }
            // 440|OK|1|1.00
            var price = (data! as NSString).stringByReplacingOccurrencesOfString("440|OK|", withString: "");
            self.totalPrice = price.componentsSeparatedByString("|")[1];
            
            NSLog("Order total: \(self.totalPrice)")
            
            // load the payment methods now!
            self.loadPaymentMethods()
        }
        
    }
    
    func loadPaymentMethods() {
        var item = cart.items[0]
        
        var priceWithoutDot = (self.totalPrice! as NSString).stringByReplacingOccurrencesOfString(".", withString: "")
        
        var url = "\(Utils.getBaseURL())/qp.dca?nmout=1&dx=12345678"
        var params = "sListPaymentMethods~\(uniqueID!)~\(auth)~\(item.location.id)~0~\(priceWithoutDot)";
        
        Networking.post(url, data: params) { (data, error) -> Void in
            if (error != nil) {
                NSLog("Error loading payment methods: \(error?.localizedDescription)")
                return
            }
            if (data!.rangeOfString("380|OK|") == nil) {
                if (data!.rangeOfString("380.01") != nil) {
                    var alert = UIAlertView(title: "Oh no!", message: "It seems you have not added any payment options for this order type. You can add those online.", delegate: self, cancelButtonTitle: "Okay")
                    alert.show();
                    self.navigationController!.popViewControllerAnimated(true);
                    return;
                }
                self.showErrorLoading()
                return;
            }
            // 380|OK|4|31695|ISUCard|3|4|Yearly Meal Block|2961|0000|0|31694|ISUCard|3|4|Yearly Meal Block|2961|0000|0|31692|ISU|3|7|SemesterPlan|2961|0000|1|26702|ISU|3|7|SemesterPlan|2961|0000|1
            var paymentMethodsString = (data! as NSString).stringByReplacingOccurrencesOfString("380|OK|", withString: "");
            var paymentMethods = paymentMethodsString.componentsSeparatedByString("|");
            
            var numberOfPaymentMethods = (paymentMethods[0] as String).toInt()!
            
            for (var i = 0; i < numberOfPaymentMethods * 8; i += 8) {
                var paymentMethod = PaymentMethod()
                paymentMethod.id = (paymentMethods[i+1] as String).toInt()!
                paymentMethod.name = paymentMethods[i+2]
                paymentMethod.tender = paymentMethods[i+4]
                paymentMethod.info = paymentMethods[i+5]
                self.paymentMethods.append(paymentMethod);
            }
            
            self.pickerView.reloadAllComponents()
            
        }
    }
    
    func checkoutOrder(date: NSDate, paymentMethod: PaymentMethod) {
        var item = cart.items[0]
        
        var formatter = NSDateFormatter()
        formatter.dateFormat = "yyyyMMdd~HHmm"
        var dateTimeString = formatter.stringFromDate(self.timePicker.date)
        
        var url = "\(Utils.getBaseURL())/qp.dca?nmout=1&dx=12345678"
        var params = "oCheckoutOrder~\(uniqueID!)~\(auth)~\(item.location.id)~0~\(dateTimeString)~\(paymentMethod.id)~\(paymentMethod.tender)~~~~1~1~\(item.stringify())";
        
        if (!Utils.isDebug()) {
        
            Networking.post(url, data: params) { (data, error) -> Void in
                if (error != nil) {
                    NSLog("Error loading payment methods: \(error?.localizedDescription)")
                    return
                }
                // 300|OK|778530|1.00|0.00|0.00|0|0.00|1.00|0.00|0.00|0.00
                NSLog(data!)
            
            
                self.showOrderComplete("12345678", date: self.timePicker.date, order: item)
            
            
            }
            
        } else {
            //debug mode
            self.showOrderComplete("123456", date: self.timePicker.date, order: item);
        }
    }
    
    func showOrderComplete(confirmationNumber: String, date: NSDate!, order: Order) {
        var orderProcessedNavController = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("OrderProcessedViewController") as UINavigationController
        var orderProcessedViewController = orderProcessedNavController.viewControllers.first as OrderProcessedController
        
        orderProcessedViewController.number = confirmationNumber
        orderProcessedViewController.time = date;
        orderProcessedViewController.pickupLocation = order.location.name
        
        self.presentViewController(orderProcessedNavController, animated: false, completion: nil)
    }
    
    func showErrorLoading() {
        var alert = UIAlertView(title: "Error", message: "Failed to load vital information... :(", delegate: self, cancelButtonTitle: "OK")
        alert.show()
        self.navigationController!.popViewControllerAnimated(true);
    }
    
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.paymentMethods.count;
    }
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String! {
        var paymentMethod = self.paymentMethods[row]
        return "\(paymentMethod.name) - \(paymentMethod.info)";
    }
    
    
    
    /*
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue!, sender: AnyObject!) {
    // Get the new view controller using segue.destinationViewController.
    // Pass the selected object to the new view controller.
    }
    */
    
}