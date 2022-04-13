//
//  AudioEngineController.swift
//  Vocable
//
//  Created by Chris Stroud on 12/17/20.
//  Copyright © 2020 WillowTree. All rights reserved.
//

import Foundation
import AVFoundation
import Speech

class AudioEngineController: NSObject, AVAudioPlayerDelegate {

    static let shared = AudioEngineController()

    @Published private(set) var audioBuffer: (buffer: AVAudioPCMBuffer, timestamp: AVAudioTime)?

    private let audioEngine = AVAudioEngine()
    private let audioSession = AVAudioSession.sharedInstance()
    private let conversionQueue = DispatchQueue(label: "SpeechConversion")

    private let internalQueueKey = DispatchSpecificKey<Void>()

    private lazy var internalQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "AudioEngineController_Internal", qos: .userInteractive)
        queue.setSpecific(key: self.internalQueueKey, value: ())
        return queue
    }()

    private var registeredSpeechControllers = Set<SpeechRecognitionController>()

    private var audioEngineShouldRun = false

    private var installedTapFormat: AVAudioFormat?

    private var audioPlayers = Set<AVAudioPlayer>()

    override init() {
        super.init()
        setupRouteChangeNotifications()
        updateAudioSession()
    }

    private func dispatchInternalAsync(_ actions: @escaping () -> Void) {
        let isInternal = DispatchQueue.getSpecific(key: internalQueueKey) != nil
        if isInternal {
            actions()
        } else {
            internalQueue.async(execute: actions)
        }
    }

    private func dispatchInternalSync(_ actions: @escaping () throws -> Void) rethrows {
        let isInternal = DispatchQueue.getSpecific(key: internalQueueKey) != nil
        if isInternal {
            try actions()
        } else {
            try internalQueue.sync(execute: actions)
        }
    }

    @objc private func handleRouteChange(notification: Notification) {
        dispatchInternalAsync { [weak self] in
            self?.updateInputNodeTapIfNeeded()
        }
    }

    private func setupRouteChangeNotifications() {
        let nc = NotificationCenter.default
        nc.addObserver(self,
                       selector: #selector(handleRouteChange),
                       name: .AVAudioEngineConfigurationChange,
                       object: nil)
    }

    @discardableResult
    private func updateInputNodeTapIfNeeded() -> Bool {

        let hasRecordPermission = AVAudioSession.sharedInstance().recordPermission == .granted
        guard hasRecordPermission else {
            return false
        }

        let node = audioEngine.inputNode
        let bus = 0
        let micInputFormat = node.inputFormat(forBus: bus)

        if micInputFormat.sampleRate == 0 {
            print("Audio engine input node sample rate 0. Cannot proceed.")
            return false
        }

        if let installedFormat = installedTapFormat, installedFormat == micInputFormat {
            return true
        }

        let speechInputFormat = SFSpeechAudioBufferRecognitionRequest().nativeAudioFormat
        let formatConverter = AVAudioConverter(from: micInputFormat, to: speechInputFormat)!

        node.removeTap(onBus: bus)
        node.installTap(onBus: bus, bufferSize: 1024, format: micInputFormat) { [weak self] buffer, timestamp in

            guard !AVSpeechSynthesizer.shared.isSpeaking else {
                return
            }

            self?.conversionQueue.async {
                let frameCapacity = AVAudioFrameCount(micInputFormat.sampleRate * 2.0)
                guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: speechInputFormat, frameCapacity: frameCapacity) else {
                    return
                }
                var error: NSError?

                var haveData = false
                let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                    if haveData {
                        outStatus.pointee = .noDataNow
                        return nil
                    }
                    outStatus.pointee = .haveData
                    haveData = true
                    return buffer
                }

                formatConverter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

                if let error = error {
                    assertionFailure(error.localizedDescription)
                } else {
                    self?.audioBuffer = (buffer: convertedBuffer, timestamp: timestamp)
                }
            }
        }

        installedTapFormat = micInputFormat
        audioEngine.prepare()
        return true
    }

    func register(speechRecognizer: SpeechRecognitionController, completion: @escaping (Bool) -> Void) {
        dispatchInternalAsync { [weak self] in
            guard let self = self else { return }
            self.registeredSpeechControllers.insert(speechRecognizer)
            self.updateAudioSession(completion: completion)
        }
    }

    func unregister(speechRecognizer: SpeechRecognitionController, completion: ((Bool) -> Void)? = nil) {
        dispatchInternalAsync { [weak self] in
            guard let self = self else { return }
            self.registeredSpeechControllers.remove(speechRecognizer)
            self.updateAudioSession(completion: completion)
        }
    }

    func playEffect(_ effect: SoundEffect, completion: @escaping () -> Void) {

        guard let data = effect.soundData else {
            return
        }
        print("Playing \"\(effect.rawValue).wav\"...")
        guard let player = try? AVAudioPlayer(data: data, fileTypeHint: "wav") else {
            return
        }
        player.delegate = self
        player.play()
        audioPlayers.insert(player)
    }

    private func updateAudioSession(completion: ((Bool) -> Void)? = nil) {

        dispatchInternalSync { [weak self] in
            var result = false
            var sessionNeedsActivation = false
            guard let self = self else {
                completion?(result)
                return
            }
            do {
                if self.registeredSpeechControllers.isEmpty {
                    if self.audioSession.category != .playback {
                        print("AUDIO SESSION CATEGORY: playback")
                        try self.audioSession.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
                        sessionNeedsActivation = true
                    }
                    self.audioEngineShouldRun = !self.registeredSpeechControllers.isEmpty
                    result = true
                } else {

                    if self.audioSession.category != .playAndRecord {
                        print("AUDIO SESSION CATEGORY: playAndRecord")
                        try self.audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
                        sessionNeedsActivation = true
                    }

                    if self.updateInputNodeTapIfNeeded() {
                        self.audioEngineShouldRun = true
                        result = true
                    } else {

                        // This is not the desired path if speech controllers are
                        // registered, but it ensures the audio session will at least
                        // be prepared for speech synthesis
                        if self.audioSession.category != .playback {
                            print("AUDIO SESSION CATEGORY: playback")
                            try self.audioSession.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
                            sessionNeedsActivation = true
                        }
                        result = false
                    }
                }

                if sessionNeedsActivation {
                    try self.audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                    print("AUDIO SESSION ACTIVATED")
                }
            } catch {
                assertionFailure("Failed to activate audio session: \(error)")
                result = false
            }
            result = true

            if self.audioEngineShouldRun {
                if !self.audioEngine.isRunning {
                    try? self.audioEngine.start()
                    print("AUDIO ENGINE STARTED")
                }
            } else {
                if self.audioEngine.isRunning {
                    self.audioEngine.pause()
                    print("AUDIO ENGINE PAUSED")
                }
            }

            completion?(result)
        }
    }

    // MARK: AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        audioPlayers.remove(player)
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        // no-op
    }
}
