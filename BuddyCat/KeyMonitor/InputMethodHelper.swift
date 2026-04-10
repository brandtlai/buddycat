import Carbon

struct InputMethodHelper {
    static func currentInputMethodType() -> InputMethodType {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
            return .other
        }
        let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
        let lowered = id.lowercased()

        if lowered.contains("com.apple.keylayout") {
            return .en
        }

        let zhKeywords = [
            "chinese", "pinyin", "sogou", "baidu", "wechat",
            "shuangpin", "wubi", "zhuyin", "cangjie"
        ]
        if zhKeywords.contains(where: { lowered.contains($0) }) {
            return .zh
        }

        return .other
    }
}
