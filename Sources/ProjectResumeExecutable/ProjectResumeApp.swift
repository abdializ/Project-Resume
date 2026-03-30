import SwiftUI
import ProjectResumeKit

@main
struct ProjectResumeApp: App {
    @NSApplicationDelegateAdaptor(ProjectResumeAppDelegate.self) private var appDelegate

    var body: some Scene {
        ProjectResumeScenes()
    }
}
