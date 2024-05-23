//
//  DragView.swift
//  DragAndDropManagerMain
//
//  Created by Pedro Ésli on 21/02/22.
//

import SwiftUI

public struct DragInfo {
    public let didDrop: Bool
    public let isDragging: Bool
    public let isColliding: Bool
}

/// A draging view that needs to be inside a `InteractiveDragDropContainer` to work properly.
public struct DragView<Content, DragContent>: View where Content: View, DragContent: View{
    public typealias ContentType = (_ isDraging: Bool) -> Content
    public typealias DragContentType = (_ dragInfo: DragInfo) -> DragContent

    @EnvironmentObject private var manager: DragDropManager
    
    @State private var dragOffset: CGSize = CGSize.zero
    @State private var position: CGPoint = CGPoint.zero
    @State private var isDragging = false
    @State private var isDroped = false
    
    private let content: ContentType
    private var dragContent: DragContentType
    private var dragginStoppedAction: ((_ isSuccessfullDrop: Bool) -> Void)?
    private let elementID: UUID
    private var translationAdjustment: ((DragGesture.Value) -> (CGSize))?

    /// Initialize this view with its unique ID and custom view.
    ///
    /// - Parameters:
    ///     - id: The unique id of this view.
    ///     - content: The custom content of this view and what will be dragged.
    public init(id: UUID, @ViewBuilder content: @escaping ContentType) where DragContent == Content {
        self.elementID = id
        self.content = content
        self.dragContent = { _ in
            content(false)
        }
    }
    
    /// Initialize this view with its unique ID and custom view.
    ///
    /// - Parameters:
    ///     - id: The unique id of this view.
    ///     - content: The custom content of this view.
    ///     - dragContent: A custom content for the dragging view.
    public init(id: UUID, @ViewBuilder content: @escaping ContentType, @ViewBuilder dragContent: @escaping DragContentType) {
        self.elementID = id
        self.content = content
        self.dragContent = dragContent
    }
    
    public var body: some View {
        ZStack {
            dragContent(DragInfo(didDrop: isDroped, isDragging: isDragging, isColliding: manager.isColliding(dragId: elementID)))
                .offset(dragOffset)
                .zIndex(isDragging ? 1 : 0)
            content(isDragging)
                .background {
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                self.manager.addFor(drag: elementID, frame: geometry.frame(in: .dragAndDrop))
                            }
                            .onDisappear {
                                self.manager.remove(dragViewId: elementID)
                            }
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            withAnimation(.interactiveSpring()) {
                                dragOffset = adjustedTranslationWhileDragging(value)
                            }
                        }
                        .simultaneously(with:
                            DragGesture(coordinateSpace: .dragAndDrop)
                                .onChanged(onDragChanged(_:))
                                .onEnded(onDragEnded(_:))
                        )
                )
        }
        .zIndex(isDragging ? 1 : 0)
    }
    
    /// An action indicating if the user has stopped dragging this view and indicates if it has dropped succesfuly on a `DropView` or not.
    ///
    /// - Parameter action: An action that will happen after the user has stopped dragging. (Also tell if it has dropped or not on a `DropView`) .
    ///
    /// - Returns: A DragView with a dragging ended action trigger.
    public func onDraggingEnded(action: @escaping (Bool) -> Void) -> DragView {
        var new = self
        new.dragginStoppedAction = action
        return new
    }

    /// Set an optional closure to calculate the adjustment to the position of the view,
    /// eg when we want the view to be visible above the finger while dragging.
    ///
    /// - Parameter adjustment: A closure that can take startLocation of the touch,
    ///     to calculate the adjustment.
    ///
    /// - Returns: A CGSize to be added to the translation to position the view while dragging.
    public func translationAdjustmentWhileDragging(_ adjustment: ((DragGesture.Value) -> (CGSize))?) -> DragView {
        var copy = self
        copy.translationAdjustment = adjustment
        return copy
    }

    private func onDragChanged(_ value: DragGesture.Value) {
        manager.report(drag: elementID, offset: adjustedTranslationWhileDragging(value))

        if !isDragging {
            isDragging = true
        }
    }
    
    private func onDragEnded(_ value: DragGesture.Value) {
        if manager.canDrop(id: elementID) {
            manager.dropDragView(of: elementID)
            isDroped = true
            dragOffset = CGSize.zero
            manager.report(drag: elementID, offset: CGSize.zero)
            dragginStoppedAction?(true)
        } else {
            withAnimation(.spring()) {
                dragOffset = CGSize.zero
            }
            manager.report(drag: elementID, offset: CGSize.zero)
            dragginStoppedAction?(false)
        }
        isDragging = false
    }

    private func adjustedTranslationWhileDragging(_ value: DragGesture.Value) -> CGSize {
        guard isDragging, let translationAdjustment else {
            return value.translation
        }

        let adjustment = translationAdjustment(value)
        return CGSize(width: value.translation.width + adjustment.width,
                      height: value.translation.height + adjustment.height)
    }
}
