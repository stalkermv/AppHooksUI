#if os(iOS)
import UIKit
public typealias PlatformApplication = UIKit.UIApplication
#elseif os(macOS)
import AppKit
public typealias PlatformApplication = NSApplication
#else
#error("AppHooksModules is published for iOS and macOS in this release.")
#endif
