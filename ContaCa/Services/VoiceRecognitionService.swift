//
//  VoiceRecognitionService.swift
//  ContaCa
//
//  Created by João Pedro on 10/29/26.
//

import Foundation
import Speech
import AVFoundation
import Combine

/// Item individual do prato de voz
public struct VoicePlateItem: Identifiable, Sendable, Equatable {
    public var id = UUID()
    public var name: String
    public var brand: String
    public var portionValue: Double
    public var unit: String
    public var isLiquid: Bool
    public var calories: Double
    public var protein: Double
    public var carbs: Double
    public var fat: Double
    
    public var baseCaloriesPer100: Double
    public var baseProteinPer100: Double
    public var baseCarbsPer100: Double
    public var baseFatPer100: Double
    
    public init(
        id: UUID = UUID(),
        name: String,
        brand: String = "",
        portionValue: Double,
        unit: String = "g",
        isLiquid: Bool = false,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        let p = max(1.0, portionValue)
        self.portionValue = p
        self.unit = unit
        self.isLiquid = isLiquid
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        
        let factor = p / 100.0
        self.baseCaloriesPer100 = calories / factor
        self.baseProteinPer100 = protein / factor
        self.baseCarbsPer100 = carbs / factor
        self.baseFatPer100 = fat / factor
    }
    
    public mutating func updatePortion(_ newPortion: Double) {
        let stepMin = isLiquid ? 25.0 : 5.0
        let clamped = max(stepMin, newPortion)
        self.portionValue = clamped
        let factor = clamped / 100.0
        self.calories = ((baseCaloriesPer100 * factor) * 10).rounded() / 10
        self.protein = ((baseProteinPer100 * factor) * 10).rounded() / 10
        self.carbs = ((baseCarbsPer100 * factor) * 10).rounded() / 10
        self.fat = ((baseFatPer100 * factor) * 10).rounded() / 10
    }
}

/// Estrutura com os dados extraídos de uma fala em linguagem natural (suporta pratos com múltiplos itens)
public struct VoiceFoodIntent: Sendable, Equatable {
    public var rawText: String
    public var mealType: MealType
    public var items: [VoicePlateItem]
    
    public var totalCalories: Double {
        items.reduce(0.0) { $0 + $1.calories }
    }
    public var totalProtein: Double {
        items.reduce(0.0) { $0 + $1.protein }
    }
    public var totalCarbs: Double {
        items.reduce(0.0) { $0 + $1.carbs }
    }
    public var totalFat: Double {
        items.reduce(0.0) { $0 + $1.fat }
    }
    
    // Propriedades para compatibilidade com código existente
    public var foodQuery: String {
        items.map { $0.name }.joined(separator: ", ")
    }
    public var portionGrams: Double {
        items.first?.portionValue ?? 100.0
    }
    public var matchedFood: NutritionalFoodItem? {
        guard let first = items.first else { return nil }
        return NutritionalFoodItem(
            name: first.name,
            brand: first.brand,
            caloriesPer100g: first.baseCaloriesPer100,
            proteinPer100g: first.baseProteinPer100,
            carbsPer100g: first.baseCarbsPer100,
            fatPer100g: first.baseFatPer100
        )
    }
    public var calculatedCalories: Double { totalCalories }
    public var calculatedProtein: Double { totalProtein }
    public var calculatedCarbs: Double { totalCarbs }
    public var calculatedFat: Double { totalFat }
    
    public init(
        rawText: String,
        mealType: MealType,
        items: [VoicePlateItem] = []
    ) {
        self.rawText = rawText
        self.mealType = mealType
        self.items = items
    }
    
