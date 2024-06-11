//
//  DragDropManager.swift
//  DragAndDropManagerMain
//
//  Created by Pedro Ésli on 21/02/22.
//

import SwiftUI

/// Observable class responsible for maintaining the positions of all `DropView` and `DragView` views and checking if it is possible to drop
class DragDropManager: ObservableObject {

    @Published var droppedId: UUID? = nil
    @Published var currentDraggingId: UUID? = nil
    @Published var currentDraggingOffset: CGSize? = nil

    @Published var currentDraggingViewCollidesWithDropId: UUID? = nil

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
    ///     - dragId: The id of the view to drag.
    ///     - frame: The frame of the drag view.
    func add(dragId: UUID, frame: CGRect) {
        dragViewsMap.emplaceRef(forKey: dragId, value: frame)
    }

    /// Update frame for the given `DragView`, eg when view geometry changes.
    ///
    /// - Parameters:
    ///     - dragId: The id of the view to drag.
    ///     - frame: The frame of the drag view.
    func update(dragId: UUID, frame: CGRect) {
        dragViewsMap.updateValue(frame, forKey: dragId)
    }

    /// Deregister a `DragView`.
    ///
    /// - Parameters:
    ///     - dragId: The id of the view to drag.
    ///
    /// NB: When the same UUID is reused (eg., a `DragView` is created after dropping a view
    /// on the drop target), `addFor(drag:frame:)` is called before `remove(dragViewId:)`,
    /// resulting in the view ID not registering. To avoid this, internally we keep track of
    /// the times `addFor(drag:frame:)` and `remove(dragViewId:)` were called.
    func remove(dragId: UUID) {
        dragViewsMap.removeRef(forKey: dragId)
    }

    /// Register a new `DropView` to the drop list map.
    ///
    /// - Parameters:
    ///     - dropId: The id of the drop view.
    ///     - frame: The frame of the drag view.
    ///     - canRecieveAnyDragView: Can this drop view recieve any drag view.
    func add(dropId: UUID, frame: CGRect, canRecieveAnyDragView: Bool) {
        if canRecieveAnyDragView {
            otherDropViewsMap.emplaceRef(forKey: dropId, value: frame)
        } else {
            dropViewsMap.emplaceRef(forKey: dropId, value: frame)
        }
    }

    /// Update frame for the given `DropView`, eg when view geometry changes.
    ///
    /// - Parameters:
    ///     - dropId: The id of the drop view.
    ///     - frame: The frame of the drag view.
    ///     - canRecieveAnyDragView: Can this drop view recieve any drag view.
    func update(dropId: UUID, frame: CGRect, canRecieveAnyDragView: Bool) {
        if canRecieveAnyDragView {
            otherDropViewsMap.updateValue(frame, forKey: dropId)
        } else {
            dropViewsMap.updateValue(frame, forKey: dropId)
        }
    }

    /// Deregister a new `DropView` to the drop list map.
    ///
    /// - Parameters:
    ///     - dropId: The id of the drop view.
    ///
    /// NB: When the same UUID is reused (eg., a `DropView` is created after dropping a view
    /// on the drop target), `addFor(drop: ...)` is called before `remove(dropViewId:)`,
    /// resulting in the view ID not registering. To avoid this, internally we keep track of
    /// the times `addFor(drop: ...)` and `remove(dropViewId:)` were called.
    func remove(dropId: UUID) {
        dropViewsMap.removeRef(forKey: dropId)
        otherDropViewsMap.removeRef(forKey: dropId)
    }

    /// Keeps track of the current dragging view id and offset
    ///
    /// - Parameters:
    ///     - dragId: The id of the drag view.
    ///     - frame: The offset of the dragging view.
    func report(dragId: UUID, offset: CGSize) {
        currentDraggingId = dragId
        currentDraggingOffset = offset

        updateCollisionState()
    }

    /// Check if the current dragging view is colliding with the current provided id of drop view
    ///
    /// - Parameter id: The id of the drop view to check if its colliding
    ///
    /// - Returns: `True` if the dragging  view is colliding with the current drop view.
    func isColliding(dropId: UUID) -> Bool {
        return currentDraggingViewCollidesWithDropId == dropId
    }

    /// Check if the current dragging view is colliding.
    ///
    /// - Returns: `True` if the dragging view is colliding
    func isColliding(dragId: UUID) -> Bool {
        return dragId == currentDraggingId && currentDraggingViewCollidesWithDropId != nil
    }

    /// Checks if it is possible to drop a `DragView` in a certain position where theres a `DropView`.
    ///
    /// - Parameters:
    ///     - id: The id of the drag view from which to drop.
    ///     - offset: The current offset of the view you are dragging.
    ///
    /// - Returns: `True` if the view can be dropped at the position.
    func canDrop(dragId: UUID) -> Bool {
        return isColliding(dragId: dragId)
    }

    /// Tells that the current `DragView` will be dropped;
    func drop(dragId: UUID) {
        guard isColliding(dragId: dragId) else {
            droppedId = nil
            return
        }

        droppedId = currentDraggingViewCollidesWithDropId
    }

    /// Pre-calculate the potential drop target view id based on overlapping frames of the drop
    /// targets and the current dragging view frame.
    ///
    /// Sets `self.currentDraggingViewCollidesWithDropViewId` to the potential drop target view id.
    private func updateCollisionState() {
        if let currentDraggingOffset,
           let currentDraggingId,
           let dragRect = dragViewsMap[currentDraggingId]?.value
        {
            let currentDraggingViewFrame = dragRect.offsetBy(
                dx: currentDraggingOffset.width,
                dy: currentDraggingOffset.height)
            let currentDraggingViewMidPoint = CGPoint(
                x: currentDraggingViewFrame.midX,
                y: currentDraggingViewFrame.midY)

            // Check views that can only accept specific viewId first.
            if let dropRect = dropViewsMap[currentDraggingId]?.value {
                if dropRect.intersects(currentDraggingViewFrame) {
                    currentDraggingViewCollidesWithDropId = currentDraggingId
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
                currentDraggingViewCollidesWithDropId = closestDropView.0
                return
            }
        }

        currentDraggingViewCollidesWithDropId = nil
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

  mutating func updateValue<T>(_ value: T, forKey key: Key) where Value == DragDropManager.RefCounted<T> {
      if var ref = self[key] {
          ref.value = value
          self[key] = ref
      }
  }
}
