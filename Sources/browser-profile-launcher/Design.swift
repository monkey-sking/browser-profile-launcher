import AppKit
import SwiftUI

// MARK: - 设计 Token

enum AppColors {
    /// 主色 #3366CC
    static let primary = Color(nsColor: NSColor(red: 0.20, green: 0.40, blue: 0.80, alpha: 1))

    /// 破坏性操作（删除）#D6453D
    static let destructive = Color(nsColor: NSColor(red: 0.839, green: 0.271, blue: 0.239, alpha: 1))

    /// 运行中绿点 #1E9E6A
    static let running = Color(nsColor: NSColor(red: 0.118, green: 0.620, blue: 0.416, alpha: 1))

    /// 各浏览器品牌色（用于色块头像底色）
    static let browserBrand: [BrowserKind: Color] = [
        .chrome:       Color(nsColor: NSColor(red: 0.259, green: 0.522, blue: 0.957, alpha: 1)),
        .edge:         Color(nsColor: NSColor(red: 0.184, green: 0.608, blue: 0.839, alpha: 1)),
        .brave:        Color(nsColor: NSColor(red: 0.984, green: 0.329, blue: 0.169, alpha: 1)),
        .arc:          Color(nsColor: NSColor(red: 0.984, green: 0.416, blue: 0.620, alpha: 1)),
        .vivaldi:      Color(nsColor: NSColor(red: 0.937, green: 0.247, blue: 0.212, alpha: 1)),
        .chromium:     Color(nsColor: NSColor(red: 0.235, green: 0.514, blue: 0.882, alpha: 1)),
        .opera:        Color(nsColor: NSColor(red: 0.235, green: 0.451, blue: 0.851, alpha: 1)),
        .chromeCanary: Color(nsColor: NSColor(red: 0.259, green: 0.522, blue: 0.957, alpha: 1)),
        .edgeCanary:   Color(nsColor: NSColor(red: 0.184, green: 0.608, blue: 0.839, alpha: 1)),
        .egoLite:      AppColors.primary,
        .browserClaw:  AppColors.primary,
    ]

    static func brand(for browser: BrowserKind) -> Color {
        browserBrand[browser] ?? primary
    }
}

// MARK: - 浏览器色块头像（品牌色圆角方块 + 白色 Globe）

struct BrowserAvatarView: View {
    let browser: BrowserKind
    var size: CGFloat = 32

    var body: some View {
        let corner = size * 0.28
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(AppColors.brand(for: browser))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "globe")
                    .font(.system(size: size * 0.56, weight: .medium))
                    .foregroundStyle(.white)
            )
    }
}

// MARK: - 语义标签（色胶囊，对应设计稿状态色）

struct ProfileTag: View {
    enum Kind {
        case `default`   // 默认
        case recent       // 最近
        case nonDefault   // 非默认目录
    }

    let kind: Kind
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(Capsule())
    }

    private var foreground: Color {
        switch kind {
        case .default:    return Color(nsColor: NSColor(red: 0.690, green: 0.478, blue: 0.071, alpha: 1)) // #B07A12
        case .recent:     return Color(nsColor: NSColor(red: 0.718, green: 0.475, blue: 0.122, alpha: 1)) // #B7791F
        case .nonDefault: return AppColors.primary
        }
    }

    private var background: Color {
        switch kind {
        case .default:    return Color(nsColor: NSColor(red: 0.984, green: 0.941, blue: 0.839, alpha: 1)) // #FBF0D6
        case .recent:     return Color(nsColor: NSColor(red: 0.992, green: 0.922, blue: 0.839, alpha: 1)) // #FDEBD6
        case .nonDefault: return Color(nsColor: NSColor(red: 0.910, green: 0.933, blue: 0.984, alpha: 1)) // #E8EEFB
        }
    }
}