    public init(
        rawText: String,
        foodQuery: String,
        portionGrams: Double,
        mealType: MealType,
        matchedFood: NutritionalFoodItem? = nil,
        calculatedCalories: Double = 0,
        calculatedProtein: Double = 0,
        calculatedCarbs: Double = 0,
        calculatedFat: Double = 0
    ) {
        self.rawText = rawText
        self.mealType = mealType
        if let food = matchedFood {
            self.items = [
                VoicePlateItem(
                    name: food.name,
                    brand: food.brand,
                    portionValue: portionGrams,
                    unit: food.defaultUnit,
                    isLiquid: food.isLiquid,
                    calories: calculatedCalories,
                    protein: calculatedProtein,
                    carbs: calculatedCarbs,
                    fat: calculatedFat
                )
            ]
        } else {
            self.items = []
        }
    }
}

/// Modo de escuta por voz
public enum VoiceListeningMode: Sendable {
    case food
    case workout
}

/// Estado das permissões de voz e microfone
public enum VoicePermissionStatus: Sendable {
    case notDetermined
    case authorized
    case speechDenied
    case microphoneDenied
    case restricted
}

/// Serviço de reconhecimento de voz e análise semântica de alimentos
@MainActor
public final class VoiceRecognitionService: NSObject, ObservableObject {
    public static let shared = VoiceRecognitionService()
    
    @Published public var isRecording: Bool = false
    @Published public var recognizedText: String = ""
    @Published public var audioLevel: Float = 0.0 // 0.0 a 1.0 para visualizador de ondas
    @Published public var permissionStatus: VoicePermissionStatus = .notDetermined
    @Published public var listeningMode: VoiceListeningMode = .food
    @Published public var currentIntent: VoiceFoodIntent? = nil
    @Published public var alternativeMatches: [NutritionalFoodItem] = []
    @Published public var isAnalyzing: Bool = false
    @Published public var errorMessage: String? = nil
    
    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private var parseDebounceTask: Task<Void, Never>?
    private var activeAnalysisTask: Task<Void, Never>?
    private var currentAnalysisId: Int = 0
    private var lastSpokenTime: Date = Date()
    
    override public init() {
        super.init()
        let ptLocale = Locale(identifier: "pt-BR")
        if SFSpeechRecognizer.supportedLocales().contains(ptLocale) {
            self.speechRecognizer = SFSpeechRecognizer(locale: ptLocale)
        } else {
            self.speechRecognizer = SFSpeechRecognizer()
        }
    }
    
    // MARK: - Permissões
    
    public func checkPermissions() {
        let speechAuth = SFSpeechRecognizer.authorizationStatus()
        let micAuth = AVAudioApplication.shared.recordPermission
        
        switch (speechAuth, micAuth) {
        case (.authorized, .granted):
            permissionStatus = .authorized
        case (.denied, _):
            permissionStatus = .speechDenied
        case (_, .denied):
            permissionStatus = .microphoneDenied
        case (.restricted, _):
            permissionStatus = .restricted
        default:
            permissionStatus = .notDetermined
        }
    }
    
    public func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        guard speechStatus == .authorized else {
            if speechStatus == .denied {
                permissionStatus = .speechDenied
            } else {
                permissionStatus = .restricted
            }
            return false
        }
        
