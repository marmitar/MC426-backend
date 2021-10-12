import Foundation
import Vapor
import Services


/// Dados que podem ser após a busca.
///
/// A forma reduzida é usada para enviar menos informação
/// para o cliente, removendo alguns campos que só são
/// úteis quando requisitados epsecificamente.
protocol Matchable: Searchable {
    /// Forma reduzida do dado, usada como preview
    /// durante a busca.
    associatedtype ReducedForm: EncodableMatch

    /// Reduz o dado.
    func reduced() -> ReducedForm
}

extension Matchable {
    /// Nome do tipo em letras minúsculas, usado
    /// como valor do `ReducedForm.content`.
    static func contentName() -> String {
        "\(Self.self)".lowercased()
    }
}

/// Conteúdo retornado por uma match, contendo um
/// campo que descreve seu tipo.
protocol EncodableMatch: Encodable {
    /// Descrição do tipo.
    var content: String { get }

    /// Definido para marcar o campo 'content' para encode.
    /// https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types
    associatedtype CodingKeys: CodingKey
}

/// Controlador de dados buscáveis.
protocol ContentController {
    /// Tipo do dado que ele controla.
    associatedtype Content: Matchable

    /// Busca textual no conjunto de dados.
    ///
    /// - Parameter text: Texto a ser buscado.
    /// - Parameter maxScore: Maior score que ainda
    ///   pode ser considerado um match.
    ///
    /// - Returns: Vetor com os dados que deram match
    ///   e o score de cada item para a query. Dados
    ///   com um score menor que `maxScore` não são
    ///   retornados.
    func search(for text: String, upTo maxScore: Double) -> [(item: Content, score: Double)]
}

extension ContentController {
    /// Busca textual no conjunto de dados.
    ///
    /// Os resultados da busca são retornados de
    /// já forma ordenada. Apenas os `matches`
    /// melhores scores são retornados.
    ///
    /// - Parameter text: Texto a ser buscado.
    /// - Parameter matches: Quantidade máxima de
    ///   dados que deve ser retornada. Os dados com
    ///   os menores scores são ignorados.
    /// - Parameter maxScore: Maior score que ainda
    ///   pode ser considerado um match.
    ///
    /// - Returns: Vetor ordenado com os matches do
    ///   conjunto de dados. O vetor é limitado aos
    ///   `matches` melhores scores e todos os dados
    ///   tem um score menor que `maxScore`.
    func search(for text: String, limitedTo matches: Int, upTo maxScore: Double) -> [Match] {
        var results = self.search(for: text, upTo: maxScore)
        results.sort(on: { $0.score })

        return results.prefix(matches).map {
            Match($0.item.reduced(), $0.score)
        }
    }
}

/// Representa um match no conjunto de dados.
///
/// Útil para trabalhar com matches de tipos
/// diferentes, mas que ainda podem ser
/// enviados como JSON.
struct Match {
    /// O item a ser enviado.
    let item: Encodable
    /// O score do item, usado para comparação.
    let score: Double

    fileprivate init(_ item: Encodable, _ score: Double) {
        self.item = item
        self.score = score
    }
}

extension Match: Content {
    /// Não faz sentido receber um `Match` do cliente.
    init(from decoder: Decoder) throws {
        throw DecodingError.typeMismatch(Never.self, .init(
            codingPath: [],
            debugDescription: "Can't decode to a MatchedContent"
        ))
    }

    /// Um `Match` é formatado exatamente como seu item interno.
    func encode(to encoder: Encoder) throws {
        try self.item.encode(to: encoder)
    }
}
