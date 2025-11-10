//
//  ViewController.swift
//  Acceptance
//
//  Created by Виталий Одегов on 10.11.2025.
//

import UIKit
import LocalAuthentication

final class ViewController: UIViewController {

    private enum AuthState {
        case login
        case createPin
        case confirmPin
        case pinEntry
        case authenticated
    }

    private let validUsername = "user"
    private let validPassword = "password"

    private var state: AuthState = .login {
        didSet { updateUI(for: state) }
    }

    private var storedPin: String? {
        didSet { updateBiometricButtonVisibility() }
    }
    private var temporaryPin: String?

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .title2)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let usernameField: UITextField = {
        let field = UITextField()
        field.placeholder = "Логин"
        field.borderStyle = .roundedRect
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.textContentType = .username
        return field
    }()

    private let passwordField: UITextField = {
        let field = UITextField()
        field.placeholder = "Пароль"
        field.borderStyle = .roundedRect
        field.isSecureTextEntry = true
        field.textContentType = .password
        return field
    }()

    private let pinField: UITextField = {
        let field = UITextField()
        field.placeholder = "Введите 4-значный код"
        field.borderStyle = .roundedRect
        field.keyboardType = .numberPad
        field.textAlignment = .center
        field.textContentType = .oneTimeCode
        return field
    }()

    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.layer.cornerRadius = 8
        button.backgroundColor = .systemBlue
        button.tintColor = .white
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return button
    }()

    private let biometricsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitleColor(.systemBlue, for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .body)
        return button
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        configureActions()
        loadStoredPin()
        evaluateBiometricAvailability()
        state = storedPin == nil ? .login : .pinEntry
    }

    private func setupView() {
        view.backgroundColor = .systemBackground
        view.addSubview(stackView)

        [titleLabel, usernameField, passwordField, pinField, actionButton, biometricsButton, statusLabel].forEach { stackView.addArrangedSubview($0) }

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        actionButton.setTitle("Продолжить", for: .normal)
        pinField.addTarget(self, action: #selector(pinFieldChanged(_:)), for: .editingChanged)
    }

    private func configureActions() {
        actionButton.addTarget(self, action: #selector(handlePrimaryAction), for: .touchUpInside)
        biometricsButton.addTarget(self, action: #selector(handleBiometricAuthentication), for: .touchUpInside)
    }

    private func loadStoredPin() {
        do {
            storedPin = try KeychainHelper.shared.loadPin()
        } catch {
            statusLabel.text = "Не удалось загрузить PIN-код"
        }
    }

    private func updateUI(for state: AuthState) {
        pinField.text = ""
        statusLabel.text = ""

        switch state {
        case .login:
            titleLabel.text = "Вход"
            actionButton.setTitle("Войти", for: .normal)
            usernameField.isHidden = false
            passwordField.isHidden = false
            pinField.isHidden = true
            biometricsButton.isHidden = true
        case .createPin:
            titleLabel.text = "Создайте 4-значный код"
            actionButton.setTitle("Сохранить код", for: .normal)
            usernameField.isHidden = true
            passwordField.isHidden = true
            pinField.isHidden = false
            pinField.placeholder = "Придумайте код"
            biometricsButton.isHidden = true
        case .confirmPin:
            titleLabel.text = "Подтвердите код"
            actionButton.setTitle("Подтвердить", for: .normal)
            usernameField.isHidden = true
            passwordField.isHidden = true
            pinField.isHidden = false
            pinField.placeholder = "Повторите код"
            biometricsButton.isHidden = true
        case .pinEntry:
            titleLabel.text = "Введите PIN-код"
            actionButton.setTitle("Разблокировать", for: .normal)
            usernameField.isHidden = true
            passwordField.isHidden = true
            pinField.isHidden = false
            pinField.placeholder = "Введите код"
            updateBiometricButtonVisibility()
        case .authenticated:
            titleLabel.text = "Добро пожаловать!"
            actionButton.setTitle("Выйти", for: .normal)
            usernameField.isHidden = true
            passwordField.isHidden = true
            pinField.isHidden = true
            biometricsButton.isHidden = true
            statusLabel.text = "Аутентификация успешно выполнена"
        }
    }

    private func updateBiometricButtonVisibility() {
        guard state == .pinEntry, storedPin != nil else {
            biometricsButton.isHidden = true
            return
        }
        biometricsButton.isHidden = !isBiometricsAvailable
    }

    private var isBiometricsAvailable = false

    private func evaluateBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            isBiometricsAvailable = true
            let title: String
            switch context.biometryType {
            case .faceID:
                title = "Войти с Face ID"
            case .touchID:
                title = "Войти с Touch ID"
            default:
                title = "Войти по биометрии"
            }
            biometricsButton.setTitle(title, for: .normal)
        } else {
            isBiometricsAvailable = false
        }
    }

    @objc private func pinFieldChanged(_ textField: UITextField) {
        guard let text = textField.text else { return }
        let filtered = text.filter { $0.isNumber }
        if filtered.count > 4 {
            textField.text = String(filtered.prefix(4))
        } else if filtered != text {
            textField.text = filtered
        }
    }

    @objc private func handlePrimaryAction() {
        switch state {
        case .login:
            handleLogin()
        case .createPin:
            handleCreatePin()
        case .confirmPin:
            handleConfirmPin()
        case .pinEntry:
            handlePinEntry()
        case .authenticated:
            handleLogout()
        }
    }

    private func handleLogin() {
        guard let username = usernameField.text, let password = passwordField.text, !username.isEmpty, !password.isEmpty else {
            statusLabel.text = "Введите логин и пароль"
            return
        }

        guard username == validUsername, password == validPassword else {
            statusLabel.text = "Неверные логин или пароль"
            return
        }

        usernameField.text = ""
        passwordField.text = ""
        state = .createPin
    }

    private func handleCreatePin() {
        guard let pin = pinField.text, pin.count == 4 else {
            statusLabel.text = "Код должен состоять из 4 цифр"
            return
        }
        temporaryPin = pin
        state = .confirmPin
    }

    private func handleConfirmPin() {
        guard let confirmation = pinField.text, confirmation.count == 4 else {
            statusLabel.text = "Код должен состоять из 4 цифр"
            return
        }

        guard confirmation == temporaryPin else {
            statusLabel.text = "Коды не совпадают"
            return
        }

        do {
            try KeychainHelper.shared.savePin(confirmation)
            storedPin = confirmation
            temporaryPin = nil
            state = .pinEntry
            statusLabel.text = "PIN-код сохранен"
        } catch {
            statusLabel.text = "Не удалось сохранить PIN-код"
        }
    }

    private func handlePinEntry() {
        guard let input = pinField.text, input.count == 4 else {
            statusLabel.text = "Введите корректный код"
            return
        }

        guard let storedPin, input == storedPin else {
            statusLabel.text = "Неверный код"
            return
        }

        state = .authenticated
    }

    private func handleLogout() {
        do {
            try KeychainHelper.shared.deletePin()
        } catch {
            statusLabel.text = "Не удалось удалить PIN-код"
        }
        storedPin = nil
        temporaryPin = nil
        state = .login
    }

    @objc private func handleBiometricAuthentication() {
        let context = LAContext()
        context.localizedFallbackTitle = "Введите PIN-код"
        let reason = "Авторизуйтесь, чтобы разблокировать"

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.state = .authenticated
                } else if let error = error {
                    self?.statusLabel.text = self?.localizedError(from: error) ?? "Не удалось выполнить вход"
                } else {
                    self?.statusLabel.text = "Аутентификация отменена"
                }
            }
        }
    }

    private func localizedError(from error: Error) -> String {
        let nsError = error as NSError
        switch nsError.code {
        case LAError.authenticationFailed.rawValue:
            return "Не удалось подтвердить личность"
        case LAError.userCancel.rawValue:
            return "Аутентификация отменена"
        case LAError.userFallback.rawValue:
            return "Используйте PIN-код"
        case LAError.biometryLockout.rawValue:
            return "Биометрия временно недоступна"
        default:
            return nsError.localizedDescription
        }
    }
}
