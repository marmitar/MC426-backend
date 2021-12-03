import Foundation
import SwiftSoup

/// URL do índice de disciplinas.
private let indexURL = "https://www.dac.unicamp.br/sistemas/catalogos/grad/catalogo2021/disciplinas/index.html"

extension Discipline: WebScrapabl {
    static func scrape(with scraper: WebScraper) async throws -> [Discipline] {
        // carrega e parseia o índice
        let index = try await scraper.getHTML(from: indexURL)
        return try await scrapeIndex(page: index, with: scraper)
    }

    /// Parsing da página índice para encontrar os links das páginas de disciplinas e parsear cada uma.
    private static func scrapeIndex(page: Document, with scraper: WebScraper) async throws -> [Discipline] {
        // todos os links que seguem o padrão '../disciplinas/XX.html'
        let links = try page.getElementsByAttributeValueMatching("href", "^../disciplinas/..\\.html$")

        // as páginas podem ser requisitadas e parseadas em qualquer ordem
        let results = try await links.asyncUnorderedMap { link -> [Discipline] in
            let document = try await scraper.getHTML(from: try link.absUrl("href"))
            return try scrapeDisciplines(page: document)
        }
        return results.flatMap { $0 }
    }

    /// Parsing de uma página com várias disciplinas, em geral seguindo o mesmo padrão de sigla.
    private static func scrapeDisciplines(page: Document) throws -> [Discipline] {
        // acha os headers (h2) de cada disciplina, com id no formato 'disc-XX000'
        let headers = try page.getElementsByAttributeValueMatching("id", "^disc-..[0-9][0-9][0-9]$")

        return try headers.compactMap { header in
            try parseDiscipline(header)
        }
    }

    // MARK: - Parsing

    /// Parser de uma disciplina a partir do seu header (elemento com id 'disc-CÓDIGO').
    ///
    /// Assume todos os pré-requisitos como especiais e não faz tratamento do campo `reqBy`.
    private static func parseDiscipline(_ header: Element) throws -> Discipline {
        let (code, name) = try ParsingUtils.parseText(from: header, expectedTag: "h2") { try parseHeader(in: $0) }

        // as seções da disciplina são feitas por um <h3> (titulo da seção) seguido de
        // um <p> ou <div> (corpo da seção), que deve vir logo após o elemento
        let sections = try ParsingUtils.parseHTMLSections(header.parent(), headerTag: "h3") {
            try $0.nextElementSibling()
        }
        // a ementa é o texto de uma seção com título "Ementa"
        let syllabus = try ParsingUtils.getText(from: sections["Ementa"], ignoreChildren: true)
        // a carga horária é um pouco diferente, as seções tem como título um <strong>, mas o conteúdo fica
        // perdido dentro do elemento pai, e precisa ser acessado como um nó com apenas texto
        let workload = try ParsingUtils.parseHTMLSections(sections["Carga Horária"], headerTag: "strong") {
            $0.nextSibling()
        }
        // um nó (que não é elemento) tem tag vazia
        let credits = try ParsingUtils.parseText(from: workload["Total de Créditos:"], expectedTag: "") { UInt($0) }
        //
        let reqs = try ParsingUtils.parseText(from: sections["Pré-requisitos"], expectedTag: "p") {
            try parseAllRequirements(in: $0)
        }

        return Discipline(code: code, name: name, credits: credits, reqs: reqs, reqBy: Set(), syllabus: syllabus)
    }

    /// Parser do texto do header (`<h2 id="disc-XX000">`) de uma discplina, que apenas divide o texto em torno do "-".
    ///
    /// Espera que o texto esteja no formato 'CÓDIGO - Nome', senão retorna `nil`.
    private static func parseHeader(in text: String) throws -> (code: String, name: String)? {
        let parts = text.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
        guard
            let code = parts.get(at: 0)?.reducingWhitespace(),
            // use parseRequirement para garantir que o código é válido
            let validCode = try parseRequirement(in: code)?.code,
            let name = parts.get(at: 1)?.reducingWhitespace()
        else {
            return nil
        }
        return (validCode, name)
    }

    /// Parser da seção de pré-requisitos, que aceita o texto padrão quando não existe requisito ou o texto de
    /// requisitos no formato `GRUPO (ou GRUPO)...` em que `GRUPO` tem o formato `CODIGO(+CODIGO)...` e o
    /// código é aceito por ``parseRequirement``.
    private static func parseAllRequirements(in text: String) throws -> Set<Set<Requirement>>? {
        guard text.reducingWhitespace() != "Não há pré-requisitos para essa disciplina" else {
            return Set()
        }

        return try parseTextualGroup(in: text, separatedBy: "ou") { group in
            try parseTextualGroup(in: group, separatedBy: "+") { requirement in
                try parseRequirement(in: requirement)
            }
        }
    }

    /// Parser de um grupo textual no formato `ITEM (sep ITEM)...`.
    ///
    /// Parameter text: texto a ser parseado.
    /// Parameter separator: o separador de elementos do grupo (`sep`).
    /// Parameter parser: função que faz o parsing de cada item do grupo.
    /// Returns: conjunto dos itens do grupo.
    private static func parseTextualGroup<Item: Hashable>(
        in text: String,
        separatedBy separator: String,
        parser: (String) throws -> Item?
    ) rethrows -> Set<Item>? {
        try text.components(separatedBy: separator)
            .filter { !$0.isEmpty }
            .tryMap { try parser($0.reducingWhitespace()) }
            .map { results in Set(results) }
    }

    /// Regex que dá match com código de disciplinas e opcionalmente o marcador `*` de pré-requisito parcial.
    private static let disciplineCodeRegex = Result {
        try NSRegularExpression(pattern: "^(\\*?)([A-Z][A-Z ][0-9][0-9][0-9])$")
    }

    /// Parser de um pré-requisito de disciplina, no formato `XX000` ou `*XX000`.
    ///
    /// Assume que o código é especial, para ser corrigido depois.
    private static func parseRequirement(in text: String) throws -> Requirement? {
        let range = NSRange(location: 0, length: text.utf8.count)
        guard
            let matches = try disciplineCodeRegex.get().firstMatch(in: text, range: range),
            matches.numberOfRanges >= 3,
            let rangePartial = Range(matches.range(at: 1), in: text),
            let rangeCode = Range(matches.range(at: 2), in: text)
        else {
            return nil
        }
        let partialMarker = text[rangePartial]
        let code = text[rangeCode]

        return Requirement(code: String(code), partial: !partialMarker.isEmpty, special: true)
    }
}
