import Foundation
import SwiftUI
import Observation

// MARK: - Random Event

struct RandomEvent {
    let emoji: String
    let message: String
    let isPositive: Bool
    let effect: (GameState) -> Void
}

// MARK: - Game State

@Observable
final class GameState {

    // Identity
    var petName: String = "Vita"
    var createdAt: Date = Date()
    var lastSaved: Date = Date()

    // Stats 0–100
    var hunger:      Double = 80
    var happiness:   Double = 80
    var health:      Double = 100
    var energy:      Double = 80
    var cleanliness: Double = 80

    // Pet state
    var mood:      PetMood = .happy
    var isSick:    Bool = false
    var isSleeping: Bool = false
    var poopCount: Int = 0
    var lastPoopAt: Date = .distantPast

    // Progression
    var stage: LifeStage = .egg
    var evolutionPath: EvolutionPath = .default

    // Care log
    var careLog: CareLog = CareLog()

    // Economy
    var coins:            Double = 10
    var totalCoinsEarned: Double = 10

    // Records
    var miniGameHighScore: Int = 0
    var miniGameHighCombo: Int = 0

    // Achievements
    var unlockedAchievements: Set<String> = []

    // Events
    var lastEventAt: Date = .distantPast

    // ── UI state (not persisted) ──
    var showFoodMenu:     Bool = false
    var showMiniGame:     Bool = false
    var showAchievements: Bool = false
    var newAchievement:   AchievementDef? = nil
    var speechMessage:    String? = nil
    var eventMessage:     String? = nil
    var eventIsPositive:  Bool = true
    var celebrateStage:   Bool = false

    // Computed
    var ageInMinutes: Double { Date().timeIntervalSince(createdAt) / 60 }
    var isNight: Bool {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 6 || h >= 20
    }

    // MARK: - Decay constants
    private let dHunger      = 0.025
    private let dHappiness   = 0.015
    private let dHealth      = 0.004
    private let dEnergy      = 0.018
    private let dCleanliness = 0.010

    // MARK: - Game tick (called once per second)
    func tick() {
        applyDecay()
        checkPoop()
        checkSickness()
        updateMood()
        checkStageAdvance()
        rollRandomEvent()
        updateCareLog()
        checkAchievements()
    }

    // MARK: - Decay
    private func applyDecay() {
        let night = isNight
        let sl = isSleeping

        hunger      = max(0, hunger      - (sl ? dHunger * 0.3    : dHunger))
        happiness   = max(0, happiness   - (sl ? dHappiness * 0.5 : dHappiness) * (night ? 0.7 : 1))

        if sl {
            energy = min(100, energy + 0.10 * (night ? 1.3 : 1))
            careLog.sleepMinutes += 1.0 / 60.0
        } else {
            energy = max(0, energy - dEnergy * (night ? 0.4 : 1))
        }

        cleanliness = max(0, cleanliness - dCleanliness)

        if hunger < 20 || happiness < 20 || isSick {
            health = max(0, health - (isSick ? 0.03 : dHealth))
        } else if sl && hunger > 40 {
            health = min(100, health + 0.007)
        }

        careLog.cleanStreakMinutes = cleanliness >= 99
            ? careLog.cleanStreakMinutes + 1.0 / 60.0
            : 0
    }

    // MARK: - Poop
    private func checkPoop() {
        let minsSince = Date().timeIntervalSince(lastPoopAt) / 60
        let chance = 0.002 + (hunger > 80 ? 0.003 : 0)
        if poopCount < 3 && minsSince > 5 && Double.random(in: 0...1) < chance {
            poopCount += 1
            lastPoopAt = Date()
            cleanliness = max(0, cleanliness - 15)
            if poopCount >= 2 { speak("Eww… clean me! 🤢") }
        }
    }

    // MARK: - Sickness
    private func checkSickness() {
        if !isSick && health < 20 && Double.random(in: 0...1) < 0.012 {
            isSick = true
            AudioEngine.shared.play(.sick)
            showEvent("🤧 Feeling really sick…", positive: false)
        }
    }

