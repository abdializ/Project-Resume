import CryptoKit
import Foundation

struct SignatureOutput: Encodable {
    let publicKey: String
    let signature: String
    let fileURL: String
    let fileSize: UInt64
}

enum SparkleSignError: Error {
    case invalidArguments
    case invalidMode
    case invalidPrivateKey
}

func loadOrCreateKeyPair(at keyDirectoryURL: URL) throws -> (privateKey: String, publicKey: String) {
    let fileManager = FileManager.default
    try fileManager.createDirectory(at: keyDirectoryURL, withIntermediateDirectories: true)

    let privateKeyURL = keyDirectoryURL.appendingPathComponent("sparkle-private.key")
    let publicKeyURL = keyDirectoryURL.appendingPathComponent("sparkle-public.key")

    if fileManager.fileExists(atPath: privateKeyURL.path),
       fileManager.fileExists(atPath: publicKeyURL.path) {
        let privateKey = try String(contentsOf: privateKeyURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let publicKey = try String(contentsOf: publicKeyURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (privateKey, publicKey)
    }

    let privateKey = Curve25519.Signing.PrivateKey()
    let encodedPrivateKey = privateKey.rawRepresentation.base64EncodedString()
    let encodedPublicKey = privateKey.publicKey.rawRepresentation.base64EncodedString()

    try encodedPrivateKey.write(to: privateKeyURL, atomically: true, encoding: .utf8)
    try encodedPublicKey.write(to: publicKeyURL, atomically: true, encoding: .utf8)

    return (encodedPrivateKey, encodedPublicKey)
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    throw SparkleSignError.invalidArguments
}

let mode = arguments[1]

switch mode {
case "public-key":
    guard arguments.count == 3 else {
        throw SparkleSignError.invalidArguments
    }

    let keyDirectoryURL = URL(fileURLWithPath: arguments[2], isDirectory: true)
    let keyPair = try loadOrCreateKeyPair(at: keyDirectoryURL)
    FileHandle.standardOutput.write(Data(keyPair.publicKey.utf8))

case "sign":
    guard arguments.count == 4 else {
        throw SparkleSignError.invalidArguments
    }

    let archiveURL = URL(fileURLWithPath: arguments[2])
    let keyDirectoryURL = URL(fileURLWithPath: arguments[3], isDirectory: true)
    let keyPair = try loadOrCreateKeyPair(at: keyDirectoryURL)

    guard let privateKeyData = Data(base64Encoded: keyPair.privateKey) else {
        throw SparkleSignError.invalidPrivateKey
    }

    let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
    let archiveData = try Data(contentsOf: archiveURL)
    let signature = try privateKey.signature(for: archiveData)
    let attributes = try FileManager.default.attributesOfItem(atPath: archiveURL.path)
    let fileSize = attributes[.size] as? UInt64 ?? UInt64(archiveData.count)

    let output = SignatureOutput(
        publicKey: keyPair.publicKey,
        signature: signature.base64EncodedString(),
        fileURL: archiveURL.absoluteURL.absoluteString,
        fileSize: fileSize
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(output)
    FileHandle.standardOutput.write(data)

default:
    throw SparkleSignError.invalidMode
}
