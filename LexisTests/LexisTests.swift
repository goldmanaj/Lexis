//
//  LexisTests.swift
//  LexisTests
//
//  Created by Aaron Goldman on 3/28/26.
//

import Testing
import Foundation
@testable import Lexis

struct LexisTests {

    @Test func testWordBankFallbackReturnsValidWord() {
        let fallbackWord = WordBank.getRandomWord()
        #expect(!fallbackWord.word.isEmpty)
        #expect(!fallbackWord.definition.isEmpty)
        #expect(fallbackWord.wrongAnswers.count >= 3)
    }

    @Test func testWordBankFallbackExcludesSeenWords() {
        let seen = Set(WordBank.words.dropLast().map { $0.word.lowercased() })
        let fallbackWord = WordBank.getRandomWord(excluding: seen)
        #expect(fallbackWord.word.lowercased() == WordBank.words.last?.word.lowercased())
    }

    @Test @MainActor func testWordStoreInitialization() {
        let store = WordStore()
        #expect(store.isLoading == false)
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor func testStreakCalculation() {
        let store = WordStore()
        store.archive = []
        
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
        
        store.archive.append(contentsOf: [
            WordEntry(id: UUID(), word: "One", phonetic: "", partOfSpeech: "", definition: "", etymology: "", exampleSentence: "", wrongAnswers: [], date: today),
            WordEntry(id: UUID(), word: "Two", phonetic: "", partOfSpeech: "", definition: "", etymology: "", exampleSentence: "", wrongAnswers: [], date: yesterday),
            WordEntry(id: UUID(), word: "Three", phonetic: "", partOfSpeech: "", definition: "", etymology: "", exampleSentence: "", wrongAnswers: [], date: twoDaysAgo)
        ])
        
        #expect(store.streakCount == 3)
    }
}
