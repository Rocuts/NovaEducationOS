import Foundation

// MARK: - PhysicsSolver
// Deterministic physics interceptor: constants lookup, formula computation,
// and unit conversions. "App decide, LLM ensena" — we compute the answer
// and let the teacher model explain it pedagogically.

struct PhysicsSolver: SubjectInterceptor, Sendable {

    let interceptorId = "physics_solver"
    let supportedSubjects: Set<Subject> = [.physics, .open]

    // MARK: - Physical Constant

    struct PhysicalConstant: Sendable {
        let name: String          // Spanish display name
        let symbol: String        // Standard symbol
        let value: Double         // Numeric value
        let valueDisplay: String  // Human-readable value with scientific notation
        let units: String         // SI units
        let aliases: [String]     // Normalized Spanish keywords for detection
    }

    // MARK: - Formula

    struct Formula: Sendable {
        let name: String          // Spanish name
        let expression: String    // e.g. "F = m × a"
        let variables: [String]   // Variable names used in regex extraction
        let compute: @Sendable ([String: Double]) -> Double?
    }

    // MARK: - UnitConversion

    struct UnitConversion: Sendable {
        let name: String
        let fromUnit: String
        let toUnit: String
        let aliases: [String]             // Detection keywords
        let convert: @Sendable (Double) -> Double
        let formatResult: @Sendable (Double, Double) -> String  // (input, output) -> display
    }

    // MARK: - Constants Catalog (~30)

    static let constants: [PhysicalConstant] = [
        PhysicalConstant(
            name: "Velocidad de la luz", symbol: "c",
            value: 299_792_458, valueDisplay: "299,792,458", units: "m/s",
            aliases: ["velocidad de la luz", "velocidad luz", "constante c", "cuanto vale c"]
        ),
        PhysicalConstant(
            name: "Aceleración gravitacional", symbol: "g",
            value: 9.80665, valueDisplay: "9.80665", units: "m/s\u{00B2}",
            aliases: ["gravedad", "aceleracion gravitacional", "aceleracion de la gravedad", "constante g", "cuanto vale g", "valor de g"]
        ),
        PhysicalConstant(
            name: "Constante de gravitación universal", symbol: "G",
            value: 6.674e-11, valueDisplay: "6.674\u{00D7}10\u{207B}\u{00B9}\u{00B9}", units: "N\u{00B7}m\u{00B2}/kg\u{00B2}",
            aliases: ["constante de gravitacion", "gravitacion universal", "constante gravitacional", "valor de g mayuscula"]
        ),
        PhysicalConstant(
            name: "Constante de Planck", symbol: "h",
            value: 6.626e-34, valueDisplay: "6.626\u{00D7}10\u{207B}\u{00B3}\u{2074}", units: "J\u{00B7}s",
            aliases: ["constante de planck", "planck", "constante h", "cuanto vale h"]
        ),
        PhysicalConstant(
            name: "Carga elemental", symbol: "e",
            value: 1.602e-19, valueDisplay: "1.602\u{00D7}10\u{207B}\u{00B9}\u{2079}", units: "C",
            aliases: ["carga elemental", "carga del electron", "carga electron", "carga electrica elemental"]
        ),
        PhysicalConstant(
            name: "Número de Avogadro", symbol: "N\u{2090}",
            value: 6.022e23, valueDisplay: "6.022\u{00D7}10\u{00B2}\u{00B3}", units: "mol\u{207B}\u{00B9}",
            aliases: ["avogadro", "numero de avogadro", "constante de avogadro"]
        ),
        PhysicalConstant(
            name: "Constante de Boltzmann", symbol: "k",
            value: 1.381e-23, valueDisplay: "1.381\u{00D7}10\u{207B}\u{00B2}\u{00B3}", units: "J/K",
            aliases: ["constante de boltzmann", "boltzmann", "constante k"]
        ),
        PhysicalConstant(
            name: "Constante de los gases ideales", symbol: "R",
            value: 8.314, valueDisplay: "8.314", units: "J/(mol\u{00B7}K)",
            aliases: ["constante de los gases", "gases ideales", "constante r", "cuanto vale r"]
        ),
        PhysicalConstant(
            name: "Constante de Stefan-Boltzmann", symbol: "\u{03C3}",
            value: 5.670e-8, valueDisplay: "5.670\u{00D7}10\u{207B}\u{2078}", units: "W/(m\u{00B2}\u{00B7}K\u{2074})",
            aliases: ["stefan-boltzmann", "stefan boltzmann", "constante de stefan"]
        ),
        PhysicalConstant(
            name: "Permitividad del vacío", symbol: "\u{03B5}\u{2080}",
            value: 8.854e-12, valueDisplay: "8.854\u{00D7}10\u{207B}\u{00B9}\u{00B2}", units: "F/m",
            aliases: ["permitividad del vacio", "permitividad electrica", "epsilon cero", "constante dielectrica del vacio"]
        ),
        PhysicalConstant(
            name: "Permeabilidad del vacío", symbol: "\u{03BC}\u{2080}",
            value: 1.257e-6, valueDisplay: "1.257\u{00D7}10\u{207B}\u{2076}", units: "H/m",
            aliases: ["permeabilidad del vacio", "permeabilidad magnetica", "mu cero"]
        ),
        PhysicalConstant(
            name: "Masa del electrón", symbol: "m\u{2091}",
            value: 9.109e-31, valueDisplay: "9.109\u{00D7}10\u{207B}\u{00B3}\u{00B9}", units: "kg",
            aliases: ["masa del electron", "masa electron", "peso del electron"]
        ),
        PhysicalConstant(
            name: "Masa del protón", symbol: "m\u{209A}",
            value: 1.673e-27, valueDisplay: "1.673\u{00D7}10\u{207B}\u{00B2}\u{2077}", units: "kg",
            aliases: ["masa del proton", "masa proton", "peso del proton"]
        ),
        PhysicalConstant(
            name: "Masa del neutrón", symbol: "m\u{2099}",
            value: 1.675e-27, valueDisplay: "1.675\u{00D7}10\u{207B}\u{00B2}\u{2077}", units: "kg",
            aliases: ["masa del neutron", "masa neutron", "peso del neutron"]
        ),
        PhysicalConstant(
            name: "Presión atmosférica estándar", symbol: "P\u{2090}\u{209C}\u{2098}",
            value: 101_325, valueDisplay: "101,325", units: "Pa",
            aliases: ["presion atmosferica", "atmosfera estandar", "presion normal", "1 atmosfera", "una atmosfera"]
        ),
        PhysicalConstant(
            name: "Velocidad del sonido en el aire", symbol: "v\u{209B}",
            value: 343, valueDisplay: "343", units: "m/s",
            aliases: ["velocidad del sonido", "velocidad sonido", "rapidez del sonido"]
        ),
        PhysicalConstant(
            name: "Constante de Coulomb", symbol: "k\u{2091}",
            value: 8.988e9, valueDisplay: "8.988\u{00D7}10\u{2079}", units: "N\u{00B7}m\u{00B2}/C\u{00B2}",
            aliases: ["constante de coulomb", "coulomb", "constante electrica"]
        ),
        PhysicalConstant(
            name: "Constante de Faraday", symbol: "F",
            value: 96_485, valueDisplay: "96,485", units: "C/mol",
            aliases: ["constante de faraday", "faraday"]
        ),
        PhysicalConstant(
            name: "Impedancia del vacío", symbol: "Z\u{2080}",
            value: 376.73, valueDisplay: "376.73", units: "\u{2126}",
            aliases: ["impedancia del vacio", "impedancia caracteristica del vacio"]
        ),
        PhysicalConstant(
            name: "Radio de Bohr", symbol: "a\u{2080}",
            value: 5.292e-11, valueDisplay: "5.292\u{00D7}10\u{207B}\u{00B9}\u{00B9}", units: "m",
            aliases: ["radio de bohr", "bohr"]
        ),
        PhysicalConstant(
            name: "Constante de Rydberg", symbol: "R\u{221E}",
            value: 1.097e7, valueDisplay: "1.097\u{00D7}10\u{2077}", units: "m\u{207B}\u{00B9}",
            aliases: ["constante de rydberg", "rydberg"]
        ),
        PhysicalConstant(
            name: "Unidad de masa atómica", symbol: "u",
            value: 1.661e-27, valueDisplay: "1.661\u{00D7}10\u{207B}\u{00B2}\u{2077}", units: "kg",
            aliases: ["unidad de masa atomica", "uma", "dalton"]
        ),
        PhysicalConstant(
            name: "Electronvoltio", symbol: "eV",
            value: 1.602e-19, valueDisplay: "1.602\u{00D7}10\u{207B}\u{00B9}\u{2079}", units: "J",
            aliases: ["electronvoltio", "electronvolt", "cuanto es un ev", "valor de un ev"]
        ),
        PhysicalConstant(
            name: "Año luz", symbol: "ly",
            value: 9.461e15, valueDisplay: "9.461\u{00D7}10\u{00B9}\u{2075}", units: "m",
            aliases: ["ano luz", "ano de luz", "cuanto mide un ano luz"]
        ),
        PhysicalConstant(
            name: "Unidad astronómica", symbol: "UA",
            value: 1.496e11, valueDisplay: "1.496\u{00D7}10\u{00B9}\u{00B9}", units: "m",
            aliases: ["unidad astronomica", "distancia tierra sol"]
        ),
        PhysicalConstant(
            name: "Cero absoluto", symbol: "0 K",
            value: -273.15, valueDisplay: "-273.15", units: "\u{00B0}C",
            aliases: ["cero absoluto", "temperatura minima", "0 kelvin"]
        ),
        PhysicalConstant(
            name: "Constante de Wien", symbol: "b",
            value: 2.898e-3, valueDisplay: "2.898\u{00D7}10\u{207B}\u{00B3}", units: "m\u{00B7}K",
            aliases: ["constante de wien", "wien", "ley de desplazamiento"]
        ),
        PhysicalConstant(
            name: "Número áureo", symbol: "\u{03C6}",
            value: 1.6180339887, valueDisplay: "1.6180339887", units: "(adimensional)",
            aliases: ["numero aureo", "proporcion aurea", "razon aurea", "phi"]
        ),
        PhysicalConstant(
            name: "Aceleración lunar", symbol: "g\u{2098}\u{2092}\u{2092}\u{2099}",
            value: 1.625, valueDisplay: "1.625", units: "m/s\u{00B2}",
            aliases: ["gravedad en la luna", "gravedad lunar", "aceleracion lunar", "gravedad de la luna"]
        ),
    ]