        let micGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        
        if micGranted {
            permissionStatus = .authorized
            return true
        } else {
            permissionStatus = .microphoneDenied
            return false
        }
    }
    
    // MARK: - Gravação e Reconhecimento
    
    public func startListening(mode: VoiceListeningMode = .food) {
        stopListening()
        self.listeningMode = mode
        
        errorMessage = nil
        recognizedText = ""
        currentIntent = nil
        alternativeMatches = []
        audioLevel = 0.0
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Não foi possível iniciar o microfone: \(error.localizedDescription)"
            return
        }
        
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        self.recognitionRequest = request
        
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = UInt(buffer.frameLength)
            var sum: Float = 0.0
            for i in 0..<Int(frameLength) {
                let sample = channelData[i]
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(frameLength))
            let level = min(max(rms * 10.0, 0.05), 1.0)
            
            Task { @MainActor [weak self] in
                self?.audioLevel = level
            }
        }
        
        do {
            try engine.start()
            isRecording = true
            lastSpokenTime = Date()
        } catch {
            errorMessage = "Erro ao iniciar captura: \(error.localizedDescription)"
            stopListening()
            return
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.recognizedText = transcription
                    self.lastSpokenTime = Date()
                    if self.listeningMode == .food {
                        self.scheduleParse(for: transcription)
                    }
                }
            }
            
            if error != nil || (result?.isFinal ?? false) {
                Task { @MainActor in
                    if self.listeningMode == .food, let text = result?.bestTranscription.formattedString, !text.isEmpty {
                        self.analyzeIntent(from: text)
                    }
                }
            }
        }
    }
    
    public func stopListening() {
        parseDebounceTask?.cancel()
        parseDebounceTask = nil
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isRecording = false
        audioLevel = 0.0
        
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        
        if listeningMode == .food {
            let trimmed = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed != currentIntent?.rawText {
                analyzeIntent(from: trimmed)
            }
        }
    }
    
    // MARK: - Análise e Parsing de Fala
    
    private func scheduleParse(for text: String) {
        parseDebounceTask?.cancel()
        parseDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            self.analyzeIntent(from: text)
        }
    }
    
    public func analyzeIntent(from spokenText: String) {
        let trimmed = spokenText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let cleanQuery = extractFoodQuery(from: trimmed)
        
        // Se a fala contém apenas quantidade/medida (ex: "100g", "200 gramas"):
        if cleanQuery.isEmpty || isPureMeasureQuery(cleanQuery) {
            let portion = extractPortionGrams(from: trimmed)
            if let first = currentIntent?.items.first {
                updateItemPortion(id: first.id, newPortion: portion)
            }
            return
        }
        
        currentAnalysisId += 1
        let analysisId = currentAnalysisId
        activeAnalysisTask?.cancel()
        
        isAnalyzing = true
        
        activeAnalysisTask = Task { [weak self] in
            guard let self = self else { return }
            
            // Aciona o parser nutricional inteligente (separa arroz, feijão, shakes, etc. com Tabela TACO de primeira e Nuvem como fallback)
            let parseResult = await AIFoodParserService.shared.parseMeal(description: trimmed)
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                guard self.currentAnalysisId == analysisId else { return }
                self.isAnalyzing = false
                
                guard !parseResult.items.isEmpty else { return }
                
                let plateItems = parseResult.items.map { item in
                    VoicePlateItem(
                        name: item.matchedFoodName,
                        brand: item.brand,
                        portionValue: item.portionValue,
                        unit: item.unit,
                        isLiquid: item.isLiquid,
                        calories: item.calories,
                        protein: item.protein,
                        carbs: item.carbohydrates,
                        fat: item.fat
                    )
                }
                
                self.currentIntent = VoiceFoodIntent(
                    rawText: trimmed,
                    mealType: parseResult.mealType,
                    items: plateItems
                )
            }
        }
    }
    
    public func updateItemPortion(id: UUID, newPortion: Double) {
        guard var intent = currentIntent else { return }
        if let idx = intent.items.firstIndex(where: { $0.id == id }) {
            intent.items[idx].updatePortion(newPortion)
            self.currentIntent = intent
        }
    }
    
    public func adjustItemPortion(id: UUID, delta: Double) {
        guard var intent = currentIntent else { return }
        if let idx = intent.items.firstIndex(where: { $0.id == id }) {
            let current = intent.items[idx].portionValue
            intent.items[idx].updatePortion(current + delta)
            self.currentIntent = intent
        }
    }
    
    public func removeItem(id: UUID) {
        guard var intent = currentIntent else { return }
        intent.items.removeAll { $0.id == id }
        self.currentIntent = intent
    }
    
    public func updatePortion(_ grams: Double) {
        if let first = currentIntent?.items.first {
            updateItemPortion(id: first.id, newPortion: grams)
        }
    }
    
    public func selectAlternativeMatch(_ item: NutritionalFoodItem) {
        guard var intent = currentIntent else { return }
        let values = item.values(for: intent.portionGrams)
        if !intent.items.isEmpty {
            intent.items[0] = VoicePlateItem(
                name: item.name,
                brand: item.brand,
                portionValue: intent.portionGrams,
                unit: item.defaultUnit,
                isLiquid: item.isLiquid,
                calories: values.calories,
                protein: values.protein,
                carbs: values.carbs,
                fat: values.fat
            )
            self.currentIntent = intent
        }
    }
    
    public func updateMealType(_ meal: MealType) {
        currentIntent?.mealType = meal
    }
    
    // MARK: - Algoritmos de Extração Linguística em Português
    
    private func extractMealType(from text: String) -> MealType {
        let lower = text.lowercased()
        
        if lower.contains("café da manhã") || lower.contains("cafe da manha") ||
            lower.contains("desjejum") || lower.contains("no café") || lower.contains("no cafe") {
            return .breakfast
        }
        
        if lower.contains("almoço") || lower.contains("almoco") ||
            lower.contains("almocei") || lower.contains("no almoço") || lower.contains("no almoco") {
            return .lunch
        }
        
        if lower.contains("jantar") || lower.contains("janta") ||
            lower.contains("jantei") || lower.contains("no jantar") || lower.contains("na janta") {
            return .dinner
        }
        
        if lower.contains("lanche") || lower.contains("lanchei") ||
            lower.contains("merenda") || lower.contains("ceia") || lower.contains("da tarde") {
            return .snacks
        }
        
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11:
            return .breakfast
        case 11..<15:
            return .lunch
        case 15..<19:
            return .snacks
        default:
            return .dinner
        }
    }
    
    private func extractPortionGrams(from text: String) -> Double {
        let lower = text.lowercased()
        
        let gramPattern = #"(\d+(?:[.,]\d+)?)\s*(?:gramas?|g\b|gr\b)"#
        if let regex = try? NSRegularExpression(pattern: gramPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: lower, options: [], range: NSRange(lower.startIndex..., in: lower)) {
            if let range = Range(match.range(at: 1), in: lower) {
                let numStr = String(lower[range]).replacingOccurrences(of: ",", with: ".")
                if let grams = Double(numStr), grams > 0 {
                    return grams
                }
            }
        }
        
        let colherPattern = #"(\d+|uma?|duas?|três|tres)\s*colher(?:es)?(?:\s*de\s*sopa)?"#
        if let regex = try? NSRegularExpression(pattern: colherPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: lower, options: [], range: NSRange(lower.startIndex..., in: lower)) {
            if let range = Range(match.range(at: 1), in: lower) {
                let word = String(lower[range])
                let count = parseQuantityWord(word)
                return count * 15.0
            }
        }
        
        let fatiaPattern = #"(\d+|uma?|duas?|três|tres)\s*fatia[s]?"#
        if let regex = try? NSRegularExpression(pattern: fatiaPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: lower, options: [], range: NSRange(lower.startIndex..., in: lower)) {
            if let range = Range(match.range(at: 1), in: lower) {
                let word = String(lower[range])
                let count = parseQuantityWord(word)
                return count * 35.0
            }
        }
        
        let ovoPattern = #"(\d+|um|dois|três|tres|quatro)\s*ovo[s]?"#
        if let regex = try? NSRegularExpression(pattern: ovoPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: lower, options: [], range: NSRange(lower.startIndex..., in: lower)) {
            if let range = Range(match.range(at: 1), in: lower) {
                let word = String(lower[range])
                let count = parseQuantityWord(word)
                return count * 50.0
            }
        }
        
        if lower.contains("banana") {
            let count = parseQuantityWordInContext(lower, around: "banana")
            return count * 90.0
        }
        if lower.contains("maçã") || lower.contains("maca") {
            let count = parseQuantityWordInContext(lower, around: "maç")
            return count * 130.0
        }
        
        let isolatedNumberPattern = #"^(\d+)\s*(?:de\s+)?"#
        if let regex = try? NSRegularExpression(pattern: isolatedNumberPattern, options: []),
           let match = regex.firstMatch(in: lower, options: [], range: NSRange(lower.startIndex..., in: lower)) {
            if let range = Range(match.range(at: 1), in: lower),
               let num = Double(lower[range]), num >= 10 {
                return num
            }
        }
        
        return 100.0
    }
    
    private func parseQuantityWord(_ word: String) -> Double {
        let w = word.trimmingCharacters(in: .whitespaces).lowercased()
        if let direct = Double(w) { return direct }
        switch w {
        case "um", "uma": return 1.0
        case "dois", "duas": return 2.0
        case "três", "tres": return 3.0
        case "quatro": return 4.0
        case "cinco": return 5.0
        default: return 1.0
        }
    }
    
    private func parseQuantityWordInContext(_ text: String, around keyword: String) -> Double {
        let pattern = #"(\d+|uma?|duas?|três|tres)\s*"# + keyword
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
            if let range = Range(match.range(at: 1), in: text) {
                return parseQuantityWord(String(text[range]))
            }
        }
        return 1.0
    }
    
    private func extractFoodQuery(from text: String) -> String {
        var clean = text.lowercased()
        
        let mealStopWords = [
            "no café da manhã", "no cafe da manha", "para o café da manhã", "para o cafe da manha",
            "no café", "no cafe", "de desjejum", "no almoço", "no almoco", "para o almoço", "para o almoco",
            "no jantar", "na janta", "para o jantar", "para a janta",
            "de lanche", "no lanche", "no lanchinho", "na ceia"
        ]
        for stop in mealStopWords {
            clean = clean.replacingOccurrences(of: stop, with: " ")
        }
        
        let verbStopWords = [
            "eu comi", "comi", "acabei de comer", "comemos", "consumi", "ingeri",
            "eu bebi", "bebi", "tomei", "adicione", "registre", "anote", "coloque",
            "por favor", "marca aí", "marca ai", "marca"
        ]
        for verb in verbStopWords {
            clean = clean.replacingOccurrences(of: verb, with: " ")
        }
        
        let measurePatterns = [
            #"\d+(?:[.,]\d+)?\s*(?:gramas?|g\b|gr\b|ml\b|mililitros?)"#,
            #"(?:\d+|uma?|duas?|três|tres)\s*colher(?:es)?(?:\s*de\s*sopa)?"#,
            #"(?:\d+|uma?|duas?|três|tres)\s*fatia[s]?"#,
            #"(?:\d+|uma?|duas?|três|tres)\s*unidade[s]?"#,
            #"\b\d+\s*de\b"#
        ]
        for pat in measurePatterns {
            if let regex = try? NSRegularExpression(pattern: pat, options: .caseInsensitive) {
                clean = regex.stringByReplacingMatches(in: clean, options: [], range: NSRange(clean.startIndex..., in: clean), withTemplate: " ")
            }
        }
        
        let prepositions = ["de", "da", "do", "com", "e", "um", "uma"]
        var words = clean.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        while let first = words.first, prepositions.contains(first) {
            words.removeFirst()
        }
        while let last = words.last, prepositions.contains(last) {
            words.removeLast()
        }
        
        return words.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func isPureMeasureQuery(_ text: String) -> Bool {
        let cleaned = text
            .replacingOccurrences(of: "gramas", with: "")
            .replacingOccurrences(of: "grama", with: "")
            .replacingOccurrences(of: "gr", with: "")
            .replacingOccurrences(of: "g", with: "")
            .replacingOccurrences(of: "ml", with: "")
            .replacingOccurrences(of: "mls", with: "")
            .replacingOccurrences(of: "de", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned) != nil || cleaned.isEmpty
    }
}
