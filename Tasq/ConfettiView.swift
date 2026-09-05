//
//  ConfettiView.swift
//  Chartflow
//

import SwiftUI

struct ConfettiPiece: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var color: Color
    var rotation: Double
    var scale: CGFloat
    var speed: CGFloat
    var wobble: CGFloat
}

struct ConfettiView: View {
    @State private var pieces: [ConfettiPiece] = []
    @State private var animating = false

    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(piece.color)
                        .frame(width: 10, height: 14)
                        .scaleEffect(piece.scale)
                        .rotationEffect(.degrees(piece.rotation))
                        .position(x: piece.x, y: piece.y)
                }
            }
            .onAppear {
                pieces = (0..<80).map { _ in
                    ConfettiPiece(
                        x: CGFloat.random(in: 0...geo.size.width),
                        y: -20,
                        color: colors.randomElement()!,
                        rotation: Double.random(in: 0...360),
                        scale: CGFloat.random(in: 0.5...1.5),
                        speed: CGFloat.random(in: 200...500),
                        wobble: CGFloat.random(in: -60...60)
                    )
                }

                withAnimation(.easeIn(duration: 0.1)) {
                    animating = true
                }

                for i in pieces.indices {
                    let duration = Double.random(in: 1.5...3.0)
                    withAnimation(.easeOut(duration: duration).delay(Double.random(in: 0...0.5))) {
                        pieces[i].y = geo.size.height + 20
                        pieces[i].x += pieces[i].wobble
                        pieces[i].rotation += Double.random(in: 180...720)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    ConfettiView()
}