    // MARK: - Formulas Catalog (~20)

    static let formulas: [Formula] = [
        // --- Mechanics ---
        Formula(
            name: "Fuerza (Segunda ley de Newton)",
            expression: "F = m \u{00D7} a",
            variables: ["m", "a"],
            compute: { vars in
                guard let m = vars["m"], let a = vars["a"] else { return nil }
                return m * a
            }
        ),
        Formula(
            name: "Velocidad",
            expression: "v = d / t",
            variables: ["d", "t"],
            compute: { vars in
                guard let d = vars["d"], let t = vars["t"], t != 0 else { return nil }
                return d / t
            }
        ),
        Formula(
            name: "Momento lineal",
            expression: "p = m \u{00D7} v",
            variables: ["m", "v"],
            compute: { vars in
                guard let m = vars["m"], let v = vars["v"] else { return nil }
                return m * v
            }
        ),
        Formula(
            name: "Energía cinética",
            expression: "E\u{2096} = \u{00BD}mv\u{00B2}",
            variables: ["m", "v"],
            compute: { vars in
                guard let m = vars["m"], let v = vars["v"] else { return nil }
                return 0.5 * m * v * v
            }
        ),
        Formula(
            name: "Energía potencial gravitatoria",
            expression: "E\u{209A} = mgh",
            variables: ["m", "h"],
            compute: { vars in
                guard let m = vars["m"], let h = vars["h"] else { return nil }
                return m * 9.80665 * h
            }
        ),
        Formula(
            name: "Trabajo",
            expression: "W = F \u{00D7} d",
            variables: ["f", "d"],
            compute: { vars in
                guard let f = vars["f"], let d = vars["d"] else { return nil }
                return f * d
            }
        ),
        // --- Electricity ---
        Formula(
            name: "Ley de Ohm",
            expression: "V = I \u{00D7} R",
            variables: ["i", "r"],
            compute: { vars in
                guard let i = vars["i"], let r = vars["r"] else { return nil }
                return i * r
            }
        ),
        Formula(
            name: "Potencia eléctrica",
            expression: "P = I \u{00D7} V",
            variables: ["i", "v"],
            compute: { vars in
                guard let i = vars["i"], let v = vars["v"] else { return nil }
                return i * v
            }
        ),
        Formula(
            name: "Campo eléctrico",
            expression: "E = k\u{2091}q / r\u{00B2}",
            variables: ["q", "r"],
            compute: { vars in
                guard let q = vars["q"], let r = vars["r"], r != 0 else { return nil }
                return 8.988e9 * q / (r * r)
            }
        ),
        // --- Waves ---
        Formula(
            name: "Velocidad de onda",
            expression: "v = f \u{00D7} \u{03BB}",
            variables: ["f", "lambda"],
            compute: { vars in
                guard let f = vars["f"], let lambda = vars["lambda"] else { return nil }
                return f * lambda
            }
        ),
        Formula(
            name: "Periodo",
            expression: "T = 1 / f",
            variables: ["f"],
            compute: { vars in
                guard let f = vars["f"], f != 0 else { return nil }
                return 1.0 / f
            }
        ),
        // --- Thermodynamics ---
        Formula(
            name: "Calor",
            expression: "Q = mc\u{0394}T",
            variables: ["m", "c", "dt"],
            compute: { vars in
                guard let m = vars["m"], let c = vars["c"], let dt = vars["dt"] else { return nil }
                return m * c * dt
            }
        ),
        // --- Kinematics ---
        Formula(
            name: "Velocidad final (MRUA)",
            expression: "v = v\u{2080} + at",
            variables: ["v0", "a", "t"],
            compute: { vars in
                guard let v0 = vars["v0"], let a = vars["a"], let t = vars["t"] else { return nil }
                return v0 + a * t
            }
        ),
        Formula(
            name: "Distancia (MRUA)",
            expression: "d = v\u{2080}t + \u{00BD}at\u{00B2}",
            variables: ["v0", "a", "t"],
            compute: { vars in
                guard let v0 = vars["v0"], let a = vars["a"], let t = vars["t"] else { return nil }
                return v0 * t + 0.5 * a * t * t
            }
        ),
        // --- Pressure ---
        Formula(
            name: "Presión",
            expression: "P = F / A",
            variables: ["f", "a"],
            compute: { vars in
                guard let f = vars["f"], let a = vars["a"], a != 0 else { return nil }
                return f / a
            }
        ),
        // --- Density ---
        Formula(
            name: "Densidad",
            expression: "\u{03C1} = m / V",
            variables: ["m", "v"],
            compute: { vars in
                guard let m = vars["m"], let v = vars["v"], v != 0 else { return nil }
                return m / v
            }
        ),
        // --- Gravitational Force ---
        Formula(
            name: "Fuerza gravitatoria (Newton)",
            expression: "F = Gm\u{2081}m\u{2082}/r\u{00B2}",
            variables: ["m1", "m2", "r"],
            compute: { vars in
                guard let m1 = vars["m1"], let m2 = vars["m2"], let r = vars["r"], r != 0 else { return nil }
                return 6.674e-11 * m1 * m2 / (r * r)
            }
        ),
        // --- Coulomb's Law ---
        Formula(
            name: "Fuerza de Coulomb",
            expression: "F = k\u{2091}q\u{2081}q\u{2082}/r\u{00B2}",
            variables: ["q1", "q2", "r"],
            compute: { vars in
                guard let q1 = vars["q1"], let q2 = vars["q2"], let r = vars["r"], r != 0 else { return nil }
                return 8.988e9 * q1 * q2 / (r * r)
            }
        ),
        // --- Weight ---
        Formula(
            name: "Peso",
            expression: "W = mg",
            variables: ["m"],
            compute: { vars in
                guard let m = vars["m"] else { return nil }
                return m * 9.80665
            }
        ),
        // --- Frequency from period ---
        Formula(
            name: "Frecuencia",
            expression: "f = 1 / T",
            variables: ["t"],
            compute: { vars in
                guard let t = vars["t"], t != 0 else { return nil }
                return 1.0 / t
            }
        ),
    ]

