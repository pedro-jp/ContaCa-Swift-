//
//  FormaWidgetsBundle.swift
//  FormaWidgets
//
//  Created by João Pedro on 10/29/26.
//

import WidgetKit
import SwiftUI

@main
struct FormaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        FormaCalorieWidget()
        FormaWaterWidget()
        WorkoutLiveActivity()
    }
}
