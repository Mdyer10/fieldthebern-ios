//
//  AddAddressViewController.swift
//  FieldTheBern
//
//  Created by Josh Smith on 10/4/15.
//  Copyright © 2015 Josh Smith. All rights reserved.
//

import UIKit
import MapKit

class AddAddressViewController: UIViewController, UITableViewDelegate, UITextFieldDelegate, SubmitButtonWithoutAPIDelegate {

    var previousLocation: CLLocation?
    var location: CLLocation?
    var userLocation: CLLocation?
    var placemark: CLPlacemark?
    var previousPlacemark: CLPlacemark?
    var address: Address?
    var people: [Person]?
    var updatingLocation: Bool = false
    var locationUpdated: Bool = false
    
    let filterRadiusInMeters:Double = 200
    
    let timeoutConstantInHours = 24
    
    var addressString: String {
        get {
            let street = streetAddress.text
            let number = apartmentNumber.text
            
            switch (street, number) {
            case let (street?, number?):
                return street + " " + number
            case let (street?, nil):
                return street
            case let (nil, number?):
                return number
            case (nil, nil):
                return ""
            }
        }
    }
    
    let geocoder = CLGeocoder()
    
    @IBOutlet weak var addressActivityContainer: UIView!
    
    @IBOutlet weak var streetAddress: PaddedTextField! {
        didSet {
            streetAddress.attributedPlaceholder = NSAttributedString(string: "Street Address", attributes: Text.PlaceholderAttributes)
            streetAddress.font = Text.Font
            streetAddress.delegate = self
        }
    }
    
    @IBOutlet weak var apartmentNumber: PaddedTextField! {
        didSet {
            apartmentNumber.attributedPlaceholder = NSAttributedString(string: "Apt / Suite / Other", attributes: Text.PlaceholderAttributes)
            apartmentNumber.font = Text.Font
            apartmentNumber.delegate = self
        }
    }

    @IBOutlet weak var submitButton: UIButton!
    
    @IBAction func cancel(sender: UIBarButtonItem) {
        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func pressSubmitAddress(sender: UIButton) {

        
        if (streetAddress.text!.isEmpty) {
            
            let alert = UIAlertController.errorAlertControllerWithTitle("Missing Address Info", message: "Please enter a street address.")            
            self.presentViewController(alert, animated: true, completion: nil)
            
            return
        }
        
        let alert = UIAlertController(title: "Verify Address", message: "\n\(addressString)\n\nAre you sure this is the right address? GPS is not 100% accurate.", preferredStyle: UIAlertControllerStyle.Alert)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) { (_) in
        }
        let OKAction = UIAlertAction(title: "Submit", style: .Default) { (action) in
            self.submitForm()
        }
        alert.addAction(cancelAction)
        alert.addAction(OKAction)
        
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    // MARK: - Lifecycle Functions
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.navigationItem.leftBarButtonItem?.setTitleTextAttributes([NSForegroundColorAttributeName: UIColor.whiteColor(), NSFontAttributeName: UIFont(name: "Lato-Medium", size: 16)!], forState: UIControlState.Normal)
        
        // Set submit button's submitting state
        submitButton.setTitle("Verifying Address".uppercaseString, forState: UIControlState.Disabled)
        submitButton.setBackgroundImage(UIImage.imageFromColor(Color.Gray), forState: UIControlState.Disabled)
        
        placemark = previousPlacemark
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if locationNeedsUpdating() {
            self.addressIsLoading()
            if let currentLocation = location {
                geocoder.reverseGeocodeLocation(currentLocation) { (placemarks, error) -> Void in
                    if let placemarksArray = placemarks {
                        if placemarksArray.count > 0 {
                            let pm = placemarks![0] as CLPlacemark
                            self.placemark = pm
                            NSNotificationCenter.defaultCenter().postNotificationName("placemarkUpdated", object: self, userInfo: ["placemark": pm])
                            self.updateAddressField()
                            self.addressDidLoad()
                        }
                    }
                }
            }
        } else {
            self.updateAddressField()
        }
    }
    
