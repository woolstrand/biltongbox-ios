import Foundation

struct AlertAction {
    var title: String
    var action: (() -> Void)?
}

struct AlertData: Identifiable {
    var title: String
    var message: String
    var actions: [AlertAction]
    
    var id = UUID()
}
