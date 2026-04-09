import Foundation

// MARK: - ChemistrySolver
// Deterministic chemistry interceptor: periodic table lookup, molar mass
// calculation, element/group queries. "App decide, LLM ensena" — the solver
// computes exact answers; the teacher LLM only explains them pedagogically.

struct ChemistrySolver: SubjectInterceptor, Sendable {

    let interceptorId = "chemistry_solver"
    let supportedSubjects: Set<Subject> = [.chemistry, .open]

    // MARK: - Element Model

    struct Element: Sendable {
        let atomicNumber: Int
        let symbol: String
        let nameSpanish: String
        let atomicMass: Double
        let group: Int?
        let period: Int
        let category: String
    }

    // MARK: - Periodic Table (118 elements, IUPAC 2021 masses)

    static let elements: [Element] = [
        Element(atomicNumber: 1,   symbol: "H",  nameSpanish: "Hidrógeno",     atomicMass: 1.008,     group: 1,   period: 1, category: "No metal"),
        Element(atomicNumber: 2,   symbol: "He", nameSpanish: "Helio",         atomicMass: 4.0026,    group: 18,  period: 1, category: "Gas noble"),
        Element(atomicNumber: 3,   symbol: "Li", nameSpanish: "Litio",         atomicMass: 6.941,     group: 1,   period: 2, category: "Metal alcalino"),
        Element(atomicNumber: 4,   symbol: "Be", nameSpanish: "Berilio",       atomicMass: 9.0122,    group: 2,   period: 2, category: "Metal alcalinotérreo"),
        Element(atomicNumber: 5,   symbol: "B",  nameSpanish: "Boro",          atomicMass: 10.81,     group: 13,  period: 2, category: "Metaloide"),
        Element(atomicNumber: 6,   symbol: "C",  nameSpanish: "Carbono",       atomicMass: 12.011,    group: 14,  period: 2, category: "No metal"),
        Element(atomicNumber: 7,   symbol: "N",  nameSpanish: "Nitrógeno",     atomicMass: 14.007,    group: 15,  period: 2, category: "No metal"),
        Element(atomicNumber: 8,   symbol: "O",  nameSpanish: "Oxígeno",       atomicMass: 15.999,    group: 16,  period: 2, category: "No metal"),
        Element(atomicNumber: 9,   symbol: "F",  nameSpanish: "Flúor",         atomicMass: 18.998,    group: 17,  period: 2, category: "Halógeno"),
        Element(atomicNumber: 10,  symbol: "Ne", nameSpanish: "Neón",          atomicMass: 20.180,    group: 18,  period: 2, category: "Gas noble"),
        Element(atomicNumber: 11,  symbol: "Na", nameSpanish: "Sodio",         atomicMass: 22.990,    group: 1,   period: 3, category: "Metal alcalino"),
        Element(atomicNumber: 12,  symbol: "Mg", nameSpanish: "Magnesio",      atomicMass: 24.305,    group: 2,   period: 3, category: "Metal alcalinotérreo"),
        Element(atomicNumber: 13,  symbol: "Al", nameSpanish: "Aluminio",      atomicMass: 26.982,    group: 13,  period: 3, category: "Metal del bloque p"),
        Element(atomicNumber: 14,  symbol: "Si", nameSpanish: "Silicio",       atomicMass: 28.085,    group: 14,  period: 3, category: "Metaloide"),
        Element(atomicNumber: 15,  symbol: "P",  nameSpanish: "Fósforo",       atomicMass: 30.974,    group: 15,  period: 3, category: "No metal"),
        Element(atomicNumber: 16,  symbol: "S",  nameSpanish: "Azufre",        atomicMass: 32.06,     group: 16,  period: 3, category: "No metal"),
        Element(atomicNumber: 17,  symbol: "Cl", nameSpanish: "Cloro",         atomicMass: 35.45,     group: 17,  period: 3, category: "Halógeno"),
        Element(atomicNumber: 18,  symbol: "Ar", nameSpanish: "Argón",         atomicMass: 39.948,    group: 18,  period: 3, category: "Gas noble"),
        Element(atomicNumber: 19,  symbol: "K",  nameSpanish: "Potasio",       atomicMass: 39.098,    group: 1,   period: 4, category: "Metal alcalino"),
        Element(atomicNumber: 20,  symbol: "Ca", nameSpanish: "Calcio",        atomicMass: 40.078,    group: 2,   period: 4, category: "Metal alcalinotérreo"),
        Element(atomicNumber: 21,  symbol: "Sc", nameSpanish: "Escandio",      atomicMass: 44.956,    group: 3,   period: 4, category: "Metal de transición"),
        Element(atomicNumber: 22,  symbol: "Ti", nameSpanish: "Titanio",       atomicMass: 47.867,    group: 4,   period: 4, category: "Metal de transición"),
        Element(atomicNumber: 23,  symbol: "V",  nameSpanish: "Vanadio",       atomicMass: 50.942,    group: 5,   period: 4, category: "Metal de transición"),
        Element(atomicNumber: 24,  symbol: "Cr", nameSpanish: "Cromo",         atomicMass: 51.996,    group: 6,   period: 4, category: "Metal de transición"),
        Element(atomicNumber: 25,  symbol: "Mn", nameSpanish: "Manganeso",     atomicMass: 54.938,    group: 7,   period: 4, category: "Metal de transición"),
        Element(atomicNumber: 26,  symbol: "Fe", nameSpanish: "Hierro",        atomicMass: 55.845,    group: 8,   period: 4, category: "Metal de transición"),
        Element(atomicNumber: 27,  symbol: "Co", nameSpanish: "Cobalto",       atomicMass: 58.933,    group: 9,   period: 4, category: "Metal de transición"),
        Element(atomicNumber: 28,  symbol: "Ni", nameSpanish: "Níquel",        atomicMass: 58.693,    group: 10,  period: 4, category: "Metal de transición"),
        Element(atomicNumber: 29,  symbol: "Cu", nameSpanish: "Cobre",         atomicMass: 63.546,    group: 11,  period: 4, category: "Metal de transición"),
        Element(atomicNumber: 30,  symbol: "Zn", nameSpanish: "Zinc",          atomicMass: 65.38,     group: 12,  period: 4, category: "Metal de transición"),
        Element(atomicNumber: 31,  symbol: "Ga", nameSpanish: "Galio",         atomicMass: 69.723,    group: 13,  period: 4, category: "Metal del bloque p"),
        Element(atomicNumber: 32,  symbol: "Ge", nameSpanish: "Germanio",      atomicMass: 72.630,    group: 14,  period: 4, category: "Metaloide"),
        Element(atomicNumber: 33,  symbol: "As", nameSpanish: "Arsénico",      atomicMass: 74.922,    group: 15,  period: 4, category: "Metaloide"),
        Element(atomicNumber: 34,  symbol: "Se", nameSpanish: "Selenio",       atomicMass: 78.971,    group: 16,  period: 4, category: "No metal"),
        Element(atomicNumber: 35,  symbol: "Br", nameSpanish: "Bromo",         atomicMass: 79.904,    group: 17,  period: 4, category: "Halógeno"),
        Element(atomicNumber: 36,  symbol: "Kr", nameSpanish: "Kriptón",       atomicMass: 83.798,    group: 18,  period: 4, category: "Gas noble"),
        Element(atomicNumber: 37,  symbol: "Rb", nameSpanish: "Rubidio",       atomicMass: 85.468,    group: 1,   period: 5, category: "Metal alcalino"),
        Element(atomicNumber: 38,  symbol: "Sr", nameSpanish: "Estroncio",     atomicMass: 87.62,     group: 2,   period: 5, category: "Metal alcalinotérreo"),
        Element(atomicNumber: 39,  symbol: "Y",  nameSpanish: "Itrio",         atomicMass: 88.906,    group: 3,   period: 5, category: "Metal de transición"),
        Element(atomicNumber: 40,  symbol: "Zr", nameSpanish: "Circonio",      atomicMass: 91.224,    group: 4,   period: 5, category: "Metal de transición"),
        Element(atomicNumber: 41,  symbol: "Nb", nameSpanish: "Niobio",        atomicMass: 92.906,    group: 5,   period: 5, category: "Metal de transición"),
        Element(atomicNumber: 42,  symbol: "Mo", nameSpanish: "Molibdeno",     atomicMass: 95.95,     group: 6,   period: 5, category: "Metal de transición"),
        Element(atomicNumber: 43,  symbol: "Tc", nameSpanish: "Tecnecio",      atomicMass: 98.0,      group: 7,   period: 5, category: "Metal de transición"),
        Element(atomicNumber: 44,  symbol: "Ru", nameSpanish: "Rutenio",       atomicMass: 101.07,    group: 8,   period: 5, category: "Metal de transición"),
        Element(atomicNumber: 45,  symbol: "Rh", nameSpanish: "Rodio",         atomicMass: 102.91,    group: 9,   period: 5, category: "Metal de transición"),
        Element(atomicNumber: 46,  symbol: "Pd", nameSpanish: "Paladio",       atomicMass: 106.42,    group: 10,  period: 5, category: "Metal de transición"),
        Element(atomicNumber: 47,  symbol: "Ag", nameSpanish: "Plata",         atomicMass: 107.87,    group: 11,  period: 5, category: "Metal de transición"),
        Element(atomicNumber: 48,  symbol: "Cd", nameSpanish: "Cadmio",        atomicMass: 112.41,    group: 12,  period: 5, category: "Metal de transición"),
        Element(atomicNumber: 49,  symbol: "In", nameSpanish: "Indio",         atomicMass: 114.82,    group: 13,  period: 5, category: "Metal del bloque p"),
        Element(atomicNumber: 50,  symbol: "Sn", nameSpanish: "Estaño",        atomicMass: 118.71,    group: 14,  period: 5, category: "Metal del bloque p"),
        Element(atomicNumber: 51,  symbol: "Sb", nameSpanish: "Antimonio",     atomicMass: 121.76,    group: 15,  period: 5, category: "Metaloide"),
        Element(atomicNumber: 52,  symbol: "Te", nameSpanish: "Telurio",       atomicMass: 127.60,    group: 16,  period: 5, category: "Metaloide"),
        Element(atomicNumber: 53,  symbol: "I",  nameSpanish: "Yodo",          atomicMass: 126.90,    group: 17,  period: 5, category: "Halógeno"),
        Element(atomicNumber: 54,  symbol: "Xe", nameSpanish: "Xenón",         atomicMass: 131.29,    group: 18,  period: 5, category: "Gas noble"),
        Element(atomicNumber: 55,  symbol: "Cs", nameSpanish: "Cesio",         atomicMass: 132.91,    group: 1,   period: 6, category: "Metal alcalino"),
        Element(atomicNumber: 56,  symbol: "Ba", nameSpanish: "Bario",         atomicMass: 137.33,    group: 2,   period: 6, category: "Metal alcalinotérreo"),
        Element(atomicNumber: 57,  symbol: "La", nameSpanish: "Lantano",       atomicMass: 138.91,    group: nil, period: 6, category: "Lantánido"),
        Element(atomicNumber: 58,  symbol: "Ce", nameSpanish: "Cerio",         atomicMass: 140.12,    group: nil, period: 6, category: "Lantánido"),
        Element(atomicNumber: 59,  symbol: "Pr", nameSpanish: "Praseodimio",   atomicMass: 140.91,    group: nil, period: 6, category: "Lantánido"),
        Element(atomicNumber: 60,  symbol: "Nd", nameSpanish: "Neodimio",      atomicMass: 144.24,    group: nil, period: 6, category: "Lantánido"),
        Element(atomicNumber: 61,  symbol: "Pm", nameSpanish: "Prometio",      atomicMass: 145.0,     group: nil, period: 6, category: "Lantánido"),
        Element(atomicNumber: 62,  symbol: "Sm", nameSpanish: "Samario",       atomicMass: 150.36,    group: nil, period: 6, category: "Lantánido"),
        Element(atomicNumber: 63,  symbol: "Eu", nameSpanish: "Europio",       atomicMass: 151.96,    group: nil, period: 6, category: "Lantánido"),
        Element(atomicNumber: 64,  symbol: "Gd", nameSpanish: "Gadolinio",     atomicMass: 157.25,    group: nil, period: 6, category: "Lantánido"),
        Element(atomicNumber: 65,  symbol: "Tb", nameSpanish: "Terbio",        atomicMass: 158.93,    group: nil, period: 6, category: "Lantánido"),
        Element(atomicNumber: 66,  symbol: "Dy", nameSpanish: "Disprosio",     atomicMass: 162.50,    group: nil, period: 6, category: "Lantánido"),
        Element(atomicNumber: 67,  symbol: "Ho", nameSpanish: "Holmio",        atomicMass: 164.93,    group: nil, period: 6, category: "Lantánido"),
        Element(atomicNumber: 68,  symbol: "Er", nameSpanish: "Erbio",         atomicMass: 167.26,    group: nil, period: 6, category: "Lantánido"),
        Element(atomicNumber: 69,  symbol: "Tm", nameSpanish: "Tulio",         atomicMass: 168.93,    group: nil, period: 6, category: "Lantánido"),
        Element(atomicNumber: 70,  symbol: "Yb", nameSpanish: "Iterbio",       atomicMass: 173.05,    group: nil, period: 6, category: "Lantánido"),
        Element(atomicNumber: 71,  symbol: "Lu", nameSpanish: "Lutecio",       atomicMass: 174.97,    group: 3,   period: 6, category: "Lantánido"),
        Element(atomicNumber: 72,  symbol: "Hf", nameSpanish: "Hafnio",        atomicMass: 178.49,    group: 4,   period: 6, category: "Metal de transición"),
        Element(atomicNumber: 73,  symbol: "Ta", nameSpanish: "Tantalio",      atomicMass: 180.95,    group: 5,   period: 6, category: "Metal de transición"),
        Element(atomicNumber: 74,  symbol: "W",  nameSpanish: "Wolframio",     atomicMass: 183.84,    group: 6,   period: 6, category: "Metal de transición"),
        Element(atomicNumber: 75,  symbol: "Re", nameSpanish: "Renio",         atomicMass: 186.21,    group: 7,   period: 6, category: "Metal de transición"),
        Element(atomicNumber: 76,  symbol: "Os", nameSpanish: "Osmio",         atomicMass: 190.23,    group: 8,   period: 6, category: "Metal de transición"),
        Element(atomicNumber: 77,  symbol: "Ir", nameSpanish: "Iridio",        atomicMass: 192.22,    group: 9,   period: 6, category: "Metal de transición"),
        Element(atomicNumber: 78,  symbol: "Pt", nameSpanish: "Platino",       atomicMass: 195.08,    group: 10,  period: 6, category: "Metal de transición"),
        Element(atomicNumber: 79,  symbol: "Au", nameSpanish: "Oro",           atomicMass: 196.97,    group: 11,  period: 6, category: "Metal de transición"),
        Element(atomicNumber: 80,  symbol: "Hg", nameSpanish: "Mercurio",      atomicMass: 200.59,    group: 12,  period: 6, category: "Metal de transición"),
        Element(atomicNumber: 81,  symbol: "Tl", nameSpanish: "Talio",         atomicMass: 204.38,    group: 13,  period: 6, category: "Metal del bloque p"),
        Element(atomicNumber: 82,  symbol: "Pb", nameSpanish: "Plomo",         atomicMass: 207.2,     group: 14,  period: 6, category: "Metal del bloque p"),
        Element(atomicNumber: 83,  symbol: "Bi", nameSpanish: "Bismuto",       atomicMass: 208.98,    group: 15,  period: 6, category: "Metal del bloque p"),
        Element(atomicNumber: 84,  symbol: "Po", nameSpanish: "Polonio",       atomicMass: 209.0,     group: 16,  period: 6, category: "Metaloide"),
        Element(atomicNumber: 85,  symbol: "At", nameSpanish: "Astato",        atomicMass: 210.0,     group: 17,  period: 6, category: "Halógeno"),
        Element(atomicNumber: 86,  symbol: "Rn", nameSpanish: "Radón",         atomicMass: 222.0,     group: 18,  period: 6, category: "Gas noble"),
        Element(atomicNumber: 87,  symbol: "Fr", nameSpanish: "Francio",       atomicMass: 223.0,     group: 1,   period: 7, category: "Metal alcalino"),
        Element(atomicNumber: 88,  symbol: "Ra", nameSpanish: "Radio",         atomicMass: 226.0,     group: 2,   period: 7, category: "Metal alcalinotérreo"),
        Element(atomicNumber: 89,  symbol: "Ac", nameSpanish: "Actinio",       atomicMass: 227.0,     group: nil, period: 7, category: "Actínido"),
        Element(atomicNumber: 90,  symbol: "Th", nameSpanish: "Torio",         atomicMass: 232.04,    group: nil, period: 7, category: "Actínido"),
        Element(atomicNumber: 91,  symbol: "Pa", nameSpanish: "Protactinio",   atomicMass: 231.04,    group: nil, period: 7, category: "Actínido"),
        Element(atomicNumber: 92,  symbol: "U",  nameSpanish: "Uranio",        atomicMass: 238.03,    group: nil, period: 7, category: "Actínido"),
        Element(atomicNumber: 93,  symbol: "Np", nameSpanish: "Neptunio",      atomicMass: 237.0,     group: nil, period: 7, category: "Actínido"),
        Element(atomicNumber: 94,  symbol: "Pu", nameSpanish: "Plutonio",      atomicMass: 244.0,     group: nil, period: 7, category: "Actínido"),
        Element(atomicNumber: 95,  symbol: "Am", nameSpanish: "Americio",      atomicMass: 243.0,     group: nil, period: 7, category: "Actínido"),
        Element(atomicNumber: 96,  symbol: "Cm", nameSpanish: "Curio",         atomicMass: 247.0,     group: nil, period: 7, category: "Actínido"),
        Element(atomicNumber: 97,  symbol: "Bk", nameSpanish: "Berkelio",      atomicMass: 247.0,     group: nil, period: 7, category: "Actínido"),
        Element(atomicNumber: 98,  symbol: "Cf", nameSpanish: "Californio",    atomicMass: 251.0,     group: nil, period: 7, category: "Actínido"),
        Element(atomicNumber: 99,  symbol: "Es", nameSpanish: "Einstenio",     atomicMass: 252.0,     group: nil, period: 7, category: "Actínido"),
        Element(atomicNumber: 100, symbol: "Fm", nameSpanish: "Fermio",        atomicMass: 257.0,     group: nil, period: 7, category: "Actínido"),
        Element(atomicNumber: 101, symbol: "Md", nameSpanish: "Mendelevio",    atomicMass: 258.0,     group: nil, period: 7, category: "Actínido"),
        Element(atomicNumber: 102, symbol: "No", nameSpanish: "Nobelio",       atomicMass: 259.0,     group: nil, period: 7, category: "Actínido"),
        Element(atomicNumber: 103, symbol: "Lr", nameSpanish: "Lawrencio",     atomicMass: 266.0,     group: 3,   period: 7, category: "Actínido"),
        Element(atomicNumber: 104, symbol: "Rf", nameSpanish: "Rutherfordio",  atomicMass: 267.0,     group: 4,   period: 7, category: "Metal de transición"),
        Element(atomicNumber: 105, symbol: "Db", nameSpanish: "Dubnio",        atomicMass: 268.0,     group: 5,   period: 7, category: "Metal de transición"),
        Element(atomicNumber: 106, symbol: "Sg", nameSpanish: "Seaborgio",     atomicMass: 269.0,     group: 6,   period: 7, category: "Metal de transición"),
        Element(atomicNumber: 107, symbol: "Bh", nameSpanish: "Bohrio",        atomicMass: 270.0,     group: 7,   period: 7, category: "Metal de transición"),
        Element(atomicNumber: 108, symbol: "Hs", nameSpanish: "Hasio",         atomicMass: 277.0,     group: 8,   period: 7, category: "Metal de transición"),
        Element(atomicNumber: 109, symbol: "Mt", nameSpanish: "Meitnerio",     atomicMass: 278.0,     group: 9,   period: 7, category: "Metal de transición"),
        Element(atomicNumber: 110, symbol: "Ds", nameSpanish: "Darmstadtio",   atomicMass: 281.0,     group: 10,  period: 7, category: "Metal de transición"),
        Element(atomicNumber: 111, symbol: "Rg", nameSpanish: "Roentgenio",    atomicMass: 282.0,     group: 11,  period: 7, category: "Metal de transición"),
        Element(atomicNumber: 112, symbol: "Cn", nameSpanish: "Copernicio",    atomicMass: 285.0,     group: 12,  period: 7, category: "Metal de transición"),
        Element(atomicNumber: 113, symbol: "Nh", nameSpanish: "Nihonio",       atomicMass: 286.0,     group: 13,  period: 7, category: "Metal del bloque p"),
        Element(atomicNumber: 114, symbol: "Fl", nameSpanish: "Flerovio",      atomicMass: 289.0,     group: 14,  period: 7, category: "Metal del bloque p"),
        Element(atomicNumber: 115, symbol: "Mc", nameSpanish: "Moscovio",      atomicMass: 290.0,     group: 15,  period: 7, category: "Metal del bloque p"),
        Element(atomicNumber: 116, symbol: "Lv", nameSpanish: "Livermorio",    atomicMass: 293.0,     group: 16,  period: 7, category: "Metal del bloque p"),
        Element(atomicNumber: 117, symbol: "Ts", nameSpanish: "Teneso",        atomicMass: 294.0,     group: 17,  period: 7, category: "Halógeno"),
        Element(atomicNumber: 118, symbol: "Og", nameSpanish: "Oganesón",      atomicMass: 294.0,     group: 18,  period: 7, category: "Gas noble"),
    ]

