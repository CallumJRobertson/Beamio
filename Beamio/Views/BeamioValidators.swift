import Foundation

enum BeamioValidator {
    static func isValidIP(_ value: String) -> Bool {
        let ip = "(25[0-5]|2[0-4]\\d|1\\d{2}|[1-9]?\\d)"
        let pattern = "^\(ip)(\\.\(ip)){3}(:[0-9]{1,5})?$"
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: value)
    }
}