    // MARK: - Unit Conversions

    static let unitConversions: [UnitConversion] = [
        // Length
        UnitConversion(
            name: "Kilómetros a metros", fromUnit: "km", toUnit: "m",
            aliases: ["km a m", "kilometros a metros", "convierte km a m"],
            convert: { $0 * 1000 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) km = \(PhysicsSolver.fmt(output)) m" }
        ),
        UnitConversion(
            name: "Metros a kilómetros", fromUnit: "m", toUnit: "km",
            aliases: ["m a km", "metros a kilometros", "convierte m a km"],
            convert: { $0 / 1000 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) m = \(PhysicsSolver.fmt(output)) km" }
        ),
        UnitConversion(
            name: "Centímetros a metros", fromUnit: "cm", toUnit: "m",
            aliases: ["cm a m", "centimetros a metros"],
            convert: { $0 / 100 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) cm = \(PhysicsSolver.fmt(output)) m" }
        ),
        UnitConversion(
            name: "Metros a centímetros", fromUnit: "m", toUnit: "cm",
            aliases: ["m a cm", "metros a centimetros"],
            convert: { $0 * 100 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) m = \(PhysicsSolver.fmt(output)) cm" }
        ),
        UnitConversion(
            name: "Millas a kilómetros", fromUnit: "mi", toUnit: "km",
            aliases: ["millas a kilometros", "millas a km", "mi a km"],
            convert: { $0 * 1.60934 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) mi = \(PhysicsSolver.fmt(output)) km" }
        ),
        UnitConversion(
            name: "Kilómetros a millas", fromUnit: "km", toUnit: "mi",
            aliases: ["kilometros a millas", "km a millas", "km a mi"],
            convert: { $0 / 1.60934 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) km = \(PhysicsSolver.fmt(output)) mi" }
        ),
        UnitConversion(
            name: "Pulgadas a centímetros", fromUnit: "in", toUnit: "cm",
            aliases: ["pulgadas a centimetros", "pulgadas a cm"],
            convert: { $0 * 2.54 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) in = \(PhysicsSolver.fmt(output)) cm" }
        ),
        UnitConversion(
            name: "Pies a metros", fromUnit: "ft", toUnit: "m",
            aliases: ["pies a metros", "ft a m"],
            convert: { $0 * 0.3048 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) ft = \(PhysicsSolver.fmt(output)) m" }
        ),
        // Mass
        UnitConversion(
            name: "Kilogramos a gramos", fromUnit: "kg", toUnit: "g",
            aliases: ["kg a g", "kilogramos a gramos", "kilos a gramos"],
            convert: { $0 * 1000 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) kg = \(PhysicsSolver.fmt(output)) g" }
        ),
        UnitConversion(
            name: "Gramos a kilogramos", fromUnit: "g", toUnit: "kg",
            aliases: ["g a kg", "gramos a kilogramos", "gramos a kilos"],
            convert: { $0 / 1000 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) g = \(PhysicsSolver.fmt(output)) kg" }
        ),
        UnitConversion(
            name: "Libras a kilogramos", fromUnit: "lb", toUnit: "kg",
            aliases: ["libras a kilogramos", "libras a kilos", "lb a kg"],
            convert: { $0 * 0.453592 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) lb = \(PhysicsSolver.fmt(output)) kg" }
        ),
        UnitConversion(
            name: "Kilogramos a libras", fromUnit: "kg", toUnit: "lb",
            aliases: ["kilogramos a libras", "kilos a libras", "kg a lb"],
            convert: { $0 / 0.453592 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) kg = \(PhysicsSolver.fmt(output)) lb" }
        ),
        // Temperature
        UnitConversion(
            name: "Celsius a Fahrenheit", fromUnit: "\u{00B0}C", toUnit: "\u{00B0}F",
            aliases: ["celsius a fahrenheit", "c a f", "grados celsius a fahrenheit", "de celsius a fahrenheit"],
            convert: { $0 * 9.0 / 5.0 + 32.0 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) \u{00B0}C = \(PhysicsSolver.fmt(output)) \u{00B0}F" }
        ),
        UnitConversion(
            name: "Fahrenheit a Celsius", fromUnit: "\u{00B0}F", toUnit: "\u{00B0}C",
            aliases: ["fahrenheit a celsius", "f a c", "grados fahrenheit a celsius", "de fahrenheit a celsius"],
            convert: { ($0 - 32.0) * 5.0 / 9.0 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) \u{00B0}F = \(PhysicsSolver.fmt(output)) \u{00B0}C" }
        ),
        UnitConversion(
            name: "Celsius a Kelvin", fromUnit: "\u{00B0}C", toUnit: "K",
            aliases: ["celsius a kelvin", "c a k", "grados celsius a kelvin", "de celsius a kelvin"],
            convert: { $0 + 273.15 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) \u{00B0}C = \(PhysicsSolver.fmt(output)) K" }
        ),
        UnitConversion(
            name: "Kelvin a Celsius", fromUnit: "K", toUnit: "\u{00B0}C",
            aliases: ["kelvin a celsius", "k a c", "de kelvin a celsius"],
            convert: { $0 - 273.15 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) K = \(PhysicsSolver.fmt(output)) \u{00B0}C" }
        ),
        UnitConversion(
            name: "Fahrenheit a Kelvin", fromUnit: "\u{00B0}F", toUnit: "K",
            aliases: ["fahrenheit a kelvin", "f a k", "de fahrenheit a kelvin"],
            convert: { ($0 - 32.0) * 5.0 / 9.0 + 273.15 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) \u{00B0}F = \(PhysicsSolver.fmt(output)) K" }
        ),
        // Speed
        UnitConversion(
            name: "km/h a m/s", fromUnit: "km/h", toUnit: "m/s",
            aliases: ["km/h a m/s", "kilometros por hora a metros por segundo", "kmh a ms"],
            convert: { $0 / 3.6 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) km/h = \(PhysicsSolver.fmt(output)) m/s" }
        ),
        UnitConversion(
            name: "m/s a km/h", fromUnit: "m/s", toUnit: "km/h",
            aliases: ["m/s a km/h", "metros por segundo a kilometros por hora", "ms a kmh"],
            convert: { $0 * 3.6 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) m/s = \(PhysicsSolver.fmt(output)) km/h" }
        ),
        UnitConversion(
            name: "mph a km/h", fromUnit: "mph", toUnit: "km/h",
            aliases: ["mph a km/h", "millas por hora a kilometros por hora", "mph a kmh"],
            convert: { $0 * 1.60934 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) mph = \(PhysicsSolver.fmt(output)) km/h" }
        ),
        UnitConversion(
            name: "km/h a mph", fromUnit: "km/h", toUnit: "mph",
            aliases: ["km/h a mph", "kilometros por hora a millas por hora", "kmh a mph"],
            convert: { $0 / 1.60934 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) km/h = \(PhysicsSolver.fmt(output)) mph" }
        ),
        // Pressure
        UnitConversion(
            name: "Atmósferas a Pascales", fromUnit: "atm", toUnit: "Pa",
            aliases: ["atm a pa", "atmosferas a pascales", "atm a pascales"],
            convert: { $0 * 101_325 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) atm = \(PhysicsSolver.fmt(output)) Pa" }
        ),
        UnitConversion(
            name: "Pascales a atmósferas", fromUnit: "Pa", toUnit: "atm",
            aliases: ["pa a atm", "pascales a atmosferas"],
            convert: { $0 / 101_325 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) Pa = \(PhysicsSolver.fmt(output)) atm" }
        ),
        // Energy
        UnitConversion(
            name: "Julios a calorías", fromUnit: "J", toUnit: "cal",
            aliases: ["julios a calorias", "joules a calorias", "j a cal"],
            convert: { $0 / 4.184 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) J = \(PhysicsSolver.fmt(output)) cal" }
        ),
        UnitConversion(
            name: "Calorías a julios", fromUnit: "cal", toUnit: "J",
            aliases: ["calorias a julios", "calorias a joules", "cal a j"],
            convert: { $0 * 4.184 },
            formatResult: { input, output in "\(PhysicsSolver.fmt(input)) cal = \(PhysicsSolver.fmt(output)) J" }
        ),
    ]

