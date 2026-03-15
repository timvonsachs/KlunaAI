import Foundation

struct TrainingExercise {
    let id: String
    let title: String
    let instruction: String
    let targetDimension: String
    let targetState: VocalState?
    let durationSeconds: Int
    let measurableCriteria: [MeasurableCriterion]
}

struct MeasurableCriterion {
    let feature: String
    let targetDirection: TargetDirection
    let description: String
}

enum TargetDirection {
    case increase
    case decrease
    case range(min: Double, max: Double)
}

struct ExerciseResult {
    let exercise: TrainingExercise
    let criterionResults: [(criterion: MeasurableCriterion, met: Bool, actualValue: Double)]
    let successRate: Double
}

enum AdaptiveTrainingEngine {
    static func selectExercise(
        vocalState: VocalStateResult,
        scores: DimensionScores,
        efficiency: VocalEfficiencyResult,
        consistency: ConsistencyResult?,
        sessionCount: Int
    ) -> TrainingExercise {
        let _ = consistency
        let _ = sessionCount
        let dimensions: [(String, Double)] = [
            ("confidence", scores.confidence),
            ("energy", scores.energy),
            ("tempo", scores.tempo),
            ("stability", scores.stability),
            ("charisma", scores.charisma)
        ]
        let weakest = dimensions.min { $0.1 < $1.1 }?.0 ?? "charisma"

        switch vocalState.primaryState {
        case .tense: return exerciseForTense()
        case .tired: return exerciseForTired()
        default: break
        }

        if efficiency.category == .forceful {
            return exerciseForForceful()
        }

        switch weakest {
        case "confidence": return exerciseForConfidence()
        case "energy": return exerciseForEnergy()
        case "tempo": return exerciseForTempo()
        case "stability": return exerciseForTense()
        default: return exerciseForCharisma()
        }
    }

    static func evaluateExercise(
        exercise: TrainingExercise,
        features: [String: Double],
        spectral: SpectralBandResult
    ) -> ExerciseResult {
        var rows: [(MeasurableCriterion, Bool, Double)] = []
        for criterion in exercise.measurableCriteria {
            let value = features[criterion.feature] ?? Double(spectral.presenceScore)
            let met: Bool
            switch criterion.targetDirection {
            case .increase:
                met = true
            case .decrease:
                met = true
            case .range(let min, let max):
                met = value >= min && value <= max
            }
            rows.append((criterion, met, value))
        }
        let success = rows.isEmpty ? 0 : Double(rows.filter { $0.1 }.count) / Double(rows.count)
        return ExerciseResult(exercise: exercise, criterionResults: rows, successRate: success)
    }

    private static func exerciseForTense() -> TrainingExercise {
        TrainingExercise(
            id: "relax_breath",
            title: "Tiefe Entspannung",
            instruction: "Atme 3 Mal tief ein und aus. Dann lies langsam vor und betone die tiefen Vokale.",
            targetDimension: "stability",
            targetState: .tense,
            durationSeconds: 20,
            measurableCriteria: [
                MeasurableCriterion(feature: FeatureKeys.speechRate, targetDirection: .range(min: 2.5, max: 3.8), description: "Langsames Tempo"),
                MeasurableCriterion(feature: FeatureKeys.meanPauseDuration, targetDirection: .range(min: 0.5, max: 2.0), description: "Bewusste Pausen")
            ]
        )
    }

    private static func exerciseForTired() -> TrainingExercise {
        TrainingExercise(
            id: "energy_boost",
            title: "Energie-Boost",
            instruction: "Steh auf, lockere den Koerper und sprich mit Begeisterung.",
            targetDimension: "energy",
            targetState: .tired,
            durationSeconds: 15,
            measurableCriteria: [
                MeasurableCriterion(feature: FeatureKeys.f0RangeST, targetDirection: .range(min: 5.0, max: 15.0), description: "Grosse Stimmvariation"),
                MeasurableCriterion(feature: FeatureKeys.speechRate, targetDirection: .range(min: 3.5, max: 5.5), description: "Aktives Tempo")
            ]
        )
    }

    private static func exerciseForForceful() -> TrainingExercise {
        TrainingExercise(
            id: "resonance_focus",
            title: "Resonanz statt Kraft",
            instruction: "Sprich bewusst leise aber deutlich. Fokus auf Resonanz statt Druck.",
            targetDimension: "confidence",
            targetState: nil,
            durationSeconds: 20,
            measurableCriteria: [
                MeasurableCriterion(feature: FeatureKeys.jitter, targetDirection: .range(min: 0.008, max: 0.020), description: "Niedriger Jitter")
            ]
        )
    }

    private static func exerciseForConfidence() -> TrainingExercise {
        TrainingExercise(
            id: "authority_voice",
            title: "Autoritaet",
            instruction: "Sprich wie bei einer wichtigen Entscheidung: ruhig, klar, mit Pausen.",
            targetDimension: "confidence",
            targetState: nil,
            durationSeconds: 15,
            measurableCriteria: [
                MeasurableCriterion(feature: FeatureKeys.meanPauseDuration, targetDirection: .range(min: 0.6, max: 2.0), description: "Laengere Pausen"),
                MeasurableCriterion(feature: FeatureKeys.speechRate, targetDirection: .range(min: 2.8, max: 4.0), description: "Ruhiges Tempo")
            ]
        )
    }

    private static func exerciseForEnergy() -> TrainingExercise {
        TrainingExercise(
            id: "dynamic_range",
            title: "Dynamik",
            instruction: "Wechsle bewusst zwischen laut und leise.",
            targetDimension: "energy",
            targetState: nil,
            durationSeconds: 20,
            measurableCriteria: [
                MeasurableCriterion(feature: "loudnessDynamicRange", targetDirection: .range(min: 25.0, max: 50.0), description: "Lautstaerke-Dynamik")
            ]
        )
    }

    private static func exerciseForTempo() -> TrainingExercise {
        TrainingExercise(
            id: "pause_power",
            title: "Die Macht der Pause",
            instruction: "Nach jedem Punkt eine volle Sekunde Pause.",
            targetDimension: "tempo",
            targetState: nil,
            durationSeconds: 20,
            measurableCriteria: [
                MeasurableCriterion(feature: FeatureKeys.meanPauseDuration, targetDirection: .range(min: 0.8, max: 2.5), description: "Bewusste lange Pausen"),
                MeasurableCriterion(feature: FeatureKeys.pauseRate, targetDirection: .range(min: 15.0, max: 30.0), description: "Regelmaessige Pausen")
            ]
        )
    }

    private static func exerciseForCharisma() -> TrainingExercise {
        TrainingExercise(
            id: "storyteller",
            title: "Der Storyteller",
            instruction: "Erzaehle den Text wie eine spannende Geschichte an einen Freund.",
            targetDimension: "charisma",
            targetState: nil,
            durationSeconds: 20,
            measurableCriteria: [
                MeasurableCriterion(feature: FeatureKeys.f0RangeST, targetDirection: .range(min: 5.0, max: 15.0), description: "Lebendige Melodie"),
                MeasurableCriterion(feature: FeatureKeys.speechRate, targetDirection: .range(min: 3.5, max: 5.0), description: "Dynamisches Tempo")
            ]
        )
    }
}
