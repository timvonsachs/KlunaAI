import Foundation

struct MicroDrill: Identifiable {
    let id: String
    let dimension: PerformanceDimension
    let titleDe: String
    let titleEn: String
    let instructionDe: String
    let instructionEn: String
    let timeLimit: Int
    let tipDe: String
    let tipEn: String

    func title(language: String) -> String { language == "de" ? titleDe : titleEn }
    func instruction(language: String) -> String { language == "de" ? instructionDe : instructionEn }
    func tip(language: String) -> String { language == "de" ? tipDe : tipEn }
}

final class MicroDrillProvider {
    static let shared = MicroDrillProvider()

    func drillForWeakness(_ dimension: PerformanceDimension) -> MicroDrill {
        let drills = allDrills.filter { $0.dimension == dimension }
        return drills.isEmpty ? allDrills[0] : drills[Int.random(in: 0..<drills.count)]
    }

    func weakestDimension(from scores: DimensionScores) -> PerformanceDimension {
        let all: [(PerformanceDimension, Double)] = [
            (.confidence, scores.confidence),
            (.energy, scores.energy),
            (.tempo, scores.tempo),
            (.stability, scores.stability),
            (.charisma, scores.charisma),
        ]
        return all.min(by: { $0.1 < $1.1 })?.0 ?? .energy
    }

    func heatmapWeakness(segments: [DimensionScores]) -> (dimension: PerformanceDimension, segment: Int)? {
        guard segments.count >= 2 else { return nil }
        var biggestDrop: Double = 0
        var worstDim: PerformanceDimension = .energy
        var worstSegment = 0
        for dim in PerformanceDimension.activeDimensions {
            for i in 1..<segments.count {
                let drop = segments[i - 1].value(for: dim) - segments[i].value(for: dim)
                if drop > biggestDrop {
                    biggestDrop = drop
                    worstDim = dim
                    worstSegment = i
                }
            }
        }
        return biggestDrop > 5 ? (worstDim, worstSegment) : nil
    }

