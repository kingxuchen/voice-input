import CoreAudio

public struct AudioDevice: Identifiable, Equatable, Sendable {
    public let id: AudioDeviceID
    public let name: String

    public init(id: AudioDeviceID, name: String) {
        self.id = id
        self.name = name
    }
}
