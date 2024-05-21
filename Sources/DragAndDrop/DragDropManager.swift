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

    private var dragViewsMap: [UUID: CGRect] = [:]
    private var dropViewsMap: [UUID: CGRect] = [:]
    private var otherDropViewsMap: [UUID: CGRect] = [:]

    /// Register a new `DragView` to the drag list map.
    ///
    /// - Parameters:
    ///     - id: The id of the view to drag.
    ///     - frame: The frame of the drag view.
    func addFor(drag id: UUID, frame: CGRect) {
        dragViewsMap[id] = frame
    }

    /// Register a new `DropView` to the drop list map.
    ///
    /// - Parameters:
    ///     - id: The id of the drop view.
    ///     - frame: The frame of the drag view.
    ///     - canRecieveAnyDragView: Can this drop view recieve any drag view.
    func addFor(drop id: UUID, frame: CGRect, canRecieveAnyDragView: Bool) {
        if canRecieveAnyDragView {
            otherDropViewsMap[id] = frame
            return
        }
        dropViewsMap[id] = frame
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
           let dragRect = dragViewsMap[currentDraggingViewID]
        {
            let currentDraggingViewFrame = dragRect.offsetBy(
                dx: currentDraggingOffset.width,
                dy: currentDraggingOffset.height)
            let currentDraggingViewMidPoint = CGPoint(
                x: currentDraggingViewFrame.midX,
                y: currentDraggingViewFrame.midY)

            // Check views that can only accept specific viewId first.
            if let dropRect = dropViewsMap[currentDraggingViewID] {
                if dropRect.intersects(currentDraggingViewFrame) {
                    currentDraggingViewCollidesWithDropViewId = currentDraggingViewID
                    return
                }
            }

            // Check views that can accept any viewId - select the closest.
            let closestDropView = otherDropViewsMap
                .filter { dropId, dropRect in
                    // Only consider views that intersect with the current dragging view
                    return dropRect.intersects(currentDraggingViewFrame)
                }
                .map { key, rect in
                    // Compute the distance between centers of the dragging view and centers of the overlapping drop views
                    let midPoint = CGPoint(x: rect.midX, y: rect.midY)
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
