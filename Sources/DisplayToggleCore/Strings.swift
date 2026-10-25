import Foundation

/// UI strings: Russian when it is the user's first preferred language, English otherwise.
public enum Strings {
    public static var isRussian: Bool = {
        (Locale.preferredLanguages.first ?? "en").hasPrefix("ru")
    }()

    public static func t(_ key: String) -> String {
        let table = isRussian ? ru : en
        return table[key] ?? en[key] ?? key
    }

    public static func t(_ key: String, _ arg: String) -> String {
        String(format: t(key), arg)
    }

    public static let en: [String: String] = [
        "icon.accessibility": "Displays",
        "menu.main": "%@ (main)",
        "menu.enableAll": "Enable All Displays",
        "menu.hotkeys": "Keyboard Shortcuts…",
        "menu.launchAtLogin": "Launch at Login",
        "menu.quit": "Quit (re-enables all displays)",
        "tip.disable": "Click to turn this display off",
        "tip.enable": "Click to turn this display back on",
        "hk.title": "Keyboard Shortcuts",
        "hk.enableAll": "Enable all displays",
        "hk.toggle": "Turn on/off: %@",
        "hk.hint": "Click a field and press a shortcut. Esc cancels, ⌫ clears.\nA shortcut needs ⌃, ⌥ or ⌘ (F-keys work alone).",
        "hk.recording": "Type shortcut…",
        "hk.none": "None",
        "hk.clear": "Clear",
        "hk.taken.title": "Shortcut unavailable",
        "hk.taken.text": "%@ is already used by macOS or another app. Pick a different one.",
    ]

    public static let ru: [String: String] = [
        "icon.accessibility": "Мониторы",
        "menu.main": "%@ (основной)",
        "menu.enableAll": "Включить все мониторы",
        "menu.hotkeys": "Горячие клавиши…",
        "menu.launchAtLogin": "Запускать при входе",
        "menu.quit": "Выход (включит все мониторы)",
        "tip.disable": "Нажмите, чтобы отключить монитор",
        "tip.enable": "Нажмите, чтобы включить монитор",
        "hk.title": "Горячие клавиши",
        "hk.enableAll": "Включить все мониторы",
        "hk.toggle": "Вкл/выкл: %@",
        "hk.hint": "Нажмите на поле и введите сочетание. Esc — отмена, ⌫ — очистить.\nНужна клавиша ⌃, ⌥ или ⌘ (F-клавиши можно без них).",
        "hk.recording": "Введите сочетание…",
        "hk.none": "Не задано",
        "hk.clear": "Очистить",
        "hk.taken.title": "Сочетание недоступно",
        "hk.taken.text": "%@ уже занято системой или другой программой. Выберите другое.",
    ]
}
