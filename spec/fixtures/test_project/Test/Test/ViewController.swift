//
//  ViewController.swift
//  Test
//
//  Created by Ilya Dyakonov on 5/20/19.
//  Copyright © 2019 xcode-archive-cache. All rights reserved.
//

import UIKit
import SDCAlertView

class ViewController: UIViewController {
    @IBOutlet weak var frameworkLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        frameworkLabel.text = StaticDependency().libraryWithFrameworkDependencyDescription()
        checkMidtransBundleContents()
    }
    
    fileprivate static let expectedJSONValue = "cimb"
    
    fileprivate func checkMidtransBundleContents() {
        do {
            let bundlePath = Bundle.main.path(forResource: "MidtransKit", ofType: "bundle")!
            let jsonPath = Bundle(path: bundlePath)!.path(forResource: "bin", ofType: "json")!
            let jsonData = try Data(contentsOf: URL.init(fileURLWithPath: jsonPath))
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as! Array<Dictionary<String, Any>>
            let valueToCheck = jsonObject.first!["bank"] as! String
            if valueToCheck != ViewController.expectedJSONValue {
                fatalError("Value from bundled JSON is wrong: \(valueToCheck) != \(ViewController.expectedJSONValue)")
            }
        }
        catch {
            fatalError("Failed to read bundled JSON: \(error.localizedDescription)")
        }
    }
    
    @IBAction func tapMeTapped(_ sender: Any) {
        SDCAlertView.alert(withTitle: "Test", message: "All good", buttons: ["OK"])
    }
}
