import SwiftUI

/// 設定で選べる色（メインの色と背景の色の組み合わせ）。ライト／ダークそれぞれ用意する。
enum AppTheme: String, CaseIterable, Identifiable {
    case track = "トラックブルー"
    case night = "ナイトライム"
    case forest = "フォレストグリーン"
    case sunset = "サンセットオレンジ"

    static let storageKey = "appTheme"

    var id: String { rawValue }

    var accent: Color {
        switch self {
        case .track: Color(light: 0x1F4F93, dark: 0x79A6E6)
        case .night: Color(light: 0x3F7D00, dark: 0xC7FF00)
        case .forest: Color(light: 0x1E7A4C, dark: 0x72CF9C)
        case .sunset: Color(light: 0xC2410C, dark: 0xFB923C)
        }
    }

    var background: Color {
        switch self {
        case .track: Color(light: 0xEEF3F9, dark: 0x0F1820)
        case .night: Color(light: 0xF1F4EC, dark: 0x000000)
        case .forest: Color(light: 0xEDF5F0, dark: 0x0D1A13)
        case .sunset: Color(light: 0xFBF1EA, dark: 0x1C120D)
        }
    }

    /// 背景の上に置くカードの色
    var card: Color {
        switch self {
        case .track: Color(light: 0xFFFFFF, dark: 0x182532)
        case .night: Color(light: 0xFFFFFF, dark: 0x16181A)
        case .forest: Color(light: 0xFFFFFF, dark: 0x16271D)
        case .sunset: Color(light: 0xFFFFFF, dark: 0x2A1C14)
        }
    }

    /// アクセントの上に置く文字の色
    var onAccent: Color {
        switch self {
        case .night: Color(light: 0xFFFFFF, dark: 0x000000)
        default: Color(light: 0xFFFFFF, dark: 0x0B1117)
        }
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .track
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension View {
    /// リストやスクロール画面の背景を、選んだ色にする。
    func themedBackground() -> some View { modifier(ThemedBackground()) }

    /// 行の背景をカード色にする（リストの行用）。
    func themedRow() -> some View { modifier(ThemedRow()) }
}

private struct ThemedBackground: ViewModifier {
    @Environment(\.appTheme) private var theme

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(theme.background.ignoresSafeArea())
    }
}

private struct ThemedRow: ViewModifier {
    @Environment(\.appTheme) private var theme

    func body(content: Content) -> some View {
        content.listRowBackground(theme.card)
    }
}

/// 選んだ色を画面全体に配る（アプリの一番外側と、シートの中で使う）。
struct ThemeProvider<Content: View>: View {
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.track
    @ViewBuilder var content: Content

    var body: some View {
        content
            .environment(\.appTheme, theme)
            .tint(theme.accent)
    }
}
