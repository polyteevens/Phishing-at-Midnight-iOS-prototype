import Foundation

enum SpecimenLoaderError: Error {
    case resourceNotFound
    case decodingFailed(Error)
}

enum SpecimenLoader {
    /// Loads and decodes the full specimen pool from `specimens.json` in the
    /// app bundle. Called once at launch; the result is cheap to keep in memory.
    static func loadPool(bundle: Bundle = .main) throws -> [Specimen] {
        guard let url = bundle.url(forResource: "specimens", withExtension: "json") else {
            throw SpecimenLoaderError.resourceNotFound
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Specimen].self, from: data)
        } catch let error as SpecimenLoaderError {
            throw error
        } catch {
            throw SpecimenLoaderError.decodingFailed(error)
        }
    }
}
