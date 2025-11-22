import Foundation
import Tesseract

/// Progress/cancel monitor wrapper for long-running recognition.
public final class TessMonitor {
    public private(set) var pointer: OpaquePointer?

    private final class CallbackBox {
        var cancel: (@Sendable (Int32) -> Bool)?
        var progress: (@Sendable (_ left: Int32, _ right: Int32, _ top: Int32, _ bottom: Int32) -> Bool)?
    }

    private let callbacks = CallbackBox()

    public init?() {
        guard let monitor = TessMonitorCreate() else { return nil }
        pointer = monitor
    }

    deinit {
        if let pointer {
            TessMonitorSetCancelThis(pointer, nil)
            TessMonitorDelete(pointer)
        }
    }

    /// Called with word count; return false to cancel.
    public func setCancelHandler(_ handler: @escaping @Sendable (Int32) -> Bool) {
        callbacks.cancel = handler
        guard let pointer else { return }
        TessMonitorSetCancelThis(pointer, Unmanaged.passUnretained(callbacks).toOpaque())
        TessMonitorSetCancelFunc(pointer, TessMonitor.cancelThunk)
    }

    /// Called with pixel bounds; return false to cancel.
    public func setProgressHandler(_ handler: @escaping @Sendable (_ left: Int32, _ right: Int32, _ top: Int32, _ bottom: Int32) -> Bool) {
        callbacks.progress = handler
        guard let pointer else { return }
        TessMonitorSetCancelThis(pointer, Unmanaged.passUnretained(callbacks).toOpaque())
        TessMonitorSetProgressFunc(pointer, TessMonitor.progressThunk)
    }

    /// Remove configured callbacks.
    public func clearHandlers() {
        callbacks.cancel = nil
        callbacks.progress = nil
        guard let pointer else { return }
        TessMonitorSetCancelFunc(pointer, nil)
        TessMonitorSetProgressFunc(pointer, nil)
        TessMonitorSetCancelThis(pointer, nil)
    }

    public var progress: Int32 {
        guard let pointer else { return 0 }
        return TessMonitorGetProgress(pointer)
    }

    public func setDeadline(milliseconds: Int32) {
        guard let pointer else { return }
        TessMonitorSetDeadlineMSecs(pointer, milliseconds)
    }

    private static let cancelThunk: TessCancelFunc = { rawContext, words in
        guard let rawContext else { return false }
        let callbacks = Unmanaged<CallbackBox>.fromOpaque(rawContext).takeUnretainedValue()
        return callbacks.cancel?(Int32(words)) ?? false
    }

    private static let progressThunk: TessProgressFunc = { monitor, left, right, top, bottom in
        guard let monitor else { return false }
        guard let rawContext = TessMonitorGetCancelThis(monitor) else { return false }
        let callbacks = Unmanaged<CallbackBox>.fromOpaque(rawContext).takeUnretainedValue()
        return callbacks.progress?(left, right, top, bottom) ?? false
    }
}
