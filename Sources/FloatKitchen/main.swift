import AppKit

let application = NSApplication.shared
let controller = KitchenController()
application.delegate = controller
application.setActivationPolicy(.accessory)
application.run()
