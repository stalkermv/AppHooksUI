#if os(iOS) || os(tvOS)
import UIKit
public typealias UIApplication = UIKit.UIApplication
#elseif os(macOS)
import AppKit
public typealias UIApplication = NSApplication
#elseif os(watchOS)
import WatchKit
public typealias UIApplication = WKExtension
#else
/// Placeholder type that allows the module to compile on unsupported platforms.
public struct UIApplication { }
#endif
