import SwiftUI

struct WedgeProgressView: View {
    let progress: Double
    let hint: String
    
    init(progress: Double, hint: String) {
        self.progress = progress
        self.hint = hint
    }
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                    .stroke(Color.indigo, style: StrokeStyle(lineWidth: 20, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                    .padding(20)
                
                Circle()
                    .trim(from: CGFloat(min(progress, 1.0)), to: 1.0)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 20, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                    .padding(20)
                
                VStack {
                    Text(String(format: "%.0f%%", progress * 100))
                        .font(.headline)
                        .bold()
                    if !hint.isEmpty {
                        Text(hint)
                            .font(.subheadline)
                    }
                }
            }
            .frame(width: 150, height: 150)
        }
    }
}

struct WedgeContentView: View {
    var body: some View {
        VStack {
            WedgeProgressView(progress: 0.99, hint: "of initial")
                .padding()
            Text("Wedge Progress")
                .font(.title)
                .padding(.top, 20)
        }
    }
}

struct WedgeContentView_Previews: PreviewProvider {
    static var previews: some View {
        WedgeContentView()
    }
}