    // MARK: - Segues
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        if let identifier = segue.identifier {
            if(identifier == "SubmitAddress") {
                let conversationViewController = segue.destinationViewController as? ConversationViewController
                conversationViewController?.location = self.location
                conversationViewController?.placemark = self.placemark
                if let people = self.people {
                    conversationViewController?.people = people
                }
                conversationViewController?.address = self.address
            }
        }

    }
    
    // MARK: - Submit Button Methods
    
    func isSubmitting() {
        submitButton.enabled = false
    }
    
    func finishedSubmittingWithError(errorTitle: String, errorMessage: String) {
        
        let alert = UIAlertController.errorAlertControllerWithTitle(errorTitle, message: errorMessage)
        
        presentViewController(alert, animated: true, completion: nil)

        submitButton.enabled = true
    }
    
    // MARK: - TouchesEnded
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    // MARK: - Text Field Delegate Methods
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        switch textField {
        case streetAddress:
            return apartmentNumber.becomeFirstResponder()
        case apartmentNumber:
            return apartmentNumber.resignFirstResponder()
        default:
            return false
        }
    }
    
    func textFieldDidBeginEditing(textField: UITextField) {
        switch textField {
        case streetAddress:
            self.locationUpdated = false
            break
        default:
            break
        }
    }
    
    func textFieldDidEndEditing(textField: UITextField) {
        switch textField {
        case streetAddress:
            forwardGeocodeBasedOnTextField()
            break
        default:
            break
        }
    }

    // MARK: - Location updating methods
    
    func forwardGeocodeBasedOnTextField(onSuccess: ((success: Bool, errorTitle:String?, errorMessage:String?) -> Void)? = nil) {
        
        if(self.streetAddress.text?.length > 0) {
            
            if let city = self.placemark!.locality, let state = self.placemark!.administrativeArea {
                
                let address = self.streetAddress.text! + " " + city + " " + state
                let geocoder:CLGeocoder = CLGeocoder()
                
                // We're about to update the location
                self.updatingLocation = true

                geocoder.geocodeAddressString(address, completionHandler: { (placemarks, error) -> Void in
                    
                    if (error == nil && placemarks!.count > 0) {
                        let tempPlacemark = placemarks![0]
                        let tempLocation = tempPlacemark.location!
                        let tempThoroughfare = tempPlacemark.thoroughfare
                        
                        let meters: CLLocationDistance = tempLocation.distanceFromLocation(self.userLocation!)
                        
                        // 200 meters is about a radius of 4 NYC city blocks.
                        if (meters > self.filterRadiusInMeters) {
                            if(onSuccess != nil)
                            {
                                if(tempThoroughfare == nil)
                                {
                                    onSuccess!(success: false, errorTitle: "No location was found", errorMessage: "\n\(self.streetAddress.text!) could not be found. Try again.")
                                }
                                else
                                {
                                onSuccess!(success: false, errorTitle: "Too far from location", errorMessage: "\n\(tempThoroughfare!) is too far for you to submit. Try again.")
                                }
                            }
                            else
                            {
                                if(tempThoroughfare == nil)
                                {
                                    self.finishedSubmittingWithError("No location was found", errorMessage: "\n\(self.streetAddress.text!) could not be found. Try again.")
                                }
                                else
                                {
                                    self.finishedSubmittingWithError("Too far from location", errorMessage: "\n\(tempThoroughfare!) is too far for you to submit. Try again.")
                                }
                            }
                        } else {
                            self.previousLocation = CLLocation(latitude: self.location!.coordinate.latitude, longitude: self.location!.coordinate.longitude)
                            self.location = tempLocation
                            self.locationUpdated = true
                            
                            if(onSuccess != nil)
                            {
                                onSuccess!(success: true, errorTitle:nil, errorMessage:nil)
                            }
                        }
                        
                        // We've finished updating the location
                        self.updatingLocation = false
                    } else {
                        // We've finished updating the location
                        self.updatingLocation = false
                        
                        if(onSuccess != nil)
                        {
                            onSuccess!(success: false, errorTitle:"No location was found", errorMessage:"Please check the entered address and try again")
                        }
                        else
                        {
                            self.finishedSubmittingWithError("No location was found", errorMessage: "Please check the entered address and try again")
                        }
                    }
                })
            }
        }
    }
    
    func didLocationChange() -> Bool {
        
        if let currentLocation = location, previousLocation = previousLocation {
            
            if currentLocation.distanceFromLocation(previousLocation) >= 1 {
                return true
            }
        }
        return false
    }
    
    func locationNeedsUpdating() -> Bool {
        return didLocationChange() || self.placemark == nil
    }
    
    func updateAddressField() {
        if let placemark = self.placemark {
            if let thoroughfare = placemark.thoroughfare,
                let subThoroughfare = placemark.subThoroughfare {
                    self.streetAddress.text = "\(subThoroughfare) \(thoroughfare)"
            }
        }
    }
    
    func addressIsLoading() {
        self.addressActivityContainer.hidden = false
        self.streetAddress.enabled = false
        self.apartmentNumber.enabled = false
    }
    
    func addressDidLoad() {
        self.addressActivityContainer.hidden = true
        self.streetAddress.enabled = true
        self.apartmentNumber.enabled = true
    }
    
    // MARK: - Submitting form
    
    func processAndSubmitForm()
    {
        if let location = self.location, let placemark = self.placemark {
            
            isSubmitting()
            
            let address = Address(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, street1: streetAddress.text, street2: apartmentNumber.text, city: placemark.locality, stateCode: placemark.administrativeArea, zipCode: placemark.postalCode, bestResult: .NotVisited, lastResult: .Unknown)
            
            AddressService().getAddress(address, callback: { (returnedAddress, people, success, error) -> Void in
                
                if success {
                    if returnedAddress != nil {
                        self.people = people
                        self.address = returnedAddress
                    } else {
                        self.address = address
                    }
                    
                    if let lastVisited = self.address?.visitedAt
                    {
                        if(NSDate().hoursFrom(lastVisited) < self.timeoutConstantInHours) {
                            let timeSince = NSDate().offsetFrom(lastVisited)
                            
                            let alert = UIAlertController.errorAlertControllerWithTitle("Visit not allowed", message: "You can't canvass the same address so soon after it was last canvassed.\n\nThis address was last canvassed \(timeSince).")
                            
                            dispatch_async(dispatch_get_main_queue(),
                                {
                                    self.presentViewController(alert, animated: true, completion: nil)
                                    self.submitButton.enabled = true
                                    
                                })
                            
                            return
                        }
                    }
                    
                    self.performSegueWithIdentifier("SubmitAddress", sender: self)
                } else {
                    if let error = error {
                        let errorTitle = error.errorTitle
                        let errorMessage = error.errorDescription
                        
                        dispatch_async(dispatch_get_main_queue(),
                            {
                        self.finishedSubmittingWithError(errorTitle, errorMessage: errorMessage)
                        })
                    }
                }
            })
        }
    }
    
    func submitForm() {

        if (streetAddress.text != "") {
            if !locationUpdated {
                forwardGeocodeBasedOnTextField({ (success, errorTitle, errorMessage) -> Void in
                    if(success)
                    {
                        self.processAndSubmitForm()
                    }
                    else
                    {
                        if(errorTitle != nil && errorMessage != nil)
                        {
                            self.finishedSubmittingWithError(errorTitle!, errorMessage: errorMessage!)
                        }
                    }
                })

            }
            else
            {
                self.processAndSubmitForm()
            }
            
           
        }
    }


}
