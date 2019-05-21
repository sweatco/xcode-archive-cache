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
    }
    
    @IBAction func tapMeTapped(_ sender: Any) {
        SDCAlertView.alert(withTitle: "Test", message: "All good", buttons: ["OK"])
    }
}