    // MARK: - Precomputed Lookup Tables

    /// Symbol -> Element (case-sensitive: "Fe", "Na", etc.)
    private static let bySymbol: [String: Element] = {
        Dictionary(uniqueKeysWithValues: elements.map { ($0.symbol, $0) })
    }()

    /// Normalized Spanish name -> Element (lowercased, no diacritics)
    private static let byName: [String: Element] = {
        Dictionary(uniqueKeysWithValues: elements.map {
            (normalizeKey($0.nameSpanish), $0)
        })
    }()

    /// Atomic number -> Element
    private static let byNumber: [Int: Element] = {
        Dictionary(uniqueKeysWithValues: elements.map { ($0.atomicNumber, $0) })
    }()

    // MARK: - Group Name Aliases (Spanish)

    /// Maps common group name keywords to group numbers
    private static let groupAliases: [(keyword: String, groupNumbers: [Int])] = [
        ("metales alcalinos",       [1]),
        ("metal alcalino",          [1]),
        ("alcalinos",               [1]),
        ("alcalinoterreos",         [2]),
        ("alcalinotérreos",         [2]),
        ("metales alcalinoterreos", [2]),
        ("gases nobles",            [18]),
        ("gas noble",               [18]),
        ("halogenos",               [17]),
        ("halógenos",               [17]),
        ("calcogenos",              [16]),
        ("calcógenos",              [16]),
        ("pnicogenos",              [15]),
        ("pnictógenos",             [15]),
    ]