    // MARK: - Detection

    func detect(_ text: String, subject: Subject) -> Bool {
        let normalized = normalize(text)

        let hasConstantQuery = Self.constantKeywords.contains { normalized.contains($0) }
        let hasFormulaPattern = Self.formulaKeywords.contains { normalized.contains($0) }
        let hasConversionKeyword = Self.conversionKeywords.contains { normalized.contains($0) }
        let hasPhysicsVerb = Self.physicsVerbs.contains { normalized.contains($0) }
        let hasVariableAssignment = Self.variablePattern.firstMatch(
            in: normalized,
            range: NSRange(normalized.startIndex..., in: normalized)
        ) != nil

        return hasConstantQuery || hasFormulaPattern || hasConversionKeyword
            || hasPhysicsVerb || hasVariableAssignment
    }

    // MARK: - Solve

    func solve(_ text: String, subject: Subject) async -> InterceptorResult {
        let normalized = normalize(text)

        // 1. Constants catalog lookup
        if let result = solveConstant(normalized) { return result }

        // 2. Formula computation
        if let result = solveFormula(normalized, originalText: text) { return result }

        // 3. Unit conversions
        if let result = solveConversion(normalized) { return result }

        return .passthrough(text)
    }

    // MARK: - Constant Lookup

    private func solveConstant(_ text: String) -> InterceptorResult? {
        for constant in Self.constants {
            let matched = constant.aliases.contains { text.contains($0) }
            guard matched else { continue }

            let answer = "\(constant.symbol) = \(constant.valueDisplay) \(constant.units)"

            return InterceptorResult(
                answer: answer,
                teacherInstruction: "[RESULTADO: \(answer)] Explica qué es \(constant.name.lowercased()), su significado físico y en qué contextos se utiliza.",
                category: .catalogHit,
                attachmentType: "formula_result",
                attachmentData: """
                {"symbol":"\(constant.symbol)","value":"\(constant.valueDisplay)","units":"\(constant.units)","name":"\(constant.name)","type":"physical_constant"}
                """,
                confidence: 1.0
            )
        }
        return nil
    }

