import Foundation

extension OSType {
    init(fourCharCode: String) {
        precondition(fourCharCode.count == 4, "FourCharCode must be exactly 4 characters")
        var result: OSType = 0
        for char in fourCharCode.utf8 {
            result = (result << 8) | OSType(char)
        }
        self = result
    }
}
