import SwiftUI

struct SectionHeaderView: View {
    let title: String
    let subtitle: String
    var titleSize: CGFloat = 17
    var subtitleSize: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: titleSize, weight: .semibold))
            Text(subtitle)
                .font(.system(size: subtitleSize))
                .foregroundStyle(.secondary)
        }
    }
}
