//
//  DragDropManager.swift
//  DragAndDropManagerMain
//
//  Created by Pedro Ésli on 21/02/22.
//

import SwiftUI

/// Observable class responsible for maintaining the positions of all `DropView` and `DragView` views and checking if it is possible to drop
class DragDropManager: ObservableObject {

    @Published var droppedViewID: UUID? = nil
    @Published var currentDraggingViewID: UUID? = nil
    @Published var currentDraggingOffset: CGSize? = nil

    @Published var currentDraggingViewCollidesWithDropViewId: UUID? = nil

    fileprivate struct RefCounted<T> {
        typealias T = T

        var count: Int
        var value: T

        init(count: Int, value: T) {
            self.count = count
            self.value = value
        }
    }
    private var dragViewsMap: [UUID: RefCounted<CGRect>] = [:]
    private var dropViewsMap: [UUID: RefCounted<CGRect>] = [:]
    private var otherDropViewsMap: [UUID: RefCounted<CGRect>] = [:]

    /// Register a new `DragView` to the drag list map.
    ///
    /// - Parameters:
    ///     - id: The id of the view to drag.
    ///     - frame: The frame of the drag view.
    func addFor(drag id: UUID, frame: CGRect) {
        dragViewsMap.emplaceRef(forKey: id, value: frame)
    }

    /// Deregister a `DragView`.
    ///
    /// - Parameters:
    ///     - dragViewId: The id of the view to drag.
    ///
    /// NB: When the same UUID is reused (eg., a `DragView` is created after dropping a view
    /// on the drop target), `addFor(drag:frame:)` is called before `remove(dragViewId:)`,
    /// resulting in the view ID not registering. To avoid this, internally we keep track of
    /// the times `addFor(drag:frame:)` and `remove(dragViewId:)` were called.
    func remove(dragViewId: UUID) {
        dragViewsMap.removeRef(forKey: dragViewId)
    }

    /// Register a new `DropView` to the drop list map.
    ///
    /// - Parameters:
    ///     - id: The id of the drop view.
    ///     - frame: The frame of the drag view.
    ///     - canRecieveAnyDragView: Can this drop view recieve any drag view.
    func addFor(drop id: UUID, frame: CGRect, canRecieveAnyDragView: Bool) {
        if canRecieveAnyDragView {
            otherDropViewsMap.emplaceRef(forKey: id, value: frame)
        } else {
            dropViewsMap.emplaceRef(forKey: id, value: frame)
        }
    }

    /// Deregister a new `DropView` to the drop list map.
    ///
    /// - Parameters:
    ///     - dropViewId: The id of the drop view.
    ///
    /// NB: When the same UUID is reused (eg., a `DropView` is created after dropping a view
    /// on the drop target), `addFor(drop: ...)` is called before `remove(dropViewId:)`,
    /// resulting in the view ID not registering. To avoid this, internally we keep track of
    /// the times `addFor(drop: ...)` and `remove(dropViewId:)` were called.
    func remove(dropViewId: UUID) {
        dropViewsMap.removeRef(forKey: dropViewId)
        otherDropViewsMap.removeRef(forKey: dropViewId)
    }

    /// Keeps track of the current dragging view id and offset
    ///
    /// - Parameters:
    ///     - id: The id of the drag view.
    ///     - frame: The offset of the dragging view.
    func report(drag id: UUID, offset: CGSize) {
        currentDraggingViewID = id
        currentDraggingOffset = offset

        updateCollisionState()
    }

    /// Check if the current dragging view is colliding with the current provided id of drop view
    ///
    /// - Parameter id: The id of the drop view to check if its colliding
    ///
    /// - Returns: `True` if the dragging  view is colliding with the current drop view.
    func isColliding(dropId: UUID) -> Bool {
        return currentDraggingViewCollidesWithDropViewId == dropId
    }

    /// Check if the current dragging view is colliding.
    ///
    /// - Returns: `True` if the dragging view is colliding
    func isColliding(dragId: UUID) -> Bool {
        return dragId == currentDraggingViewID && currentDraggingViewCollidesWithDropViewId != nil
    }

    /// Checks if it is possible to drop a `DragView` in a certain position where theres a `DropView`.
    ///
    /// - Parameters:
    ///     - id: The id of the drag view from which to drop.
    ///     - offset: The current offset of the view you are dragging.
    ///
    /// - Returns: `True` if the view can be dropped at the position.
    func canDrop(id: UUID) -> Bool {
        return isColliding(dragId: id)
    }

    /// Tells that the current `DragView` will be dropped;
    func dropDragView(of id: UUID) {
        guard isColliding(dragId: id) else {
            droppedViewID = nil
            return
        }

        droppedViewID = currentDraggingViewCollidesWithDropViewId
    }

    /// Pre-calculate the potential drop target view id based on overlapping frames of the drop
    /// targets and the current dragging view frame.
    ///
    /// Sets `self.currentDraggingViewCollidesWithDropViewId` to the potential drop target view id.
    private func updateCollisionState() {
        if let currentDraggingOffset,
           let currentDraggingViewID,
           let dragRect = dragViewsMap[currentDraggingViewID]?.value
        {
            let currentDraggingViewFrame = dragRect.offsetBy(
                dx: currentDraggingOffset.width,
                dy: currentDraggingOffset.height)
            let currentDraggingViewMidPoint = CGPoint(
                x: currentDraggingViewFrame.midX,
                y: currentDraggingViewFrame.midY)

            // Check views that can only accept specific viewId first.
            if let dropRect = dropViewsMap[currentDraggingViewID]?.value {
                if dropRect.intersects(currentDraggingViewFrame) {
                    currentDraggingViewCollidesWithDropViewId = currentDraggingViewID
                    return
                }
            }

            // Check views that can accept any viewId - select the closest.
            let closestDropView = otherDropViewsMap
                .filter { dropId, dropRect in
                    // Only consider views that intersect with the current dragging view
                  return dropRect.value.intersects(currentDraggingViewFrame)
                }
                .map { key, rect in
                    // Compute the distance between centers of the dragging view and centers of the overlapping drop views
                  let midPoint = CGPoint(x: rect.value.midX, y: rect.value.midY)
                    let distance = sqrt(sqr(midPoint.x - currentDraggingViewMidPoint.x) + sqr(midPoint.y - currentDraggingViewMidPoint.y))
                    return (key, distance)
                }
                .min { lhs, rhs in
                    // Choose the drop view which is closest to the dragging view
                    let (_, d1) = lhs
                    let (_, d2) = rhs
                    return d1 < d2
                }

            if let closestDropView {
                currentDraggingViewCollidesWithDropViewId = closestDropView.0
                return
            }
        }

        currentDraggingViewCollidesWithDropViewId = nil
    }
}

/// Compute the square of the argument.
private func sqr(_ a: Double) -> Double {
    return a * a
}

fileprivate extension Dictionary {
    mutating func emplaceRef<T>(forKey key: Key, value: T) where Value == DragDropManager.RefCounted<T> {
        if var ref = self[key] {
            ref.count += 1
            ref.value = value
            self[key] = ref
        } else {
            self[key] = .init(count: 1, value: value)
        }
    }

    mutating func removeRef<T>(forKey key: Key) where Value == DragDropManager.RefCounted<T> {
        guard var ref = self[key] else { return }
        if ref.count > 1 {
            ref.count -= 1
            self[key] = ref
        } else {
            self.removeValue(forKey: key)
        }
    }
}
