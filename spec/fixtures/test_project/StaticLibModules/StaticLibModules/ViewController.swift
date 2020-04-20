//
//  ViewController.swift
//  StaticLibModules
//
//  Created by Ilya Dyakonov on 4/7/20.
//  Copyright © 2020 xcode-archive-cache. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet var reportedClassNameLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        reportedClassNameLabel.text = ClassNameReporter.reportedClassName()
    }
}