    // MARK: - Mood
    func updateMood() {
        if isSleeping { mood = .sleeping; return }
        if isSick     { mood = .sick;     return }
        let mn  = min(hunger, happiness, health, energy)
        let avg = (hunger + happiness + health + energy) / 4
        if mn > 70 && avg > 75     { mood = .excited }
        else if mn > 50 && avg > 63 { mood = .happy   }
        else if mn < 25             { mood = .sad      }
        else                        { mood = .neutral  }
    }

    // MARK: - Stage advance
    private func checkStageAdvance() {
        let age = ageInMinutes
        let next: LifeStage
        switch age {
        case ..<5:    next = .egg
        case ..<60:   next = .baby
        case ..<480:  next = .child
        case ..<1440: next = .teen
        case ..<7200: next = .adult
        default:      next = .elder
        }
        guard next != stage else { return }
        stage = next
        if next != .egg { determinePath() }
        onStageAdvance(to: next)
    }

    private func determinePath() {
        if careLog.streak > 300 && careLog.neglect < 10 {
            evolutionPath = .perfect
        } else if careLog.exercises > 15 && health > 80 {
            evolutionPath = .healthy
        } else if careLog.junkFeeds > 10 && happiness > 65 {
            evolutionPath = .wild
        } else if careLog.sleepMinutes > 60 && energy > 70 {
            evolutionPath = .sleepy
        } else {
            evolutionPath = .default
        }
    }