    /// Maps category names to filter criteria
    private static let categoryAliases: [(keyword: String, category: String)] = [
        ("lantanido",             "Lantánido"),
        ("lantanidos",            "Lantánido"),
        ("lantánido",             "Lantánido"),
        ("lantánidos",            "Lantánido"),
        ("tierras raras",         "Lantánido"),
        ("actinido",              "Actínido"),
        ("actinidos",             "Actínido"),
        ("actínido",              "Actínido"),
        ("actínidos",             "Actínido"),
        ("metal de transicion",   "Metal de transición"),
        ("metales de transicion", "Metal de transición"),
        ("metal de transición",   "Metal de transición"),
        ("metales de transición", "Metal de transición"),
        ("metaloides",            "Metaloide"),
        ("metaloide",             "Metaloide"),
        ("no metales",            "No metal"),
        ("no metal",              "No metal"),
    ]

    // MARK: - Detection Keywords

    private static let chemistryKeywords: [String] = [
        "masa molar", "peso molecular", "peso atomico",
        "elemento", "elementos", "tabla periodica",
        "grupo", "periodo",
        "metal alcalino", "gas noble", "halogeno", "halógeno",
        "lantanido", "lantánido", "actinido", "actínido",
        "metal de transicion", "metal de transición",
        "metaloide", "no metal",
        "numero atomico", "número atómico",
        "masa atomica", "masa atómica",
        "simbolo quimico", "símbolo químico",
        "formula quimica", "fórmula química",
        "compuesto", "molecula", "molécula",
    ]

