import Foundation
import QuartzCore

struct AnimationSnapshot {
    let workspaceId: WorkspaceDescriptor.ID
    let targetFrames: [WindowHandle: CGRect]
    let targetViewportOffset: CGFloat
    let workingFrame: CGRect
    let hiddenHandles: Set<WindowHandle>
    let orientation: Monitor.Orientation

    func interpolatedFrame(
        for handle: WindowHandle,
        currentViewportOffset: CGFloat,
        moveOffset: CGPoint
    ) -> CGRect? {
        guard let targetFrame = targetFrames[handle] else { return nil }

        let viewportDelta = currentViewportOffset - targetViewportOffset

        var frame = targetFrame
        switch orientation {
        case .horizontal:
            frame.origin.x += viewportDelta + moveOffset.x
            frame.origin.y += moveOffset.y
        case .vertical:
            frame.origin.x += moveOffset.x
            frame.origin.y += viewportDelta + moveOffset.y
        }

        return frame
    }

    func isWindowVisible(_ handle: WindowHandle) -> Bool {
        !hiddenHandles.contains(handle)
    }
}
