//
//  Dependency.swift
//  Dependency
//
//  Created by Ilya Dyakonov on 7/29/20.
//  Copyright © 2020 xcode-archive-test. All rights reserved.
//

import KeychainAccess

public final class Dependency {
    public init() {
        let _ = Keychain()
    }
}
