//
//  VocableListCellContentView.swift
//  Vocable
//
//  Created by Jesse Morgan on 3/14/22.
//  Copyright © 2022 WillowTree. All rights reserved.
//
import UIKit

final class VocableListCellContentView: UIView, UIContentView {

    // MARK: - Properties

    var configuration: UIContentConfiguration {
        didSet {
            configure(with: configuration)
        }
    }

    // MARK: - Subviews

    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 8
        return stackView
    }()

    private lazy var accessoryButtonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 8
        return stackView
    }()

    private lazy var primaryLabelButton: GazeableButton = {
        let button = GazeableButton()
        button.contentHorizontalAlignment = .left
        return button
    }()

    // MARK: - Lifecycle

    init(configuration: UIContentConfiguration) {
        self.configuration = configuration
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = nil

        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        accessoryButtonStackView.isHidden = true
        stackView.addArrangedSubview(accessoryButtonStackView)

        stackView.addArrangedSubview(primaryLabelButton)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: self.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            stackView.bottomAnchor.constraint(equalTo: self.bottomAnchor).withPriority(999),
            stackView.trailingAnchor.constraint(equalTo: self.trailingAnchor).withPriority(999),
            accessoryButtonStackView.heightAnchor.constraint(equalTo: stackView.heightAnchor),
            primaryLabelButton.heightAnchor.constraint(equalTo: stackView.heightAnchor)
        ])

        configure(with: configuration)
    }

    private func configure(with configuration: UIContentConfiguration) {
        guard let configuration = configuration as? Configuration else {
            updateAccessoryButtons(with: nil)
            updatePrimaryLabelButton(with: nil)
            return
        }

        updateAccessoryButtons(with: configuration)
        updatePrimaryLabelButton(with: configuration)
    }

    private func updatePrimaryLabelButton(with configuration: Configuration?) {
        primaryLabelButton.contentHorizontalAlignment = .left
        primaryLabelButton.setAttributedTitle(configuration?.attributedText, for: .normal)
        primaryLabelButton.addTarget(self, action: #selector(handlePrimaryActionSelection(_:)), for: .primaryActionTriggered)
        primaryLabelButton.setTrailingAccessoryView(configuration?.trailingAccessory?.customView, insets: .init(top: 0, leading: 12, bottom: 0, trailing: 12))
    }

    private func updateAccessoryButtons(with configuration: Configuration?) {

        let accessories = configuration?.accessories ?? []

        // Ensure the minimum number of action buttons are present
        let numberOfButtonsNeeded = max(accessories.count - accessoryButtonStackView.arrangedSubviews.count, 0)
        (0 ..< numberOfButtonsNeeded).forEach { _ in
            insertAccessoryButton()
        }

        // Update existing buttons to match new states
        let arrangedButtons = accessoryButtonStackView.arrangedSubviews.compactMap { $0 as? GazeableButton }
        zip(accessories, arrangedButtons).forEach { (action, button) in
            button.isHidden = false
            button.setImage(action.image, for: .normal)

            // Using UIControlEvent to avoid having to de-duplicate UIAction invocations
            button.addTarget(self,
                             action: #selector(handleAccessoryActionSelection(_:)),
                             for: .primaryActionTriggered)
        }

        // Hide extraneous buttons, if present
        let numberOfButtonsToHide = min(arrangedButtons.count - accessories.count, 0)
        let buttonsToHide = arrangedButtons.suffix(numberOfButtonsToHide)
        buttonsToHide.forEach { button in
            button.isHidden = true
        }

        // If there are no buttons to display, hide their stack view
        accessoryButtonStackView.isHidden = arrangedButtons.allSatisfy(\.isHidden)
    }

    private func insertAccessoryButton() {
        let button = GazeableButton()
        accessoryButtonStackView.addArrangedSubview(button)
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalTo: button.widthAnchor, multiplier: 1),
            button.heightAnchor.constraint(equalTo: accessoryButtonStackView.heightAnchor)
        ])
    }

    // MARK: - Action Handlers

    @objc
    private func handlePrimaryActionSelection(_ sender: GazeableButton) {
        guard let configuration = configuration as? Configuration else {
            return
        }
        configuration.primaryAction()
    }

    @objc
    private func handleAccessoryActionSelection(_ sender: GazeableButton) {

        guard let buttonIndex = accessoryButtonStackView.arrangedSubviews.firstIndex(of: sender) else {
            return
        }
        guard let configuration = configuration as? Configuration else {
            return
        }
        guard let accessory = configuration.accessories[safe: buttonIndex] else {
            return
        }
        accessory.action?()
    }
}