    // MARK: - Formula Computation

    private func solveFormula(_ text: String, originalText: String) -> InterceptorResult? {
        // Try to extract variable assignments: "m=10", "a=5", "v0=3"
        let vars = extractVariables(text)
        guard !vars.isEmpty else { return nil }

        // Detect which formula the student is asking about
        if let result = tryForceFormula(text, vars: vars) { return result }
        if let result = tryVelocityFormula(text, vars: vars) { return result }
        if let result = tryMomentumFormula(text, vars: vars) { return result }
        if let result = tryKineticEnergyFormula(text, vars: vars) { return result }
        if let result = tryPotentialEnergyFormula(text, vars: vars) { return result }
        if let result = tryWorkFormula(text, vars: vars) { return result }
        if let result = tryOhmLaw(text, vars: vars) { return result }
        if let result = tryElectricPower(text, vars: vars) { return result }
        if let result = tryWaveVelocity(text, vars: vars) { return result }
        if let result = tryPeriodFormula(text, vars: vars) { return result }
        if let result = tryHeatFormula(text, vars: vars) { return result }
        if let result = tryKinematicsVelocity(text, vars: vars) { return result }
        if let result = tryKinematicsDistance(text, vars: vars) { return result }
        if let result = tryPressureFormula(text, vars: vars) { return result }
        if let result = tryDensityFormula(text, vars: vars) { return result }
        if let result = tryWeightFormula(text, vars: vars) { return result }

        // If we have variables but couldn't match a formula, try matching by variable set
        if let result = tryAutoMatchFormula(vars) { return result }

        return nil
    }

    // MARK: - Individual Formula Matchers

    private func tryForceFormula(_ text: String, vars: [String: Double]) -> InterceptorResult? {
        let keywords = ["fuerza", "f=ma", "f = ma", "segunda ley", "newton"]
        guard keywords.contains(where: { text.contains($0) }),
              let m = vars["m"], let a = vars["a"] else { return nil }
        let result = m * a
        return formulaResult(name: "Fuerza (F = m \u{00D7} a)", answer: "F = \(fmt(result)) N",
                             detail: "m = \(fmt(m)) kg, a = \(fmt(a)) m/s\u{00B2}", result: result, unit: "N")
    }

    private func tryVelocityFormula(_ text: String, vars: [String: Double]) -> InterceptorResult? {
        let keywords = ["velocidad", "rapidez", "v=d/t", "v = d/t"]
        guard keywords.contains(where: { text.contains($0) }),
              let d = vars["d"], let t = vars["t"], t != 0 else { return nil }
        let result = d / t
        return formulaResult(name: "Velocidad (v = d / t)", answer: "v = \(fmt(result)) m/s",
                             detail: "d = \(fmt(d)) m, t = \(fmt(t)) s", result: result, unit: "m/s")
    }

    private func tryMomentumFormula(_ text: String, vars: [String: Double]) -> InterceptorResult? {
        let keywords = ["momento", "momentum", "cantidad de movimiento", "p=mv", "p = mv"]
        guard keywords.contains(where: { text.contains($0) }),
              let m = vars["m"], let v = vars["v"] else { return nil }
        let result = m * v
        return formulaResult(name: "Momento lineal (p = m \u{00D7} v)", answer: "p = \(fmt(result)) kg\u{00B7}m/s",
                             detail: "m = \(fmt(m)) kg, v = \(fmt(v)) m/s", result: result, unit: "kg\u{00B7}m/s")
    }

    private func tryKineticEnergyFormula(_ text: String, vars: [String: Double]) -> InterceptorResult? {
        let keywords = ["energia cinetica", "ec=", "ec =", "cinetica"]
        guard keywords.contains(where: { text.contains($0) }),
              let m = vars["m"], let v = vars["v"] else { return nil }
        let result = 0.5 * m * v * v
        return formulaResult(name: "Energía cinética (E\u{2096} = \u{00BD}mv\u{00B2})",
                             answer: "E\u{2096} = \(fmt(result)) J",
                             detail: "m = \(fmt(m)) kg, v = \(fmt(v)) m/s", result: result, unit: "J")
    }

    private func tryPotentialEnergyFormula(_ text: String, vars: [String: Double]) -> InterceptorResult? {
        let keywords = ["energia potencial", "ep=", "ep =", "potencial gravitatoria"]
        guard keywords.contains(where: { text.contains($0) }),
              let m = vars["m"], let h = vars["h"] else { return nil }
        let g = vars["g"] ?? 9.80665
        let result = m * g * h
        return formulaResult(name: "Energía potencial (E\u{209A} = mgh)",
                             answer: "E\u{209A} = \(fmt(result)) J",
                             detail: "m = \(fmt(m)) kg, g = \(fmt(g)) m/s\u{00B2}, h = \(fmt(h)) m",
                             result: result, unit: "J")
    }

