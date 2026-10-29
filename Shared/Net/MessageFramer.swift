import Foundation
import Network

final class MessageFramer: NWProtocolFramerImplementation {
    static let definition = NWProtocolFramer.Definition(implementation: MessageFramer.self)

    static let label = "MoonfallFramer"
    private static let headerSize = MemoryLayout<UInt32>.size

    required init(framer _: NWProtocolFramer.Instance) {}

    func start(framer _: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult {
        .ready
    }

    func wakeup(framer _: NWProtocolFramer.Instance) {}

    func stop(framer _: NWProtocolFramer.Instance) -> Bool {
        true
    }

    func cleanup(framer _: NWProtocolFramer.Instance) {}

    func handleOutput(framer: NWProtocolFramer.Instance, message _: NWProtocolFramer.Message, messageLength: Int, isComplete _: Bool) {
        var header = UInt32(messageLength).bigEndian
        framer.writeOutput(data: Data(bytes: &header, count: Self.headerSize))
        try? framer.writeOutputNoCopy(length: messageLength)
    }

    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        while true {
            var length: UInt32?
            let parsed = framer.parseInput(minimumIncompleteLength: Self.headerSize, maximumLength: Self.headerSize) { buffer, _ in
                guard let buffer, buffer.count >= Self.headerSize else { return 0 }
                length = buffer.loadUnaligned(as: UInt32.self).bigEndian
                return Self.headerSize
            }
            guard parsed, let length else { return Self.headerSize }
            let message = NWProtocolFramer.Message(definition: Self.definition)
            if !framer.deliverInputNoCopy(length: Int(length), message: message, isComplete: true) {
                return 0
            }
        }
    }
}

extension NWParameters {
    static func moonfall() -> NWParameters {
        let parameters = NWParameters.tcp
        parameters.defaultProtocolStack.applicationProtocols.insert(NWProtocolFramer.Options(definition: MessageFramer.definition), at: 0)
        return parameters
    }
}

extension NWConnection {
    func sendFramed(_ data: Data) {
        let message = NWProtocolFramer.Message(definition: MessageFramer.definition)
        let context = NWConnection.ContentContext(identifier: "message", metadata: [message])
        send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { _ in })
    }
}
