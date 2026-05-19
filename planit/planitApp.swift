//
//  planitApp.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/6/26.
//

import SwiftUI

@main
struct planitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .tint(.accentColor)
        }
    }
}