    private func tryWorkFormula(_ text: String, vars: [String: Double]) -> InterceptorResult? {
        let keywords = ["trabajo", "w=fd", "w = fd", "w=f*d", "w = f*d"]
        guard keywords.contains(where: { text.contains($0) }),
              let f = vars["f"], let d = vars["d"] else { return nil }
        let result = f * d
        return formulaResult(name: "Trabajo (W = F \u{00D7} d)", answer: "W = \(fmt(result)) J",
                             detail: "F = \(fmt(f)) N, d = \(fmt(d)) m", result: result, unit: "J")
    }

    private func tryOhmLaw(_ text: String, vars: [String: Double]) -> InterceptorResult? {
        let keywords = ["ohm", "v=ir", "v = ir", "ley de ohm", "voltaje"]
        guard keywords.contains(where: { text.contains($0) }),
              let i = vars["i"], let r = vars["r"] else { return nil }
        let result = i * r
        return formulaResult(name: "Ley de Ohm (V = I \u{00D7} R)", answer: "V = \(fmt(result)) V",
                             detail: "I = \(fmt(i)) A, R = \(fmt(r)) \u{2126}", result: result, unit: "V")
    }

    private func tryElectricPower(_ text: String, vars: [String: Double]) -> InterceptorResult? {
        let keywords = ["potencia electrica", "p=iv", "p = iv", "potencia"]
        guard keywords.contains(where: { text.contains($0) }),
              let i = vars["i"], let v = vars["v"] else { return nil }
        let result = i * v
        return formulaResult(name: "Potencia eléctrica (P = I \u{00D7} V)", answer: "P = \(fmt(result)) W",
                             detail: "I = \(fmt(i)) A, V = \(fmt(v)) V", result: result, unit: "W")
    }

    private func tryWaveVelocity(_ text: String, vars: [String: Double]) -> InterceptorResult? {
        let keywords = ["velocidad de onda", "v=f*lambda", "v=f*l", "onda"]
        let lambda = vars["lambda"] ?? vars["l"]
        guard keywords.contains(where: { text.contains($0) }),
              let f = vars["f"], let lam = lambda else { return nil }
        let result = f * lam
        return formulaResult(name: "Velocidad de onda (v = f \u{00D7} \u{03BB})",
                             answer: "v = \(fmt(result)) m/s",
                             detail: "f = \(fmt(f)) Hz, \u{03BB} = \(fmt(lam)) m", result: result, unit: "m/s")
    }

    private func tryPeriodFormula(_ text: String, vars: [String: Double]) -> InterceptorResult? {
        let keywords = ["periodo", "t=1/f", "t = 1/f"]
        guard keywords.contains(where: { text.contains($0) }),
              let f = vars["f"], f != 0 else { return nil }
        let result = 1.0 / f
        return formulaResult(name: "Periodo (T = 1 / f)", answer: "T = \(fmt(result)) s",
                             detail: "f = \(fmt(f)) Hz", result: result, unit: "s")
    }

    private func tryHeatFormula(_ text: String, vars: [String: Double]) -> InterceptorResult? {
        let keywords = ["calor", "q=mc", "q = mc", "transferencia de calor"]
        guard keywords.contains(where: { text.contains($0) }),
              let m = vars["m"], let c = vars["c"], let dt = vars["dt"] ?? vars["t"] else { return nil }
        let result = m * c * dt
        return formulaResult(name: "Calor (Q = mc\u{0394}T)", answer: "Q = \(fmt(result)) J",
                             detail: "m = \(fmt(m)) kg, c = \(fmt(c)) J/(kg\u{00B7}K), \u{0394}T = \(fmt(dt)) K",
                             result: result, unit: "J")
    }

    private func tryKinematicsVelocity(_ text: String, vars: [String: Double]) -> InterceptorResult? {
        let keywords = ["velocidad final", "v=v0+at", "v = v0 + at", "mrua", "acelerado"]
        guard keywords.contains(where: { text.contains($0) }),
              let v0 = vars["v0"], let a = vars["a"], let t = vars["t"] else { return nil }
        let result = v0 + a * t
        return formulaResult(name: "Velocidad final MRUA (v = v\u{2080} + at)",
                             answer: "v = \(fmt(result)) m/s",
                             detail: "v\u{2080} = \(fmt(v0)) m/s, a = \(fmt(a)) m/s\u{00B2}, t = \(fmt(t)) s",
                             result: result, unit: "m/s")
    }

    private func tryKinematicsDistance(_ text: String, vars: [String: Double]) -> InterceptorResult? {
        let keywords = ["distancia", "desplazamiento", "d=v0t", "d = v0t", "posicion"]
        guard keywords.contains(where: { text.contains($0) }),
              let v0 = vars["v0"], let a = vars["a"], let t = vars["t"] else { return nil }
        let result = v0 * t + 0.5 * a * t * t
        return formulaResult(name: "Distancia MRUA (d = v\u{2080}t + \u{00BD}at\u{00B2})",
                             answer: "d = \(fmt(result)) m",
                             detail: "v\u{2080} = \(fmt(v0)) m/s, a = \(fmt(a)) m/s\u{00B2}, t = \(fmt(t)) s",
                             result: result, unit: "m")
    }

    private func tryPressureFormula(_ text: String, vars: [String: Double]) -> InterceptorResult? {
        let keywords = ["presion", "p=f/a", "p = f/a"]
        guard keywords.contains(where: { text.contains($0) }),
              let f = vars["f"], let a = vars["a"], a != 0 else { return nil }
        let result = f / a
        return formulaResult(name: "Presión (P = F / A)", answer: "P = \(fmt(result)) Pa",
                             detail: "F = \(fmt(f)) N, A = \(fmt(a)) m\u{00B2}", result: result, unit: "Pa")
    }

    private func tryDensityFormula(_ text: String, vars: [String: Double]) -> InterceptorResult? {
        let keywords = ["densidad", "rho", "p=m/v"]
        guard keywords.contains(where: { text.contains($0) }),
              let m = vars["m"], let v = vars["v"], v != 0 else { return nil }
        let result = m / v
        return formulaResult(name: "Densidad (\u{03C1} = m / V)", answer: "\u{03C1} = \(fmt(result)) kg/m\u{00B3}",
                             detail: "m = \(fmt(m)) kg, V = \(fmt(v)) m\u{00B3}", result: result, unit: "kg/m\u{00B3}")
    }

