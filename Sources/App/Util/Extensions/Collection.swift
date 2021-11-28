//
//  File.swift
//
//
//  Created by Vitor Jundi Moriya on 25/10/21.
//

import Foundation

extension Collection {
    /// Acesso opcional na coleção para posições que podem
    /// ser inválidas.
    ///
    /// - Returns: `nil` quando a posição requisitada
    ///   não contém um elemento associado.
    ///
    /// ```swift
    /// ["a", "b", "c"].get(at: 1) == "b"
    ///
    /// ["a", "b"].get(at: 2) == nil
    /// ```
    @inlinable
    func get(at position: Index) -> Element? {
        if self.indices.contains(position) {
            return self[position]
        } else {
            return nil
        }
    }
}

extension MutableCollection where Self: RandomAccessCollection {
    /// Ordena a coleção usando uma chave de comparação.
    ///
    /// - Complexity: O(*n* log *n*)
    @inlinable
    mutating func sort<T: Comparable>(on key: (Element) throws -> T) rethrows {
        try self.sort { try key($0) < key($1) }
    }
}

extension RandomAccessCollection where Index: BinaryInteger {
    /// Busca binária em um vetor ordenado.
    ///
    /// - Parameter searchKey: Chave a ser buscada.
    /// - Parameter key: Acessor da chave em cada elemento.
    /// - Parameter areInIncreasingOrder: Predicado que diz se
    ///   um chave vem antes da outra (deve ser ordem estrita).
    ///
    /// - Returns: O valor com chave mais próxima de `searchKey`,
    ///   mais ainda menor ou igual (exceto quando todos são
    ///   maiores).
    ///
    /// - Complexity: O(*n* log *n*)
    @inlinable
    func binarySearch<T>(
        for searchKey: T,
        on key: (Element) throws -> T,
        by areInIncreasingOrder: (T, T) throws -> Bool
    ) rethrows -> Element? {
        var low = self.startIndex
        var high = self.index(low, offsetBy: self.count)

        var result: Element?
        while low < high {
            let mid = (low + high) / 2
            result = self[mid]
            let midKey = try key(self[mid])

            if try areInIncreasingOrder(midKey, searchKey) {
                low = mid + 1
            } else if try areInIncreasingOrder(searchKey, midKey) {
                high = mid
            } else {
                return result
            }
        }
        return result
    }

    /// Busca binária em um vetor ordenado.
    ///
    /// - Parameter searchKey: chave a ser buscada.
    /// - Parameter key: acessor da chave em cada elemento.
    ///
    /// - Returns: O valor com chave mais próxima de `searchKey`,
    ///   mais ainda menor ou igual (exceto quando todos são
    ///   maiores).
    ///
    /// - Complexity: O(log *n*)
    @inlinable
    func binarySearch<T: Comparable>(
        for searchKey: T,
        on key: (Element) throws -> T
    ) rethrows -> Element? {
        try self.binarySearch(for: searchKey, on: key, by: <)
    }
}
