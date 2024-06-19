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
    private let elementId: UUID
    private var translationAdjustment: ((DragGesture.Value) -> (CGSize))?
    private var reportIsDraggingClosure: ((UUID, Bool) -> ())?
    private var onTappedClosure: ((UUID) -> ())?

    /// Initialize this view with its unique ID and custom view.
    ///
    /// - Parameters:
    ///     - id: The unique id of this view.
    ///     - content: The custom content of this view and what will be dragged.
    public init(id: UUID, @ViewBuilder content: @escaping ContentType) where DragContent == Content {
        self.elementId = id
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
        self.elementId = id
        self.content = content
        self.dragContent = dragContent
    }
    
    public var body: some View {
        ZStack {
            dragContent(DragInfo(didDrop: isDroped, isDragging: isDragging, isColliding: manager.isColliding(dragId: elementId)))
                .offset(dragOffset)
                .zIndex(isDragging ? 1 : 0)
            content(isDragging)
                .background {
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                self.manager.add(dragId: elementId, frame: geometry.frame(in: .dragAndDrop))
                            }
                            .onChange(of: geometry.frame(in: .dragAndDrop)) { newValue in
                                self.manager.update(dragId: elementId, frame: newValue)
                            }
                            .onDisappear {
                                self.manager.remove(dragId: elementId)
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
                        .simultaneously(with:
                            TapGesture(count: 1)
                                .onEnded { onTappedClosure?(elementId) }
                        )
                )
        }
        .zIndex(isDragging ? 1 : 0)
        .onChange(of: isDragging) { isDragging in
            reportIsDraggingClosure?(elementId, isDragging)
        }
    }
    
    /// An action indicating if the user has stopped dragging this view and indicates if it has dropped succesfuly on a `DropView` or not.
    ///
    /// - Parameter action: An action that will happen after the user has stopped dragging. (Also tell if it has dropped or not on a `DropView`) .
    ///
    /// - Returns: A DragView with a dragging ended action trigger.
    public func onDraggingEnded(action: @escaping (Bool) -> Void) -> Self {
        var new = self
        new.dragginStoppedAction = action
        return new
    }

    /// Set an optional closure to calculate the adjustment to the position of the view,
    /// eg when we want the view to be visible above the finger while dragging.
    ///
    /// - Parameter adjustment: A closure that takes `startLocation` of the touch,
    ///     and computes the adjustment.
    ///
    /// - Returns: A DragView with the translation adjustment closure added.
    public func translationAdjustmentWhileDragging(_ adjustment: ((DragGesture.Value) -> (CGSize))?) -> Self {
        var copy = self
        copy.translationAdjustment = adjustment
        return copy
    }

    /// Set an optional closure to report if the view is dragging.
    ///
    /// - Parameter closure: A closure to be invoked when `isDragging` state changes.
    ///
    /// - Returns: A DragView with the `reportIsDraggingClosure` set.
    public func reportIsDragging(_ closure: ((UUID, Bool) -> ())?) -> Self {
        var copy = self
        copy.reportIsDraggingClosure = closure
        return copy
    }

    /// Set an optional closure to report tap gestire.
    ///
    /// - Parameter closure: A closure to be invoked when tap gesture is recognized.
    ///
    /// - Returns: A DragView with the `onTappedClosure` set.
    public func onTapped(_ closure: ((UUID) -> ())?) -> Self {
        var copy = self
        copy.onTappedClosure = closure
        return copy
    }

    // MARK: - Private

    private func onDragChanged(_ value: DragGesture.Value) {
        manager.report(dragId: elementId, offset: adjustedTranslationWhileDragging(value))

        if !isDragging {
            isDragging = true
        }
    }
    
    private func onDragEnded(_ value: DragGesture.Value) {
        if manager.canDrop(dragId: elementId) {
          manager.drop(dragId: elementId)
            isDroped = true
            dragOffset = CGSize.zero
            manager.report(dragId: elementId, offset: CGSize.zero)
            dragginStoppedAction?(true)
        } else {
            withAnimation(.spring()) {
                dragOffset = CGSize.zero
            }
            manager.report(dragId: elementId, offset: CGSize.zero)
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