    private func tryWeightFormula(_ text: String, vars: [String: Double]) -> InterceptorResult? {
        let keywords = ["peso", "w=mg", "w = mg", "cuanto pesa"]
        guard keywords.contains(where: { text.contains($0) }),
              let m = vars["m"] else { return nil }
        let g = vars["g"] ?? 9.80665
        let result = m * g
        return formulaResult(name: "Peso (W = mg)", answer: "W = \(fmt(result)) N",
                             detail: "m = \(fmt(m)) kg, g = \(fmt(g)) m/s\u{00B2}", result: result, unit: "N")
    }

    /// Auto-match: if the extracted variables exactly match a formula's variable set
    private func tryAutoMatchFormula(_ vars: [String: Double]) -> InterceptorResult? {
        let varKeys = Set(vars.keys)

        for formula in Self.formulas {
            let formulaVars = Set(formula.variables)
            guard formulaVars.isSubset(of: varKeys),
                  let result = formula.compute(vars),
                  result.isFinite else { continue }

            let varsDescription = formula.variables
                .compactMap { key in vars[key].map { "\(key) = \(fmt($0))" } }
                .joined(separator: ", ")

            return InterceptorResult(
                answer: "\(formula.name): \(fmt(result))",
                teacherInstruction: "[RESULTADO: \(formula.expression) = \(fmt(result))] Con \(varsDescription). Explica el procedimiento y el significado físico del resultado.",
                category: .computed,
                attachmentType: "formula_result",
                attachmentData: """
                {"formula":"\(formula.expression)","result":"\(fmt(result))","variables":"\(varsDescription)","name":"\(formula.name)","type":"physics_formula"}
                """,
                confidence: 0.85
            )
        }
        return nil
    }

    // MARK: - Unit Conversion

    private func solveConversion(_ text: String) -> InterceptorResult? {
        // Pattern: N [unit] a [unit]  or  convierte N [unit] a [unit]
        // Also: cuantos metros son 5 km

        for conversion in Self.unitConversions {
            let matched = conversion.aliases.contains { text.contains($0) }
            guard matched else { continue }

            // Extract the numeric value
            guard let value = extractConversionValue(text) else { continue }

            let result = conversion.convert(value)
            guard result.isFinite else { continue }

            let answer = conversion.formatResult(value, result)

            return InterceptorResult(
                answer: answer,
                teacherInstruction: "[RESULTADO: \(answer)] Explica la relación entre \(conversion.fromUnit) y \(conversion.toUnit), y cómo se realiza la conversión.",
                category: .computed,
                attachmentType: "formula_result",
                attachmentData: """
                {"from_value":\(fmt(value)),"from_unit":"\(conversion.fromUnit)","to_value":"\(fmt(result))","to_unit":"\(conversion.toUnit)","name":"\(conversion.name)","type":"unit_conversion"}
                """,
                confidence: 0.95
            )
        }

        // Try generic "cuantos X son Y Z" pattern
        if let result = solveGenericConversion(text) { return result }

        return nil
    }

    private func solveGenericConversion(_ text: String) -> InterceptorResult? {
        // "cuantos metros son 5 kilometros" / "cuantos km son 100 m"
        let pattern = #"cuant[oa]s?\s+(\w+)\s+(?:son|hay en|tiene)\s+(\d+\.?\d*)\s+(\w+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }

        func group(_ i: Int) -> String? {
            guard let range = Range(match.range(at: i), in: text) else { return nil }
            return String(text[range])
        }

        guard let toUnitWord = group(1),
              let valueStr = group(2),
              let fromUnitWord = group(3),
              let value = Double(valueStr) else { return nil }

        // Find a matching conversion based on unit words
        let fromNorm = normalizeUnitWord(fromUnitWord)
        let toNorm = normalizeUnitWord(toUnitWord)

        for conversion in Self.unitConversions {
            let fromMatch = normalizeUnitWord(conversion.fromUnit) == fromNorm
                || conversion.name.lowercased().contains(fromNorm)
            let toMatch = normalizeUnitWord(conversion.toUnit) == toNorm
                || conversion.name.lowercased().contains(toNorm)

            guard fromMatch && toMatch else { continue }

            let result = conversion.convert(value)
            guard result.isFinite else { continue }

            let answer = conversion.formatResult(value, result)

            return InterceptorResult(
                answer: answer,
                teacherInstruction: "[RESULTADO: \(answer)] Explica la conversión paso a paso.",
                category: .computed,
                attachmentType: "formula_result",
                attachmentData: """
                {"from_value":\(fmt(value)),"from_unit":"\(conversion.fromUnit)","to_value":"\(fmt(result))","to_unit":"\(conversion.toUnit)","type":"unit_conversion"}
                """,
                confidence: 0.9
            )
        }

        return nil
    }

    // MARK: - Variable Extraction

    private func extractVariables(_ text: String) -> [String: Double] {
        var vars: [String: Double] = [:]

        // Pattern: var=value or var = value (supports v0, m1, m2, q1, q2, dt, lambda, etc.)
        let pattern = #"([a-z][a-z0-9]*)\s*=\s*(-?\d+\.?\d*(?:[eE][+-]?\d+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return vars }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            guard let nameRange = Range(match.range(at: 1), in: text),
                  let valueRange = Range(match.range(at: 2), in: text),
                  let value = Double(text[valueRange]) else { continue }
            let name = String(text[nameRange])
            vars[name] = value
        }

        // Also detect "si X es Y" / "X de Y" patterns
        let spanishPattern = #"(?:si\s+)?([a-z][a-z0-9]*)\s+(?:es|vale|=)\s+(-?\d+\.?\d*(?:[eE][+-]?\d+)?)"#
        if let regex2 = try? NSRegularExpression(pattern: spanishPattern) {
            let matches2 = regex2.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches2 {
                guard let nameRange = Range(match.range(at: 1), in: text),
                      let valueRange = Range(match.range(at: 2), in: text),
                      let value = Double(text[valueRange]) else { continue }
                let name = String(text[nameRange])
                if vars[name] == nil { vars[name] = value }
            }
        }