    let allDrills: [MicroDrill] = [
        MicroDrill(id: "conf01", dimension: .confidence, titleDe: "Power-Satz", titleEn: "Power Sentence",
                  instructionDe: "Sage laut und klar: 'Ich bin ueberzeugt davon, dass das funktioniert.' Wiederhole es 3x – jedes Mal mit mehr Ueberzeugung.",
                  instructionEn: "Say loud and clear: 'I am convinced this will work.' Repeat 3 times – with more conviction each time.",
                  timeLimit: 30, tipDe: "Fokus: Klare Stimme, kein Zittern, jedes Wort betonen.", tipEn: "Focus: Clear voice, no trembling, emphasize every word."),
        MicroDrill(id: "conf02", dimension: .confidence, titleDe: "Der starke Opener", titleEn: "The Strong Opener",
                  instructionDe: "Beginne einen Pitch mit dem selbstbewusstesten Satz den du dir vorstellen kannst. Keine Einleitung, kein 'Also' – direkt rein.",
                  instructionEn: "Start a pitch with the most confident sentence you can imagine. No intro, no 'So' – jump straight in.",
                  timeLimit: 30, tipDe: "Fokus: Die ersten 3 Sekunden bestimmen alles. Laut, klar, direkt.", tipEn: "Focus: The first 3 seconds determine everything. Loud, clear, direct."),
        MicroDrill(id: "conf03", dimension: .confidence, titleDe: "Fakten mit Autoritaet", titleEn: "Facts with Authority",
                  instructionDe: "Nenne 3 Zahlen oder Fakten zu einem beliebigen Thema. Sage jede Zahl so als waerst du der weltweit fuehrende Experte.",
                  instructionEn: "Name 3 numbers or facts about any topic. Say each as if you're the world's leading expert.",
                  timeLimit: 30, tipDe: "Fokus: Stimme senken am Satzende. Nicht nach oben gehen – das klingt unsicher.", tipEn: "Focus: Lower your voice at the end of sentences. Don't go up – that sounds uncertain."),
        MicroDrill(id: "ener01", dimension: .energy, titleDe: "Lautstaerke-Treppe", titleEn: "Volume Ladder",
                  instructionDe: "Sage den gleichen Satz 3x: erst fluesternd, dann normal, dann so als wuerdest du eine Halle fuellen.",
                  instructionEn: "Say the same sentence 3 times: first whispering, then normal, then as if filling a hall.",
                  timeLimit: 30, tipDe: "Fokus: Beim dritten Mal wirklich LAUT. Dein Koerper muss die Energie spueren.", tipEn: "Focus: Really be LOUD the third time. Your body should feel the energy."),
        MicroDrill(id: "ener02", dimension: .energy, titleDe: "Begeisterung pur", titleEn: "Pure Enthusiasm",
                  instructionDe: "Erzaehle 30 Sekunden lang von etwas das dich begeistert – als waerst du der enthusiastischste Mensch der Welt.",
                  instructionEn: "Talk for 30 seconds about something exciting – as if you're the most enthusiastic person alive.",
                  timeLimit: 30, tipDe: "Fokus: Uebertreibe! Du kannst spaeter zurueckschrauben, aber erst musst du das Maximum finden.", tipEn: "Focus: Exaggerate! You can dial it back later, but first find your maximum."),
        MicroDrill(id: "ener03", dimension: .energy, titleDe: "Energie am Ende", titleEn: "Energy at the End",
                  instructionDe: "Sage 3 Saetze – aber der letzte Satz muss der energischste sein. Nicht leiser werden am Ende!",
                  instructionEn: "Say 3 sentences – but the last must be the most energetic. Don't get quieter at the end!",
                  timeLimit: 30, tipDe: "Fokus: Die meisten Menschen verlieren Energie am Schluss. Tu das Gegenteil.", tipEn: "Focus: Most people lose energy at the end. Do the opposite."),
        MicroDrill(id: "temp01", dimension: .tempo, titleDe: "Die bewusste Pause", titleEn: "The Intentional Pause",
                  instructionDe: "Sage einen Satz. Pause – zaehle innerlich bis 2. Dann der naechste Satz. Pause. Naechster. Die Pausen sind TEIL deiner Rede.",
                  instructionEn: "Say a sentence. Pause – count to 2 inside. Then next sentence. Pause. Next. The pauses ARE part of your speech.",
                  timeLimit: 30, tipDe: "Fokus: Pausen fuehlen sich laenger an als sie sind. 2 Sekunden sind perfekt.", tipEn: "Focus: Pauses feel longer than they are. 2 seconds is perfect."),
        MicroDrill(id: "temp02", dimension: .tempo, titleDe: "Zeitlupen-Rede", titleEn: "Slow-Motion Speech",
                  instructionDe: "Erklaere etwas Einfaches – aber in halber Geschwindigkeit. Jedes. Einzelne. Wort. Bewusst.",
                  instructionEn: "Explain something simple – but at half speed. Every. Single. Word. Deliberate.",
                  timeLimit: 30, tipDe: "Fokus: Langsam ≠ langweilig. Langsam + betont = maechtig.", tipEn: "Focus: Slow ≠ boring. Slow + emphasized = powerful."),
        MicroDrill(id: "temp03", dimension: .tempo, titleDe: "Tempo-Wechsel", titleEn: "Tempo Shift",
                  instructionDe: "Beginne langsam, werde schneller, und bremse beim letzten Satz ab. Wie ein Film: Aufbau, Klimax, Aufloesung.",
                  instructionEn: "Start slow, speed up, and brake for the final sentence. Like a movie: setup, climax, resolution.",
                  timeLimit: 30, tipDe: "Fokus: Der Wechsel selbst ist das Signal. Dein Publikum wacht auf.", tipEn: "Focus: The shift itself is the signal. Your audience wakes up."),
        MicroDrill(id: "clar01", dimension: .clarity, titleDe: "Zungenbrecher", titleEn: "Tongue Twister",
                  instructionDe: "Sage 3x schnell: 'Fischers Fritz fischt frische Fische.' Dann den gleichen Satz langsam und glasklar.",
                  instructionEn: "Say 3x fast: 'She sells seashells by the seashore.' Then say it slowly and crystal clear.",
                  timeLimit: 30, tipDe: "Fokus: Uebertriebene Artikulation. Lippen und Zunge bewusst bewegen.", tipEn: "Focus: Exaggerated articulation. Move lips and tongue deliberately."),
        MicroDrill(id: "clar02", dimension: .clarity, titleDe: "Jedes Wort zaehlt", titleEn: "Every Word Counts",
                  instructionDe: "Sage einen komplexen Satz – und betone JEDES Wort einzeln. Keine verschluckten Silben, kein Nuscheln.",
                  instructionEn: "Say a complex sentence – and emphasize EACH word separately. No swallowed syllables, no mumbling.",
                  timeLimit: 30, tipDe: "Fokus: Stell dir vor jemand liest von deinen Lippen ab.", tipEn: "Focus: Imagine someone is reading your lips."),
        MicroDrill(id: "clar03", dimension: .clarity, titleDe: "Kristallklar", titleEn: "Crystal Clear",
                  instructionDe: "Erklaere ein Konzept in 3 kurzen Saetzen. Kein Satz ueber 10 Worte. Einfach, klar, praezise.",
                  instructionEn: "Explain a concept in 3 short sentences. No sentence over 10 words. Simple, clear, precise.",
                  timeLimit: 30, tipDe: "Fokus: Kuerze = Praesenz. Wenn du es kuerzer sagen kannst, sag es kuerzer.", tipEn: "Focus: Brevity = presence. If you can say it shorter, say it shorter."),
        MicroDrill(id: "stab01", dimension: .stability, titleDe: "Der ruhige Anker", titleEn: "The Calm Anchor",
                  instructionDe: "Atme einmal tief ein. Dann rede 30 Sekunden ueber irgendetwas – in exakt der gleichen Lautstaerke und dem gleichen Tempo. Keine Schwankungen.",
                  instructionEn: "Take one deep breath. Then talk for 30 seconds about anything – at exactly the same volume and pace. No fluctuations.",
                  timeLimit: 30, tipDe: "Fokus: Gleichmaessigkeit. Deine Stimme ist ein ruhiger Fluss, keine Achterbahn.", tipEn: "Focus: Consistency. Your voice is a calm river, not a rollercoaster."),
        MicroDrill(id: "stab02", dimension: .stability, titleDe: "Nervoeses Thema, ruhige Stimme", titleEn: "Nervous Topic, Calm Voice",
                  instructionDe: "Sprich ueber etwas das dich nervoes macht – aber halte deine Stimme komplett ruhig. Der Inhalt darf aufregend sein, die Stimme nicht.",
                  instructionEn: "Talk about something that makes you nervous – but keep your voice completely calm. Content can be exciting, voice must not be.",
                  timeLimit: 30, tipDe: "Fokus: Das ist DIE Faehigkeit fuer Pitches und Verhandlungen.", tipEn: "Focus: This is THE skill for pitches and negotiations."),
        MicroDrill(id: "stab03", dimension: .stability, titleDe: "Gleichmaessig durch 3 Saetze", titleEn: "Steady Through 3 Sentences",
                  instructionDe: "Sage 3 Saetze. Alle in der gleichen Tonhoehe, gleichen Lautstaerke, gleichem Tempo. Wie ein Nachrichtensprecher.",
                  instructionEn: "Say 3 sentences. All at the same pitch, same volume, same speed. Like a news anchor.",
                  timeLimit: 30, tipDe: "Fokus: Kontrollierte Monotonie als Uebung – nicht als Ziel.", tipEn: "Focus: Controlled monotony as exercise – not as goal."),
        MicroDrill(id: "char01", dimension: .charisma, titleDe: "Die Achterbahn", titleEn: "The Rollercoaster",
                  instructionDe: "Erzaehle etwas mit dramatischen Hoehen und Tiefen. Leise-laut, langsam-schnell, Pausen-Tempo. Nutze die VOLLE Bandbreite deiner Stimme.",
                  instructionEn: "Tell something with dramatic highs and lows. Quiet-loud, slow-fast, pauses-tempo. Use the FULL range of your voice.",
                  timeLimit: 30, tipDe: "Fokus: Charisma = Dynamik. Nicht immer laut, nicht immer leise – der WECHSEL ist der Trick.", tipEn: "Focus: Charisma = dynamics. Not always loud, not always quiet – the SHIFT is the trick."),
        MicroDrill(id: "char02", dimension: .charisma, titleDe: "Die goldene Pause", titleEn: "The Golden Pause",
                  instructionDe: "Sage einen wichtigen Satz. Dann: 3 Sekunden STILLE. Dann den naechsten. Die Pause zwingt dein Publikum zum Nachdenken.",
                  instructionEn: "Say an important sentence. Then: 3 seconds of SILENCE. Then the next. The pause forces your audience to think.",
                  timeLimit: 30, tipDe: "Fokus: Stille ist das maechtigste Werkzeug eines Speakers.", tipEn: "Focus: Silence is the most powerful tool of a speaker."),
        MicroDrill(id: "char03", dimension: .charisma, titleDe: "Steve Jobs Close", titleEn: "Steve Jobs Close",
                  instructionDe: "Sage einen einzigen Satz – den wichtigsten deines Pitches. Sage ihn so, dass er im Raum haengen bleibt. Pause davor, Pause danach.",
                  instructionEn: "Say a single sentence – the most important of your pitch. Say it so it lingers in the room. Pause before, pause after.",
                  timeLimit: 30, tipDe: "Fokus: One more thing. Der Satz der alles zusammenfasst.", tipEn: "Focus: One more thing. The sentence that captures everything."),
    ]
}
