import SwiftUI

struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        return path
    }
}

struct WedgeProgressView: View {
    let progress: Double
    let target: Double?
    
    private enum Constants {
        static let wedgeRelativeWidth = 0.15
    }
    
    init(progress: Double, target: Double? = nil) {
        self.progress = progress
        self.target = target
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                    .stroke(Color.indigo, style: StrokeStyle(lineWidth: geometry.size.width * Constants.wedgeRelativeWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                    .padding(geometry.size.width * Constants.wedgeRelativeWidth / 2)
                
                Circle()
                    .trim(from: CGFloat(min(progress, 1.0)), to: 1.0)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: geometry.size.width * Constants.wedgeRelativeWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                    .padding(geometry.size.width * Constants.wedgeRelativeWidth / 2)
                    .overlay(alignment: Alignment(horizontal: .center, vertical: .center), content: {
                        if let target = self.target {
                            Line().stroke(Color.red, style: StrokeStyle(lineWidth: 2, dash: [5]))
                                .frame(width: 1, height: geometry.size.width * Constants.wedgeRelativeWidth * 1.5)
                                .offset(y: geometry.size.width * (1 - Constants.wedgeRelativeWidth) / 2)
                                .rotationEffect(Angle(degrees: 180 + 360 * target))
                        }
                    }
                    )
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.system(size: geometry.size.width * 0.2, weight: .bold))
            }
        }
        .aspectRatio(1.0, contentMode: .fit)
    }
}

struct WedgeContentView: View {
    var body: some View {
        VStack {
            WedgeProgressView(progress: 0.9, target: 0.75)
                .padding()
            Text("Wedge Progress")
                .font(.title)
                .padding(.top, 20)
            Spacer()
        }
    }
}

struct WedgeContentView_Previews: PreviewProvider {
    static var previews: some View {
        WedgeContentView()
    }
}