        // Detect "masa=X" or "masa de X" → m
        let aliasMap: [(keywords: [String], varName: String)] = [
            (["masa"], "m"),
            (["aceleracion"], "a"),
            (["distancia", "desplazamiento"], "d"),
            (["tiempo"], "t"),
            (["velocidad inicial"], "v0"),
            (["velocidad"], "v"),
            (["altura"], "h"),
            (["corriente", "intensidad"], "i"),
            (["resistencia"], "r"),
            (["frecuencia"], "f"),
            (["temperatura"], "dt"),
        ]

        for alias in aliasMap {
            for keyword in alias.keywords {
                let wordPattern = "\(keyword)\\s*(?:de|es|=|:)?\\s*(-?\\d+\\.?\\d*(?:[eE][+-]?\\d+)?)"
                if let regex3 = try? NSRegularExpression(pattern: wordPattern),
                   let match = regex3.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                   let valueRange = Range(match.range(at: 1), in: text),
                   let value = Double(text[valueRange]) {
                    if vars[alias.varName] == nil { vars[alias.varName] = value }
                }
            }
        }

        return vars
    }

    // MARK: - Conversion Value Extraction

    private func extractConversionValue(_ text: String) -> Double? {
        // Look for a number near a unit keyword
        let pattern = #"(-?\d+\.?\d*(?:[eE][+-]?\d+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        // Return the first number found
        for match in matches {
            guard let range = Range(match.range(at: 1), in: text),
                  let value = Double(text[range]) else { continue }
            return value
        }
        return nil
    }

    // MARK: - Helpers

    private func normalize(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
            .replacingOccurrences(of: "\u{00BF}", with: "")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "\u{00A1}", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Format a number for display: integers without decimals, floats trimmed
    nonisolated static func fmt(_ n: Double) -> String {
        if n == n.rounded() && abs(n) < 1e15 {
            return String(format: "%.0f", n)
        }
        // Scientific notation for very large/small numbers
        if abs(n) >= 1e6 || (abs(n) < 0.001 && n != 0) {
            return String(format: "%.4g", n)
        }
        let formatted = String(format: "%.4f", n)
        return formatted
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
    }

    /// Instance wrapper for static fmt
    nonisolated private func fmt(_ n: Double) -> String {
        Self.fmt(n)
    }

    private func normalizeUnitWord(_ word: String) -> String {
        word.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
            .replacingOccurrences(of: "s$", with: "", options: .regularExpression) // remove trailing plural
    }

    /// Build a standard formula InterceptorResult
    private func formulaResult(
        name: String, answer: String, detail: String, result: Double, unit: String
    ) -> InterceptorResult {
        InterceptorResult(
            answer: answer,
            teacherInstruction: "[RESULTADO: \(answer)] Con \(detail). Explica el procedimiento paso a paso y el significado físico del resultado.",
            category: .computed,
            attachmentType: "formula_result",
            attachmentData: """
            {"formula":"\(name)","result":"\(fmt(result))","unit":"\(unit)","detail":"\(detail)","type":"physics_formula"}
            """,
            confidence: 0.95
        )
    }

    // MARK: - Detection Patterns

    private static let constantKeywords: [String] = [
        "constante", "velocidad de la luz", "velocidad luz", "gravedad",
        "aceleracion gravitacional", "aceleracion de la gravedad",
        "planck", "carga elemental", "carga del electron",
        "avogadro", "boltzmann", "stefan", "permitividad",
        "permeabilidad", "masa del electron", "masa del proton",
        "masa del neutron", "presion atmosferica", "velocidad del sonido",
        "coulomb", "faraday", "impedancia del vacio", "radio de bohr",
        "rydberg", "masa atomica", "electronvoltio", "electronvolt",
        "ano luz", "unidad astronomica", "cero absoluto",
        "wien", "numero aureo", "proporcion aurea",
        "gravedad en la luna", "gravedad lunar",
        "gases ideales", "constante de los gases",
        "cuanto vale c", "cuanto vale g", "cuanto vale h",
        "cuanto vale k", "cuanto vale r",
        "valor de g", "valor de c", "valor de h",
    ]

    private static let formulaKeywords: [String] = [
        "fuerza", "f=ma", "f = ma",
        "velocidad", "rapidez", "v=d/t",
        "momento", "momentum", "cantidad de movimiento",
        "energia cinetica", "cinetica",
        "energia potencial", "potencial gravitatoria",
        "trabajo", "w=fd",
        "ley de ohm", "ohm", "v=ir",
        "potencia electrica",
        "velocidad de onda",
        "periodo", "t=1/f",
        "calor", "q=mc",
        "velocidad final", "mrua",
        "distancia", "desplazamiento",
        "presion", "p=f/a",
        "densidad",
        "peso", "w=mg",
    ]

    private static let conversionKeywords: [String] = [
        "convierte", "convertir", "conversion",
        "cuantos metros", "cuantos kilometros", "cuantos gramos",
        "cuantas millas", "cuantas libras", "cuantas calorias",
        "de celsius a", "de fahrenheit a", "de kelvin a",
        "km a m", "m a km", "cm a m", "m a cm",
        "kg a g", "g a kg", "lb a kg", "kg a lb",
        "km/h a m/s", "m/s a km/h", "mph a km/h", "km/h a mph",
        "atm a pa", "pa a atm",
        "julios a calorias", "calorias a julios",
        "pulgadas a", "pies a metros",
        "millas a kilometros", "kilometros a millas",
    ]

    private static let physicsVerbs: [String] = [
        "calcula la fuerza", "calcula la velocidad", "calcula la aceleracion",
        "calcula el peso", "calcula la energia", "calcula el trabajo",
        "calcula la presion", "calcula la densidad", "calcula el voltaje",
        "calcula la potencia", "calcula el periodo", "calcula la frecuencia",
        "calcula el calor", "calcula el momento", "calcula la distancia",
        "cual es la fuerza", "cual es la velocidad", "cual es la aceleracion",
        "cual es el peso", "cual es la energia",
    ]

    private static let variablePattern: NSRegularExpression = {
        // Matches "m=10", "a=5", "v0=3.5"
        try! NSRegularExpression(pattern: #"[a-z][a-z0-9]*\s*=\s*-?\d+\.?\d*"#)
    }()
}