    /// Chemical formula pattern: uppercase letter optionally followed by lowercase,
    /// then optional digits/subscripts. Must have at least 2 element-like tokens or
    /// digits to distinguish from regular words.
    private static let formulaPattern: NSRegularExpression = {
        // Matches formulas like H2O, NaCl, C6H12O6, H2SO4, Ca(OH)2
        try! NSRegularExpression(pattern: #"[A-Z][a-z]?[₀₁₂₃₄₅₆₇₈₉\d]*(?:\([A-Z][a-z]?[₀₁₂₃₄₅₆₇₈₉\d]*(?:[A-Z][a-z]?[₀₁₂₃₄₅₆₇₈₉\d]*)*\)[₀₁₂₃₄₅₆₇₈₉\d]*)*(?:[A-Z][a-z]?[₀₁₂₃₄₅₆₇₈₉\d]*)*"#)
    }()

    // MARK: - Detection

    func detect(_ text: String, subject: Subject) -> Bool {
        let normalized = normalize(text)

        // 1. Check for chemistry keywords
        if Self.chemistryKeywords.contains(where: { normalized.contains($0) }) {
            return true
        }

        // 2. Check for element names in Spanish
        if Self.byName.keys.contains(where: { normalized.contains($0) }) {
            return true
        }

        // 3. Check for element symbol patterns (e.g., "elemento Fe", "que es Au")
        let symbolPattern = #"\b(?:elemento|simbolo|símbolo)\s+([A-Z][a-z]?)\b"#
        if let regex = try? NSRegularExpression(pattern: symbolPattern),
           regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
            return true
        }

        // 4. Check for "elemento numero N" pattern
        let numberPattern = #"elemento\s*(?:numero|número|#|n[°º]?\.?)\s*(\d+)"#
        if let regex = try? NSRegularExpression(pattern: numberPattern, options: .caseInsensitive),
           regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
            return true
        }

