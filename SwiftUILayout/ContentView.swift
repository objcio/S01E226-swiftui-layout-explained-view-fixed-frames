//
//  ContentView.swift
//  NotSwiftUI
//
//  Created by Chris Eidhof on 05.10.20.
//

import SwiftUI

protocol View_ {
    associatedtype Body: View_
    var body: Body { get }
    
    // for debugging
    associatedtype SwiftUIView: View
    var swiftUI: SwiftUIView { get }
}

typealias RenderingContext = CGContext
typealias ProposedSize = CGSize

protocol BuiltinView {
    func render(context: RenderingContext, size: CGSize)
    func size(proposed: ProposedSize) -> CGSize
    typealias Body = Never
}

extension View_ where Body == Never {
    var body: Never { fatalError("This should never be called.") }
}

extension Never: View_ {
    typealias Body = Never
    var swiftUI: Never { fatalError("Should never be called") }
}

extension View_ {
    func _render(context: RenderingContext, size: CGSize) {
        if let builtin = self as? BuiltinView {
            builtin.render(context: context, size: size)
        } else {
            body._render(context: context, size: size)
        }
    }
    
    func _size(proposed: ProposedSize) -> CGSize {
        if let builtin = self as? BuiltinView {
            return builtin.size(proposed: proposed)
        } else {
            return body._size(proposed: proposed)
        }
    }
}

protocol Shape_: View_ {
    func path(in rect: CGRect) -> CGPath
}

extension Shape_ {
    var body: some View_ {
        ShapeView(shape: self)
    }
    var swiftUI: AnyShape {
        AnyShape(shape: self)
    }
}

extension NSColor: View_ {
    var body: some View_ {
        ShapeView(shape: Rectangle_(), color: self)
    }
    
    var swiftUI: some View {
        Color(self)
    }
}

struct AnyShape: Shape {
    let _path: (CGRect) -> CGPath
    init<S: Shape_>(shape: S) {
        _path = shape.path(in:)
    }
    
    func path(in rect: CGRect) -> Path {
        Path(_path(rect))
    }
}

struct ShapeView<S: Shape_>: BuiltinView, View_ {
    var shape: S
    var color: NSColor =  .red
    
    func size(proposed: ProposedSize) -> CGSize {
        return proposed
    }
    
    func render(context: RenderingContext, size: ProposedSize) {
        context.saveGState()
        context.setFillColor(color.cgColor)
        context.addPath(shape.path(in: CGRect(origin: .zero, size: size)))
        context.fillPath()
        context.restoreGState()
    }
    
    var swiftUI: some View {
        AnyShape(shape: shape)
    }
}

struct Rectangle_: Shape_ {
    func path(in rect: CGRect) -> CGPath {
        CGPath(rect: rect, transform: nil)
    }
}

struct Ellipse_: Shape_ {
    func path(in rect: CGRect) -> CGPath {
        CGPath(ellipseIn: rect, transform: nil)
    }
}

struct FixedFrame<Content: View_>: View_, BuiltinView {
    var width: CGFloat?
    var height: CGFloat?
    var content: Content
    
    func size(proposed: ProposedSize) -> CGSize {
        let childSize = content._size(proposed: ProposedSize(width: width ?? proposed.width, height: height ?? proposed.height))
        return CGSize(width: width ?? childSize.width, height: height ?? childSize.height)
    }
    func render(context: RenderingContext, size: ProposedSize) {
        context.saveGState()
        let childSize = content._size(proposed: size)
        let x = (size.width-childSize.width)/2
        let y = (size.height-childSize.height)/2
        context.translateBy(x: x, y: y)
        content._render(context: context, size: childSize)
        context.restoreGState()
    }
    
    var swiftUI: some View {
        content.swiftUI.frame(width: width, height: height)
    }
}

extension View_ {
    func frame(width: CGFloat? = nil, height: CGFloat? = nil) -> some View_ {
        FixedFrame(width: width, height: height, content: self)
    }
}

var sample: some View_ {
    Ellipse_()
        .frame(width: 200, height: 100)
        .frame(width: 300, height: 50)
}

func render<V: View_>(view: V, size: CGSize) -> Data {
    return CGContext.pdf(size: size) { context in
        view
            .frame(width: size.width, height: size.height)
            ._render(context: context, size: size)
    }
}

struct ContentView: View {
    let size = CGSize(width: 600, height: 400)

    @State var opacity: Double = 0.5
    var body: some View {
        VStack {
            ZStack  {
                Image(nsImage: NSImage(data: render(view: sample, size: size))!)
                    .opacity(1-opacity)
                sample.swiftUI.frame(width: size.width, height: size.height)
                    .opacity(opacity)
            }
            Slider(value: $opacity, in: 0...1)
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
