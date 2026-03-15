//
//  KlunaBundle.swift
//  Kluna
//
//  Created by Tim von Sachs on 10.03.26.
//

import WidgetKit
import SwiftUI

@main
struct KlunaBundle: WidgetBundle {
    var body: some Widget {
        Kluna()
        KlunaControl()
        KlunaLiveActivity()
    }
}
