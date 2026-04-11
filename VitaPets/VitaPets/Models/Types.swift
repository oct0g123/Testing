import Foundation
import SwiftUI
import Observation

// MARK: - Enums

enum LifeStage: String, Codable, CaseIterable {
    case egg, baby, child, teen, adult, elder

    var label: String { rawValue.capitalized }

    var scale: CGFloat {
        switch self {
        case .egg:   return 0.65
        case .baby:  return 0.75
        case .child: return 0.90
        case .teen:  return 1.00
        case .adult: return 1.10
        case .elder: return 1.05
        }
    }
}

enum EvolutionPath: String, Codable {
    case `default`, perfect, wild, healthy, sleepy

    var label: String {
        switch self {
        case .default: return "Classic"
        case .perfect: return "Perfect ⭐"
        case .wild:    return "Wild 🌿"
        case .healthy: return "Strong 💪"
        case .sleepy:  return "Dreamy 💤"
        }
    }

    var bodyColor: Color {
        switch self {
        case .default: return Color(red: 0.48, green: 0.55, blue: 0.87)
        case .perfect: return Color(red: 0.83, green: 0.66, blue: 0.94)
        case .wild:    return Color(red: 0.49, green: 0.78, blue: 0.47)
        case .healthy: return Color(red: 0.94, green: 0.78, blue: 0.44)
        case .sleepy:  return Color(red: 0.44, green: 0.78, blue: 0.80)
        }
    }

    var bellyColor: Color {
        switch self {
        case .default: return Color(red: 0.66, green: 0.71, blue: 0.94)
        case .perfect: return Color(red: 0.93, green: 0.83, blue: 1.00)
        case .wild:    return Color(red: 0.68, green: 0.91, bert: 0.66)
        case .healthy: return Color(red: 1.00, green: 0.91, blue: 0.66)
        case .sleepy:  return Color(red: 0.66, green: 0.91, blue: 0.93)
        }
    }

    var auraColor: Color {
        switch self {
        case .default: return Color(red: 0.39, green: 0.47, blue: 0.94).opacity(0.28)
        case .perfect: return Color(red: 0.83, green: 0.66, blue: 0.94).opacity(0.38)
        case .wild:    return Color(red: 0.39, green: 0.78, blue: 0.31).opacity(0.28)
        case .healthy: return Color(red: 0.94, green: 0.75, blue: 0.31).opacity(0.28)
        case .sleepy:  return Color(red: 0.31, green: 0.75, blue: 0.78).opacity(0.28)
        }
    }

    enum EarStyle { case round, sharp, floppy }
    var earStyle: EarStyle {
        switch self {
        case .wild:   return .sharp
        case .sleepy: return .floppy
        default:      return .round
        }
    }
}

// Fix typo in bellyColor - needs extension
extension EvolutionPath {
    // bellyColor helper (wild fixed)
    var bellyColorFixed: Color {
        switch self {
        case .default: return Color(red: 0.66, green: 0.71, blue: 0.94)
        case .perfect: return Color(red: 0.93, green: 0.83, blue: 1.00)
        case .wild:    return Color(red: 0.68, green: 0.91, blue: 0.66)
        case .healthy: return Color(red: 1.00, green: 0.91, blue: 0.66)
        case .sleepy:  return Color(red: 0.66, green: 0.91, blue: 0.93)
        }
    }
}

enum PetMood {
    case excited, happy, neutral, sad, sick, sleeping

    var emoji: String {
        switch self {
        case .excited:  return "🤩"
        case .happy:    return "😊"
        case .neutral:  return "😐"
        case .sad:      return "😢"
        case .sick:     return "🤢"
        case .sleeping: return "😴"
        }
    }
    var label: String {
        switch self {
        case .excited:  return "Excited!"
        case .happy:    return "Happy"
        case .neutral:  return "Okay"
        case .sad:      return "Sad"
        case .sick:     return "Sick"
        case .sleeping: return "Sleeping"
        }
    }
}

// MARK: - Food

struct FoodItem: Identifiable {
    let id: String
    let emoji: String
    let name: String
    let cost: Int
    let hungerGain: Double
    let healthGain: Double
    let happinessGain: Double
    let energyGain: Double
    let isJunk: Bool
    let description: String
}

