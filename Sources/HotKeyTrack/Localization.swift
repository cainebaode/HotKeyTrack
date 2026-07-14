import Foundation

/// 轻量国际化：系统首选语言为中文时展示中文，否则一律使用英文。
enum AppLang {
    /// 是否中文环境（zh / zh-Hans / zh-Hant 等均视为中文）。
    /// 在进程生命周期内固定，读取一次即可。
    static let isChinese: Bool = {
        let pref = (Locale.preferredLanguages.first ?? "en").lowercased()
        return pref.hasPrefix("zh")
    }()
}

/// 就地双语工具：中文环境返回 `zh`，否则返回 `en`。
/// 用法：`Text(LT("重新扫描", "Rescan"))`
func LT(_ zh: String, _ en: String) -> String {
    AppLang.isChinese ? zh : en
}
