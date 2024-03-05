//
//  TripleArrow.swift
//  BiltongTracker
//
//  Created by Igor Chertenkov on 03/03/2024.
//

import SwiftUI

struct TripleRightArrow: View {
    var body: some View {
        HStack(spacing: -2) {
            Triangle()
            Triangle()
            Triangle()
        }
    }
}

struct Triangle: View {
    let width = 5.0
    let reach = 5.0
    let spacing = 5.0
    let height = 15.0
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: width, y: 0))
            path.addLine(to: CGPoint(x: width + reach, y: height / 2))
            path.addLine(to: CGPoint(x: width, y: height))
            path.addLine(to: CGPoint(x: 0, y: height))
            path.addLine(to: CGPoint(x: reach, y: height / 2))
            path.closeSubpath()
        }
        .fill(Color.orange)
        .frame(width: width + reach, height: height)
    }
}

struct TripleArrowContentView: View {
    var body: some View {
        TripleRightArrow()
    }
}

struct TripleArrowContentView_Previews: PreviewProvider {
    static var previews: some View {
        TripleArrowContentView()
    }
}
