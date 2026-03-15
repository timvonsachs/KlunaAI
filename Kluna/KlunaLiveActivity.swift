//
//  KlunaLiveActivity.swift
//  Kluna
//
//  Created by Tim von Sachs on 10.03.26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct KlunaAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct KlunaLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: KlunaAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension KlunaAttributes {
    fileprivate static var preview: KlunaAttributes {
        KlunaAttributes(name: "World")
    }
}

extension KlunaAttributes.ContentState {
    fileprivate static var smiley: KlunaAttributes.ContentState {
        KlunaAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: KlunaAttributes.ContentState {
         KlunaAttributes.ContentState(emoji: "🤩")
     }
}

// Intentionally no #Preview macro here to keep CI/xcodebuild compatible
// in environments where preview macro plugins are unavailable.
