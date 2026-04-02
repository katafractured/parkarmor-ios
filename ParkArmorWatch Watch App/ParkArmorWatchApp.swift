//
//  ParkArmorWatchApp.swift
//  ParkArmorWatch Watch App
//
//  Created by Christian Flores on 3/25/26.
//

import SwiftUI

@main
struct ParkArmorWatchApp: App {
    @State private var watchViewModel = WatchViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(watchViewModel)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        watchViewModel.syncNow()
                    }
                }
        }
    }
}
