import SwiftUI

struct FruitGradeSplashView: View {
    var onGetStarted: () -> Void

    var body: some View {
        ZStack {
            FruitGradePhotoBackground(emoji: "🍎", dark: true)
                .ignoresSafeArea()
            Color.black.opacity(0.25).ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 90, height: 90)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                }

                Text("FruitGrade")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)

                Text("Know the ripeness,\nget the best quality.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()
                Spacer()

                Button(action: onGetStarted) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    // Placeholder: UI mockup only, no learn-more destination yet.
                } label: {
                    Text("Learn More")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
    }
}

#Preview {
    FruitGradeSplashView(onGetStarted: {})
}
