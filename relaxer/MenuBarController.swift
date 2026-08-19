import AppKit
import SwiftUI

enum MenuBarIconRenderer {
    private struct CacheKey: Hashable {
        let level: Int
        let scale: CGFloat
    }

    private static var cache: [CacheKey: NSImage] = [:]

    @MainActor
    static func image(level: Int) -> NSImage {
        let clamped = min(max(level, 0), 10)
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let key = CacheKey(level: clamped, scale: scale)

        if let cached = cache[key] {
            return cached
        }

        let view = LeafMenuBarIcon(level: clamped)
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale

        guard let image = renderer.nsImage else {
            return NSImage(systemSymbolName: "leaf", accessibilityDescription: "Relaxer") ?? NSImage()
        }
        image.isTemplate = true
        cache[key] = image
        return image
    }
}

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let monitor: TimerMonitor
    private let popover: NSPopover
    private var isObservingProgress = false

    init(monitor: TimerMonitor) {
        self.monitor = monitor
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        super.init()

        let hostingController = NSHostingController(rootView: MenuBarContent(monitor: monitor))
        popover.contentSize = NSSize(width: 240, height: 220)
        popover.behavior = .transient
        popover.contentViewController = hostingController

        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        isObservingProgress = true
        observeProgress()
    }

    func stop() {
        isObservingProgress = false
        if popover.isShown {
            popover.performClose(nil)
        }
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func observeProgress() {
        guard isObservingProgress else { return }
        withObservationTracking {
            updateIcon()
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeProgress()
            }
        }
    }

    private func updateIcon() {
        statusItem.button?.image = MenuBarIconRenderer.image(level: monitor.progressFillLevel)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
            return
        }

        updateIcon()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}