let allFoods: [FoodItem] = [
    FoodItem(id:"meal",   emoji:"🥩", name:"Full Meal",   cost:0, hungerGain:35, healthGain: 3,  happinessGain: 5,  energyGain: 5,  isJunk:false, description:"+35 hunger · +3 health"),
    FoodItem(id:"snack",  emoji:"🍪", name:"Snack",       cost:0, hungerGain:15, healthGain: 0,  happinessGain:12,  energyGain: 2,  isJunk:false, description:"+15 hunger · +12 happy"),
    FoodItem(id:"veggie", emoji:"🥦", name:"Veggies",     cost:3, hungerGain:20, healthGain:10,  happinessGain: 3,  energyGain: 3,  isJunk:false, description:"+20 hunger · +10 health"),
    FoodItem(id:"treat",  emoji:"🍬", name:"Sweet Treat", cost:2, hungerGain: 8, healthGain:-2,  happinessGain:22,  energyGain: 5,  isJunk:true,  description:"+22 happy (junk!)"),
    FoodItem(id:"candy",  emoji:"🍭", name:"Space Candy", cost:1, hungerGain: 5, healthGain:-4,  happinessGain:28,  energyGain:10,  isJunk:true,  description:"+28 happy (very junk!)"),
]

// MARK: - Achievements

struct AchievementDef: Identifiable {
    let id: String
    let emoji: String
    let label: String
    let description: String
}

let allAchievements: [AchievementDef] = [
    AchievementDef(id:"firstMeal",   emoji:"🍖", label:"First Supper",  description:"Feed your pet for the first time"),
    AchievementDef(id:"playful",     emoji:"🎮", label:"Playtime!",      description:"Play the mini-game once"),
    AchievementDef(id:"mgPro",       emoji:"🎯", label:"Treat Catcher",  description:"Score 20+ in one mini-game"),
    AchievementDef(id:"comboKing",   emoji:"🔥", label:"Combo King",     description:"Hit a 10x combo in mini-game"),
    AchievementDef(id:"century",     emoji:"💰", label:"Century",        description:"Hold 100 coins at once"),
    AchievementDef(id:"loaded",      emoji:"👑", label:"Loaded",         description:"Earn 500 total coins"),
    AchievementDef(id:"survivor",    emoji:"💊", label:"Survivor",       description:"Recover from sickness 3 times"),
    AchievementDef(id:"nightOwl",    emoji:"🦉", label:"Night Owl",      description:"Care for your pet after midnight"),
    AchievementDef(id:"perfectPath", emoji:"⭐", label:"Immaculate",     description:"Reach Adult via Perfect path"),
    AchievementDef(id:"wildPath",    emoji:"🌿", label:"Feral Spirit",   description:"Reach Adult via Wild path"),
    AchievementDef(id:"healthyPath", emoji:"💪", label:"Iron Body",      description:"Reach Adult via Healthy path"),
    AchievementDef(id:"sleepyPath",  emoji:"💤", label:"Dreamer",        description:"Reach Adult via Sleepy path"),
    AchievementDef(id:"elder",       emoji:"🌟", label:"Silver Scales",  description:"Reach the Elder life stage"),
    AchievementDef(id:"weathered",   emoji:"⚡", label:"Weathered",      description:"Experience 10 random events"),
    AchievementDef(id:"spotless",    emoji:"✨", label:"Spotless",       description:"Keep cleanliness at 100 for 30 min"),
]

// MARK: - Care Log

struct CareLog: Codable {
    var streak: Int = 0
    var neglect: Int = 0
    var sleepMinutes: Double = 0
    var exercises: Int = 0
    var junkFeeds: Int = 0
    var feeds: Int = 0
    var games: Int = 0
    var sickRecoveries: Int = 0
    var eventCount: Int = 0
    var cleanStreakMinutes: Double = 0
}

// MARK: - Saved State (Codable snapshot)

struct SavedState: Codable {
    var petName: String
    var createdAt: Date
    var lastSaved: Date
    var hunger, happiness, health, energy, cleanliness: Double
    var isSick, isSleeping: Bool
    var poopCount: Int
    var lastPoopAt: Date
    var stage: String
    var evolutionPath: String
    var careLog: CareLog
    var coins, totalCoinsEarned: Double
    var miniGameHighScore, miniGameHighCombo: Int
    var unlockedAchievements: [String]
    var lastEventAt: Date
}