    private func onStageAdvance(to newStage: LifeStage) {
        AudioEngine.shared.play(.levelUp)
        celebrateStage = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.celebrateStage = false }
        let msgs: [LifeStage: String] = [
            .baby:  "I hatched! Hello world! 🐣",
            .child: "I'm growing so fast!",
            .teen:  "Becoming a teenager! 😎",
            .adult: "I'm all grown up! 🎉",
            .elder: "Wise and old… 🌟",
        ]
        if let m = msgs[newStage] { speak(m) }
        if newStage == .adult {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.showEvent("Evolution: \(self.evolutionPath.label)!", positive: true)
            }
        }
    }

    // MARK: - Random events
    private var randomEvents: [RandomEvent] {[
        RandomEvent(emoji:"🪙", message:"Found a coin under the couch!",   isPositive:true,  effect:{ $0.coins += 3 }),
        RandomEvent(emoji:"💫", message:"Dreamed of flying through stars!", isPositive:true,  effect:{ $0.happiness = min(100,$0.happiness+15) }),
        RandomEvent(emoji:"☄️", message:"A meteor shower energizes you!",  isPositive:true,  effect:{ $0.energy    = min(100,$0.energy+20) }),
        RandomEvent(emoji:"🎁", message:"A mystery package arrived!",       isPositive:true,  effect:{ $0.coins += 5; $0.happiness = min(100,$0.happiness+8) }),
        RandomEvent(emoji:"🌟", message:"What a beautiful cosmic day!",     isPositive:true,  effect:{ $0.happiness = min(100,$0.happiness+10); $0.health = min(100,$0.health+5) }),
        RandomEvent(emoji:"🤧", message:"Achoo! Caught a little cold.",     isPositive:false, effect:{ s in s.health = max(0,s.health-18); if s.health < 30 { s.isSick = true } }),
        RandomEvent(emoji:"😰", message:"Had a terrible nightmare...",      isPositive:false, effect:{ $0.happiness = max(0,$0.happiness-20); $0.energy = max(0,$0.energy-10) }),
        RandomEvent(emoji:"💨", message:"Space dust got everywhere!",       isPositive:false, effect:{ $0.cleanliness = max(0,$0.cleanliness-28) }),
        RandomEvent(emoji:"😖", message:"Tummy hurts after eating...",      isPositive:false, effect:{ $0.health = max(0,$0.health-10); $0.happiness = max(0,$0.happiness-10) }),
        RandomEvent(emoji:"😴", message:"Took an unexpected cosmic nap!",   isPositive:true,  effect:{ $0.energy = min(100,$0.energy+18); $0.hunger = max(0,$0.hunger-8) }),
    ]}

    private func rollRandomEvent() {
        if isSleeping { return }
        let minsSince = Date().timeIntervalSince(lastEventAt) / 60
        guard minsSince >= 5, Double.random(in: 0...1) < 0.002,
              let ev = randomEvents.randomElement() else { return }
        ev.effect(self)
        lastEventAt = Date()
        careLog.eventCount += 1
        AudioEngine.shared.play(.event)
        showEvent("\(ev.emoji) \(ev.message)", positive: ev.isPositive)
    }

    // MARK: - Care log update
    private func updateCareLog() {
        let allGood = hunger>70 && happiness>70 && health>70 && energy>70 && cleanliness>70
        let anyBad  = hunger<25 || happiness<25 || health<25 || energy<25
        if allGood { careLog.streak += 1 } else { careLog.streak = max(0, careLog.streak - 2) }
        if anyBad  { careLog.neglect += 1 }
    }

    // MARK: - Achievements
    private func checkAchievements() {
        let h = Calendar.current.component(.hour, from: Date())
        let checks: [(String, Bool)] = [
            ("firstMeal",   careLog.feeds >= 1),
            ("playful",     careLog.games >= 1),
            ("mgPro",       miniGameHighScore >= 20),
            ("comboKing",   miniGameHighCombo >= 10),
            ("century",     coins >= 100),
            ("loaded",      totalCoinsEarned >= 500),
            ("survivor",    careLog.sickRecoveries >= 3),
            ("nightOwl",    h < 4),
            ("perfectPath", stage == .adult && evolutionPath == .perfect),
            ("wildPath",    stage == .adult && evolutionPath == .wild),
            ("healthyPath", stage == .adult && evolutionPath == .healthy),
            ("sleepyPath",  stage == .adult && evolutionPath == .sleepy),
            ("elder",       stage == .elder),
            ("weathered",   careLog.eventCount >= 10),
            ("spotless",    careLog.cleanStreakMinutes >= 30),
        ]
        for (id, met) in checks where met && !unlockedAchievements.contains(id) {
            unlockAchievement(id: id)
        }
    }

    func unlockAchievement(id: String) {
        unlockedAchievements.insert(id)
        if let def = allAchievements.first(where: { $0.id == id }) {
            AudioEngine.shared.play(.achievement)
            newAchievement = def
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                if self.newAchievement?.id == id { self.newAchievement = nil }
            }
        }
        save()
    }

    // MARK: - Activities

    func feed(_ food: FoodItem) {
        guard !isSleeping, hunger <= 95 else { return }
        if food.cost > 0 { coins -= Double(food.cost) }
        hunger      = min(100, hunger      + food.hungerGain)
        health      = min(100, max(0, health + food.healthGain))
        happiness   = min(100, happiness   + food.happinessGain)
        energy      = min(100, energy      + food.energyGain)
        if food.isJunk { careLog.junkFeeds += 1 }
        careLog.feeds += 1
        if hunger > 95 { happiness = max(0,happiness-5); health = max(0,health-2) }
        AudioEngine.shared.play(.feed)
        speak(food.isJunk ? "Mmm, so yummy! 😋" : "Nom nom nom! 🍽️")
        checkAchievements()
    }

    func toggleSleep() {
        isSleeping.toggle()
        if isSleeping {
            AudioEngine.shared.play(.sleep)
            speak("Goodnight… 💤")
        } else {
            AudioEngine.shared.play(.wake)
            speak("Good morning! ☀️")
            happiness = min(100, happiness + 8)
        }
        updateMood()
    }

    func clean() {
        guard !isSleeping else { return }
        cleanliness = min(100, cleanliness + 45)
        happiness   = min(100, happiness + 5)
        poopCount = 0
        AudioEngine.shared.play(.clean)
        speak("Squeaky clean! ✨")
    }

    func giveMedicine() {
        guard isSick, coins >= 5 else { return }
        coins -= 5; isSick = false
        health = min(100, health + 30)
        careLog.sickRecoveries += 1
        AudioEngine.shared.play(.medicine)
        speak("Feeling better! 💊")
        checkAchievements()
    }

    func exercise() {
        guard !isSleeping, energy >= 20 else { return }
        energy    = max(0, energy - 18)
        health    = min(100, health + 6)
        hunger    = max(0, hunger - 12)
        happiness = min(100, happiness + 8)
        careLog.exercises += 1
        AudioEngine.shared.play(.exercise)
        speak("Feeling strong! 💪")
        checkAchievements()
    }

    func rewardMiniGame(score: Int, combo: Int) {
        careLog.games += 1
        if score > miniGameHighScore { miniGameHighScore = score }
        if combo > miniGameHighCombo { miniGameHighCombo = combo }
        let earned = score / 3
        coins += Double(earned); totalCoinsEarned += Double(earned)
        happiness = min(100, happiness + min(Double(score), 20))
        energy    = max(0, energy - 10)
        if earned > 0 { AudioEngine.shared.play(.coin) }
        checkAchievements()
    }

    // MARK: - UI helpers
    func speak(_ msg: String) {
        speechMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if self.speechMessage == msg { self.speechMessage = nil }
        }
    }

    func showEvent(_ msg: String, positive: Bool) {
        eventMessage = msg; eventIsPositive = positive
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            if self.eventMessage == msg { self.eventMessage = nil }
        }
    }

    // MARK: - Persistence
    func save() {
        let snap = SavedState(
            petName: petName, createdAt: createdAt, lastSaved: Date(),
            hunger: hunger, happiness: happiness, health: health,
            energy: energy, cleanliness: cleanliness,
            isSick: isSick, isSleeping: isSleeping,
            poopCount: poopCount, lastPoopAt: lastPoopAt,
            stage: stage.rawValue, evolutionPath: evolutionPath.rawValue,
            careLog: careLog, coins: coins, totalCoinsEarned: totalCoinsEarned,
            miniGameHighScore: miniGameHighScore, miniGameHighCombo: miniGameHighCombo,
            unlockedAchievements: Array(unlockedAchievements),
            lastEventAt: lastEventAt
        )
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: "vitapets_v1")
        }
    }

    func load() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: "vitapets_v1"),
              let snap = try? JSONDecoder().decode(SavedState.self, from: data) else { return false }
        petName = snap.petName; createdAt = snap.createdAt; lastSaved = snap.lastSaved
        hunger = snap.hunger; happiness = snap.happiness; health = snap.health
        energy = snap.energy; cleanliness = snap.cleanliness
        isSick = snap.isSick; isSleeping = snap.isSleeping
        poopCount = snap.poopCount; lastPoopAt = snap.lastPoopAt
        stage = LifeStage(rawValue: snap.stage) ?? .egg
        evolutionPath = EvolutionPath(rawValue: snap.evolutionPath) ?? .default
        careLog = snap.careLog; coins = snap.coins; totalCoinsEarned = snap.totalCoinsEarned
        miniGameHighScore = snap.miniGameHighScore; miniGameHighCombo = snap.miniGameHighCombo
        unlockedAchievements = Set(snap.unlockedAchievements)
        lastEventAt = snap.lastEventAt
        // Offline decay
        let off = min(Date().timeIntervalSince(lastSaved), 8 * 3600)
        hunger      = max(0, hunger      - dHunger      * 0.5 * off)
        happiness   = max(0, happiness   - dHappiness   * 0.3 * off)
        energy      = max(0, energy      - dEnergy      * 0.4 * off)
        cleanliness = max(0, cleanliness - dCleanliness * 0.5 * off)
        if hunger < 20 || happiness < 20 { health = max(0, health - dHealth * 0.3 * off) }
        return true
    }

    func reset(name: String) {
        petName = name; createdAt = Date(); lastSaved = Date()
        hunger=80; happiness=80; health=100; energy=80; cleanliness=80
        isSick=false; isSleeping=false; poopCount=0; lastPoopAt = .distantPast
        stage = .egg; evolutionPath = .default; careLog = CareLog()
        coins=10; totalCoinsEarned=10; miniGameHighScore=0; miniGameHighCombo=0
        unlockedAchievements=[]; lastEventAt = .distantPast
        save()
    }
}
