//
//  DropView.swift
//  DragAndDropManagerMain
//
//  Created by Pedro Ésli on 21/02/22.
//

import SwiftUI

public struct DropInfo {
    public let didDrop: Bool
    public let isColliding: Bool
}

/// A drop view that needs to be inside a `InteractiveDragDropContainer` to work properly.
public struct DropView<Content>: View where Content: View {
    
    @EnvironmentObject private var manager: DragDropManager
    @State private var isDropped = false
    @State private var elementId: UUID
    private var canRecieveAnyDragView = false
    private let content: (_ dragInfo: DropInfo) -> Content
    private var receivedAction: ((_ receivingID: UUID) -> Void)?
    
    /// Initializer for the drop view that uses the id of the receiving drag view.
    ///
    /// - Parameters:
    ///     - id: The id of the drop view which this drop view will be able to accept. If set nil, the DropView will recieve any DragView.
    ///     - content: The view and area that will be able to be dropped.
    public init(receiveFrom id: UUID? = nil, @ViewBuilder content: @escaping (DropInfo) -> Content) {
        if let id = id {
            self.elementId = id
        } else {
            self.elementId = UUID()
            canRecieveAnyDragView = true
        }
        self.content = content
    }

    public var body: some View {
        content(DropInfo(didDrop: isDropped, isColliding: manager.isColliding(dropId: elementId)))
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            self.manager.add(dropId: elementId, frame: geometry.frame(in: .dragAndDrop), canRecieveAnyDragView: canRecieveAnyDragView)
                        }
                        .onChange(of: geometry.frame(in: .dragAndDrop)) { newValue in
                            self.manager.update(dropId: elementId, frame: newValue, canRecieveAnyDragView: canRecieveAnyDragView)
                        }
                        .onDisappear {
                            self.manager.remove(dropId: elementId)
                        }
                }
            }
            .onChange(of: manager.droppedId) { newValue in
                if newValue == elementId {
                    isDropped = true
                    if let dragId = manager.currentDraggingId {
                        receivedAction?(dragId)
                    }
                }
            }
    }
    
    /// Adds and action to perform when this `DropView` receives a `DragView`.
    ///
    /// - Parameter action: An action when this `DropView` has received its `DragView`. Also informs the id of the `DragView`.
    ///
    /// - Returns: A DropView with an action trigger.
    public func onDragViewReceived(action: @escaping (UUID) -> Void) -> DropView {
        var new = self
        new.receivedAction = action
        return new
    }
}
