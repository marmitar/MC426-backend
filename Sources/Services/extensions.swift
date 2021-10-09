import Foundation

extension Collection {
    /// Acesso opcional na coleção para posições que podem
    /// ser inválidas.
    ///
    /// - Returns: `nil` quando a posição requisitada
    ///   não contém um elemento associado.
    func get(at position: Index) -> Element? {
        if self.indices.contains(position) {
            return self[position]
        } else {
            return nil
        }
    }
}

/// Mutex que cobre um valor.
///
/// # Obsercação
///
/// Não é seguro em usos gerais.
private class Mutex<T> {
    private let inner = NSLock()
    private var value: T

    init(_ value: T) {
        self.value = value
    }

    /// Executa uma ação com controle da mutex.
    func withLock<U>(perform: (inout T) throws -> U) rethrows -> U {
        self.inner.lock()
        defer { self.inner.unlock() }

        return try perform(&self.value)
    }

    /// Acessa o valor, sem trancar a mutex.
    ///
    /// # Cuidado
    ///
    /// Usar apenas após todas as operações com a mutex.
    func get() -> T {
        self.value
    }
}

public extension RandomAccessCollection where Self.SubSequence == ArraySlice<Element> {
    /// Versão concorrente do ``Array.forEach``.
    ///
    /// Pode ser executada em ordem diferente da esperada.
    func concurrentForEach(_ body: (Element) throws -> Void) rethrows {
        try concurrentPerform(execute: body, onError: { throw $0 })
        /// Função necessária para evitar problemas com `rethrows`. Veja:
        /// https://developer.apple.com/forums/thread/8002?answerId=24898022#24898022
        func concurrentPerform(
            execute: (Element) throws -> Void,
            onError: (Error) throws -> Void
        ) rethrows {
            let err = Mutex<Error?>(nil)

            DispatchQueue.concurrentPerform(iterations: self.count) { position in
                let index = self.index(
                    self.startIndex,
                    offsetBy: position
                )

                do {
                    try execute(self[index])
                } catch {
                    err.withLock { $0 = error }
                }
            }

            if let error = err.get() {
                try onError(error)
            }
        }
    }

    /// Versão concorrente do ``Array.map``.
    ///
    /// O resultado pode ter uma ordem diferente da esperada.
    func concurrentMap<T>(_ transform: (Element) throws -> T) rethrows -> [T] {
        let transformed = Mutex<[T]>([])

        try self.concurrentForEach { item in
            let newItem = try transform(item)

            transformed.withLock {
                $0.append(newItem)
            }
        }
        return transformed.get()
    }

    /// Versão concorrente do ``Array.flatMap``.
    ///
    /// O resultado pode ter uma ordem diferente da esperada.
    func concurrentFlatMap<Segment: Sequence>(
        _ transform: (Element) throws -> Segment
    ) rethrows -> [Segment.Element] {
        let transformed = Mutex<[Segment.Element]>([])

        try self.concurrentForEach { item in
            let newSequence = try transform(item)

            transformed.withLock {
                $0.append(contentsOf: newSequence)
            }
        }
        return transformed.get()
    }

    /// Versão concorrente do ``Array.compactMap``.
    ///
    /// O resultado pode ter uma ordem diferente da esperada.
    func concurrentCompactMap<Result>(
        _ transform: (Element) throws -> Result?
    ) rethrows -> [Result] {
        let transformed = Mutex<[Result]>([])

        try self.concurrentForEach { item in
            if let newItem = try transform(item) {
                transformed.withLock {
                    $0.append(newItem)
                }
            }
        }
        return transformed.get()
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
