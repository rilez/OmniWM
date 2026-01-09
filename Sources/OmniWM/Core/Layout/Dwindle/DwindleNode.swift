import Foundation
import CoreGraphics
import QuartzCore

typealias DwindleNodeId = UUID

enum DwindleOrientation: Equatable, Codable {
    case horizontal
    case vertical

    var perpendicular: DwindleOrientation {
        switch self {
        case .horizontal: .vertical
        case .vertical: .horizontal
        }
    }
}

extension Direction {
    var dwindleOrientation: DwindleOrientation {
        switch self {
        case .left, .right: .horizontal
        case .up, .down: .vertical
        }
    }

    var opposite: Direction {
        switch self {
        case .left: .right
        case .right: .left
        case .up: .down
        case .down: .up
        }
    }

    var isPositive: Bool {
        switch self {
        case .right, .up: true
        case .left, .down: false
        }
    }
}

enum DwindleNodeKind {
    case split(orientation: DwindleOrientation, ratio: CGFloat)
    case leaf(handle: WindowHandle?, fullscreen: Bool)
}

final class DwindleNode {
    let id: DwindleNodeId
    weak var parent: DwindleNode?
    var children: [DwindleNode] = []
    var kind: DwindleNodeKind
    var cachedFrame: CGRect?

    var moveXAnimation: MoveAnimation?
    var moveYAnimation: MoveAnimation?

    init(kind: DwindleNodeKind) {
        id = UUID()
        self.kind = kind
    }

    var isLeaf: Bool {
        if case .leaf = kind { return true }
        return false
    }

    var isSplit: Bool {
        if case .split = kind { return true }
        return false
    }

    var windowHandle: WindowHandle? {
        if case let .leaf(handle, _) = kind { return handle }
        return nil
    }

    var isFullscreen: Bool {
        if case let .leaf(_, fullscreen) = kind { return fullscreen }
        return false
    }

    var splitOrientation: DwindleOrientation? {
        if case let .split(orientation, _) = kind { return orientation }
        return nil
    }

    var splitRatio: CGFloat? {
        if case let .split(_, ratio) = kind { return ratio }
        return nil
    }

    func firstChild() -> DwindleNode? { children.first }
    func secondChild() -> DwindleNode? { children.count > 1 ? children[1] : nil }

    func detach() {
        parent?.children.removeAll { $0.id == self.id }
        parent = nil
    }

    func appendChild(_ child: DwindleNode) {
        child.detach()
        child.parent = self
        children.append(child)
    }

    func insertChild(_ child: DwindleNode, at index: Int) {
        child.detach()
        child.parent = self
        children.insert(child, at: min(index, children.count))
    }

    func replaceChildren(first: DwindleNode, second: DwindleNode) {
        for child in children {
            child.parent = nil
        }
        children.removeAll()
        first.parent = self
        second.parent = self
        children = [first, second]
    }

    func descendToFirstLeaf() -> DwindleNode {
        var node = self
        while let first = node.firstChild() {
            node = first
        }
        return node
    }

    func descendToLastLeaf() -> DwindleNode {
        var node = self
        while let child = node.children.last {
            node = child
        }
        return node
    }

    func isFirstChild(of parent: DwindleNode) -> Bool {
        parent.firstChild()?.id == id
    }

    func isSecondChild(of parent: DwindleNode) -> Bool {
        parent.secondChild()?.id == id
    }

    func sibling() -> DwindleNode? {
        guard let parent else { return nil }
        if isFirstChild(of: parent) {
            return parent.secondChild()
        } else {
            return parent.firstChild()
        }
    }

    func insertBefore(_ sibling: DwindleNode) {
        guard let parent = sibling.parent,
              let index = parent.children.firstIndex(where: { $0.id == sibling.id }) else { return }
        self.detach()
        self.parent = parent
        parent.children.insert(self, at: index)
    }

    func insertAfter(_ sibling: DwindleNode) {
        guard let parent = sibling.parent,
              let index = parent.children.firstIndex(where: { $0.id == sibling.id }) else { return }
        self.detach()
        self.parent = parent
        parent.children.insert(self, at: index + 1)
    }

    func collectAllLeaves() -> [DwindleNode] {
        var result: [DwindleNode] = []
        collectLeavesRecursive(into: &result)
        return result
    }

    private func collectLeavesRecursive(into result: inout [DwindleNode]) {
        if isLeaf {
            result.append(self)
        } else {
            for child in children {
                child.collectLeavesRecursive(into: &result)
            }
        }
    }

    func collectAllWindows() -> [WindowHandle] {
        collectAllLeaves().compactMap { $0.windowHandle }
    }

    func animateFrom(oldFrame: CGRect, newFrame: CGRect, clock: AnimationClock?, config: SpringConfig) {
        let now = clock?.now() ?? CACurrentMediaTime()

        let displacementX = oldFrame.origin.x - newFrame.origin.x
        let displacementY = oldFrame.origin.y - newFrame.origin.y

        if abs(displacementX) > 0.5 {
            let anim = SpringAnimation(
                from: 1.0,
                to: 0.0,
                startTime: now,
                config: config,
                clock: clock
            )
            moveXAnimation = MoveAnimation(animation: anim, fromOffset: displacementX)
        }

        if abs(displacementY) > 0.5 {
            let anim = SpringAnimation(
                from: 1.0,
                to: 0.0,
                startTime: now,
                config: config,
                clock: clock
            )
            moveYAnimation = MoveAnimation(animation: anim, fromOffset: displacementY)
        }
    }

    func renderOffset(at time: TimeInterval) -> CGPoint {
        CGPoint(
            x: moveXAnimation?.currentOffset(at: time) ?? 0,
            y: moveYAnimation?.currentOffset(at: time) ?? 0
        )
    }

    func tickAnimations(at time: TimeInterval) {
        if let anim = moveXAnimation, anim.isComplete(at: time) {
            moveXAnimation = nil
        }
        if let anim = moveYAnimation, anim.isComplete(at: time) {
            moveYAnimation = nil
        }
    }

    func hasActiveAnimations(at time: TimeInterval) -> Bool {
        if let anim = moveXAnimation, !anim.isComplete(at: time) { return true }
        if let anim = moveYAnimation, !anim.isComplete(at: time) { return true }
        return false
    }
}
