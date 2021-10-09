import Foundation

extension Collection {
    /// Acesso opcional na coleção para posições que podem
    /// ser inválidas.
    ///
    /// - Returns: `nil` quando a posição requisitada
    ///   não contém um elemento associado.
    func get(at position: Self.Index) -> Self.Element? {
        if self.indices.contains(position) {
            return self[position]
        } else {
            return nil
        }
    }
}

extension StringProtocol {
    /// Remove a extensão do nome do arquivo.
    ///
    /// ```swift
    /// "arquivo.py".stripExtension() == "arquivo"
    /// ```
    func stripExtension() -> String {
        var components = self.components(separatedBy: ".")
        if components.count > 1 {
            components.removeLast()
        }
        return components.joined(separator: ".")
    }
}