        // 5. Check for molar mass / molecular weight with a formula
        if (normalized.contains("masa molar") || normalized.contains("peso molecular")) {
            return true
        }

        // 6. Check for chemical formula with "masa", "formula", "compuesto"
        let formulaContext = normalized.contains("formula") || normalized.contains("compuesto")
            || normalized.contains("molecula") || normalized.contains("masa")
        if formulaContext {
            if Self.formulaPattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                return true
            }
        }

        // 7. Check for group/category queries
        if Self.groupAliases.contains(where: { normalized.contains($0.keyword) }) {
            return true
        }
        if Self.categoryAliases.contains(where: { normalized.contains($0.keyword) }) {
            return true
        }

        return false
    }

    // MARK: - Solve

    func solve(_ text: String, subject: Subject) async -> InterceptorResult {
        let normalized = normalize(text)

        // 1. Molar mass calculation
        if let result = solveMolarMass(text, normalized: normalized) { return result }

        // 2. Element lookup by atomic number
        if let result = solveByAtomicNumber(normalized, original: text) { return result }

        // 3. Element lookup by symbol
        if let result = solveBySymbol(text, normalized: normalized) { return result }

        // 4. Element lookup by Spanish name
        if let result = solveByName(normalized) { return result }

        // 5. Group lookup
        if let result = solveGroupLookup(normalized) { return result }

        // 6. Category lookup
        if let result = solveCategoryLookup(normalized) { return result }

        return .passthrough(text)
    }

    // MARK: - Molar Mass Calculator

    private func solveMolarMass(_ text: String, normalized: String) -> InterceptorResult? {
        // Trigger: "masa molar de X" or "peso molecular de X"
        let triggers = ["masa molar", "peso molecular"]
        guard triggers.contains(where: { normalized.contains($0) }) else { return nil }

        // Extract formula from original text (preserves case)
        guard let formula = extractFormula(text) else { return nil }

        // Parse and compute
        guard let parsed = parseFormula(formula) else { return nil }
        guard !parsed.isEmpty else { return nil }

        var totalMass = 0.0
        var breakdown: [(symbol: String, count: Int, mass: Double)] = []

        for (symbol, count) in parsed {
            guard let element = Self.bySymbol[symbol] else { return nil }
            let contribution = element.atomicMass * Double(count)
            totalMass += contribution
            breakdown.append((symbol, count, contribution))
        }

        let formattedMass = formatMass(totalMass)
        let answer = "Masa molar de \(formula) = \(formattedMass) g/mol"

        let breakdownStr = breakdown.map { item in
            "\(item.symbol)\(item.count > 1 ? String(item.count) : ""): \(item.count) x \(formatMass(Self.bySymbol[item.symbol]?.atomicMass ?? 0)) = \(formatMass(item.mass))"
        }.joined(separator: " + ")

        let breakdownJSON = breakdown.map { item in
            "{\"symbol\":\"\(item.symbol)\",\"count\":\(item.count),\"mass\":\(formatMass(item.mass))}"
        }.joined(separator: ",")

        return InterceptorResult(
            answer: answer,
            teacherInstruction: "[RESULTADO: \(formattedMass) g/mol] Explica como se calcula la masa molar de \(formula): \(breakdownStr). Suma total = \(formattedMass) g/mol.",
            category: .computed,
            attachmentType: "formula_result",
            attachmentData: """
            {"formula":"\(formula)","molarMass":\(formattedMass),"breakdown":[\(breakdownJSON)],"unit":"g/mol","type":"molar_mass"}
            """,
            confidence: 1.0
        )
    }

    /// Extracts a chemical formula from the text (preserving uppercase for element symbols).
    private func extractFormula(_ text: String) -> String? {
        // Look for formula after "de" or "del" keyword
        let dePattern = #"(?:de|del)\s+([A-Z][a-zA-Z₀₁₂₃₄₅₆₇₈₉\d\(\)]+)"#
        if let regex = try? NSRegularExpression(pattern: dePattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            let candidate = String(text[range])
            // Validate it looks like a formula (has at least one uppercase letter)
            if candidate.contains(where: { $0.isUppercase }) {
                return candidate
            }
        }

        // Fallback: find any formula-like pattern in the text
        let range = NSRange(text.startIndex..., in: text)
        if let match = Self.formulaPattern.firstMatch(in: text, range: range),
           let matchRange = Range(match.range, in: text) {
            let candidate = String(text[matchRange])
            // Must have at least 2 characters and contain an uppercase letter
            if candidate.count >= 2 && candidate.contains(where: { $0.isUppercase }) {
                return candidate
            }
        }

        return nil
    }

    /// Parses a chemical formula into [(symbol, count)] pairs.
    /// Handles: H2O, NaCl, C6H12O6, H2SO4, Ca(OH)2, Mg3(PO4)2
    /// Supports both Unicode subscripts and regular digits.
    private func parseFormula(_ formula: String) -> [(String, Int)]? {
        // First normalize subscript digits to regular digits
        let normalized = normalizeSubscripts(formula)
        var result: [(String, Int)] = []
        var index = normalized.startIndex

        while index < normalized.endIndex {
            let char = normalized[index]

            if char.isUppercase {
                // Start of element symbol
                var symbol = String(char)
                var next = normalized.index(after: index)

                // Collect lowercase letters (part of symbol)
                while next < normalized.endIndex && normalized[next].isLowercase {
                    symbol.append(normalized[next])
                    next = normalized.index(after: next)
                }

                // Collect digits (subscript count)
                var countStr = ""
                while next < normalized.endIndex && normalized[next].isNumber {
                    countStr.append(normalized[next])
                    next = normalized.index(after: next)
                }

                let count = countStr.isEmpty ? 1 : (Int(countStr) ?? 1)

                // Validate symbol exists
                guard Self.bySymbol[symbol] != nil else { return nil }

                result.append((symbol, count))
                index = next

            } else if char == "(" {
                // Start of group: collect until matching ")"
                var depth = 1
                var groupStr = ""
                var next = normalized.index(after: index)

                while next < normalized.endIndex && depth > 0 {
                    let c = normalized[next]
                    if c == "(" { depth += 1 }
                    else if c == ")" { depth -= 1 }
                    if depth > 0 { groupStr.append(c) }
                    next = normalized.index(after: next)
                }

                guard depth == 0 else { return nil }

                // Collect multiplier after ")"
                var multStr = ""
                while next < normalized.endIndex && normalized[next].isNumber {
                    multStr.append(normalized[next])
                    next = normalized.index(after: next)
                }

                let multiplier = multStr.isEmpty ? 1 : (Int(multStr) ?? 1)

                // Recursively parse the group
                guard let groupParsed = parseFormula(groupStr) else { return nil }

                for (sym, cnt) in groupParsed {
                    result.append((sym, cnt * multiplier))
                }

                index = next

            } else {
                // Unexpected character
                return nil
            }
        }

        return result
    }

    /// Converts Unicode subscript digits to regular digits.
    private func normalizeSubscripts(_ text: String) -> String {
        let subscriptMap: [Character: Character] = [
            "\u{2080}": "0", "\u{2081}": "1", "\u{2082}": "2", "\u{2083}": "3",
            "\u{2084}": "4", "\u{2085}": "5", "\u{2086}": "6", "\u{2087}": "7",
            "\u{2088}": "8", "\u{2089}": "9",
        ]
        return String(text.map { subscriptMap[$0] ?? $0 })
    }

    // MARK: - Element Lookup by Atomic Number

    private func solveByAtomicNumber(_ normalized: String, original: String) -> InterceptorResult? {
        // Patterns: "elemento numero 6", "elemento #6", "elemento 79", "numero atomico 26"
        let patterns: [String] = [
            #"elemento\s*(?:numero|número|#|n[°º]?\.?)\s*(\d+)"#,
            #"numero atomico\s*(?:del?\s*)?(\d+)"#,
            #"elemento\s+(\d+)\b"#,
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
               let range = Range(match.range(at: 1), in: normalized),
               let number = Int(normalized[range]),
               let element = Self.byNumber[number] {
                return buildElementResult(element)
            }
        }

        return nil
    }

    // MARK: - Element Lookup by Symbol

    private func solveBySymbol(_ text: String, normalized: String) -> InterceptorResult? {
        // Patterns: "elemento Fe", "simbolo Au", "que es el Fe"
        let patterns: [String] = [
            #"(?:elemento|simbolo|símbolo)\s+([A-Z][a-z]?)\b"#,
            #"que es (?:el\s+)?([A-Z][a-z]?)\b"#,
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let symbol = String(text[range])
                if let element = Self.bySymbol[symbol] {
                    return buildElementResult(element)
                }
            }
        }

        return nil
    }

    // MARK: - Element Lookup by Name

    private func solveByName(_ normalized: String) -> InterceptorResult? {
        // Check for common query patterns: "que es el carbono", "propiedades del hierro",
        // "dime sobre el oxigeno", or just the element name
        let queryPatterns: [String] = [
            #"(?:que es|qué es|propiedades|dime sobre|informacion sobre|información sobre|hablame de|háblame de|explica)\s*(?:el|la|del|de la|de)?\s*(.+)"#,
        ]

        for pattern in queryPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
               let range = Range(match.range(at: 1), in: normalized) {
                let candidate = String(normalized[range]).trimmingCharacters(in: .whitespaces)
                if let element = Self.byName[candidate] {
                    return buildElementResult(element)
                }
            }
        }

        // Direct name match: just the element name alone or with common prefixes
        for (name, element) in Self.byName {
            if normalized == name || normalized == "el \(name)" || normalized == "la \(name)" {
                return buildElementResult(element)
            }
        }

        return nil
    }

    // MARK: - Group Lookup

    private func solveGroupLookup(_ normalized: String) -> InterceptorResult? {
        // Check named group aliases first
        for alias in Self.groupAliases {
            if normalized.contains(alias.keyword) {
                let groupElements = Self.elements.filter { el in
                    alias.groupNumbers.contains(el.group ?? -1)
                }
                if !groupElements.isEmpty {
                    return buildGroupResult(
                        groupName: alias.keyword.capitalized,
                        elements: groupElements
                    )
                }
            }
        }

        // Check for "grupo N" pattern
        let groupPattern = #"grupo\s*(\d+)"#
        if let regex = try? NSRegularExpression(pattern: groupPattern),
           let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
           let range = Range(match.range(at: 1), in: normalized),
           let groupNum = Int(normalized[range]),
           groupNum >= 1 && groupNum <= 18 {
            let groupElements = Self.elements.filter { $0.group == groupNum }
            if !groupElements.isEmpty {
                return buildGroupResult(
                    groupName: "Grupo \(groupNum)",
                    elements: groupElements
                )
            }
        }

        // Check for "periodo N" pattern
        let periodPattern = #"periodo\s*(\d+)"#
        if let regex = try? NSRegularExpression(pattern: periodPattern),
           let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
           let range = Range(match.range(at: 1), in: normalized),
           let periodNum = Int(normalized[range]),
           periodNum >= 1 && periodNum <= 7 {
            let periodElements = Self.elements.filter { $0.period == periodNum }
            if !periodElements.isEmpty {
                return buildGroupResult(
                    groupName: "Periodo \(periodNum)",
                    elements: periodElements
                )
            }
        }

        return nil
    }

    // MARK: - Category Lookup

    private func solveCategoryLookup(_ normalized: String) -> InterceptorResult? {
        for alias in Self.categoryAliases {
            if normalized.contains(alias.keyword) {
                let categoryElements = Self.elements.filter { $0.category == alias.category }
                if !categoryElements.isEmpty {
                    return buildGroupResult(
                        groupName: alias.category,
                        elements: categoryElements
                    )
                }
            }
        }

        return nil
    }

    // MARK: - Result Builders

    private func buildElementResult(_ element: Element) -> InterceptorResult {
        let groupStr = element.group != nil ? "Grupo \(element.group!)" : element.category
        let answer = "\(element.nameSpanish) (\(element.symbol)) — Z=\(element.atomicNumber), Masa=\(formatMass(element.atomicMass)) u, \(groupStr), Periodo \(element.period), \(element.category)"

        return InterceptorResult(
            answer: answer,
            teacherInstruction: "[RESULTADO: \(element.nameSpanish) (\(element.symbol)), Z=\(element.atomicNumber), \(formatMass(element.atomicMass)) u] Explica las propiedades y usos principales de este elemento.",
            category: .catalogHit,
            attachmentType: "element_info",
            attachmentData: """
            {"symbol":"\(element.symbol)","name":"\(element.nameSpanish)","atomicNumber":\(element.atomicNumber),"atomicMass":\(formatMass(element.atomicMass)),"group":\(element.group.map { String($0) } ?? "null"),"period":\(element.period),"category":"\(element.category)","type":"element_lookup"}
            """,
            confidence: 1.0
        )
    }

    private func buildGroupResult(groupName: String, elements: [Element]) -> InterceptorResult {
        let elementList = elements.map { "\($0.nameSpanish) (\($0.symbol))" }.joined(separator: ", ")
        let preview = elements.prefix(6).map { "\($0.symbol)" }.joined(separator: ", ")
        let more = elements.count > 6 ? " y \(elements.count - 6) mas" : ""
        let answer = "\(groupName): \(elements.count) elementos — \(preview)\(more)"

        let elementsJSON = elements.map { el in
            "{\"symbol\":\"\(el.symbol)\",\"name\":\"\(el.nameSpanish)\",\"atomicNumber\":\(el.atomicNumber)}"
        }.joined(separator: ",")

        return InterceptorResult(
            answer: answer,
            teacherInstruction: "[RESULTADO: \(groupName), \(elements.count) elementos] Explica las propiedades comunes de este grupo y menciona los elementos: \(elementList).",
            category: .catalogHit,
            attachmentType: "element_info",
            attachmentData: """
            {"groupName":"\(groupName)","count":\(elements.count),"elements":[\(elementsJSON)],"type":"group_lookup"}
            """,
            confidence: 1.0
        )
    }

    // MARK: - Helpers

    private func normalize(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
            .replacingOccurrences(of: "¿", with: "")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "¡", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Normalize a key for dictionary lookup (lowercase, no diacritics).
    private static func normalizeKey(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
    }

    private func formatMass(_ mass: Double) -> String {
        if mass == mass.rounded(.down) && mass < 1e6 {
            return String(format: "%.0f", mass)
        }
        let formatted = String(format: "%.4f", mass)
        return formatted
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
    }
}
