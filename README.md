# PayTrace

**PayTrace — UPI Payment Trigger Layer & Finance Tracker**

A comprehensive mobile application designed to streamline UPI payment processing, transaction tracking, and personal finance management. PayTrace provides users with intelligent payment automation, real-time transaction monitoring, and detailed financial insights through an intuitive and secure interface.

## 🎯 Overview

PayTrace is a feature-rich Flutter application that bridges UPI payment systems with advanced financial analytics. It enables users to:

- Process UPI payments seamlessly through QR code scanning and intent handling
- Track all payment transactions in a centralized database
- Monitor spending patterns with visual analytics and insights
- Manage contacts and payment recipients efficiently
- Secure sensitive data with encryption and biometric authentication
- Receive real-time notifications for payment events
- Export financial data for reporting and analysis

## ✨ Key Features

### 💳 Payment Management
- **UPI Integration**: Direct UPI payment processing with automatic transaction logging
- **QR Code Scanning**: Quick payment initiation through QR code recognition
- **Smart Contact Management**: Organize and manage payment recipients with easy access
- **Transaction History**: Comprehensive transaction logs with filtering and search capabilities

### 📊 Financial Analytics
- **Visual Insights**: Interactive charts and graphs for spending analysis
- **Summary Dashboard**: Quick overview of key financial metrics and trends
- **Detailed Reports**: Export transaction data in CSV format for external analysis
- **Payment Patterns**: Identify spending habits and financial trends

### 🔒 Security & Authentication
- **Biometric Lock**: Fingerprint/Face ID protection for app access
- **Secure Storage**: End-to-end encrypted storage for sensitive information
- **Permission-Based Access**: Granular control over app permissions
- **Secure Credential Management**: Safe storage of payment-related data

### 🔔 User Experience
- **Dark & Light Themes**: Customizable visual preferences
- **Onboarding Flow**: Intuitive setup wizard for new users
- **Background Tasks**: Automated background processing for notifications
- **Local Notifications**: Real-time alerts for payment events and updates

### 📱 Multi-Platform Support
- Android
- iOS
- Web
- Linux
- macOS
- Windows

## 🏗️ Architecture

PayTrace follows a **Clean Architecture** pattern with clear separation of concerns:

```
lib/
├── app/                    # App shell, routing, and navigation
├── core/                   # Core utilities, theme, constants
├── data/                   # Data layer (database, repositories)
├── features/               # Feature-specific business logic & UI
│   ├── home/              # Dashboard and main screen
│   ├── pay/               # Payment processing
│   ├── people/            # Contact management
│   ├── history/           # Transaction history
│   ├── insights/          # Analytics and reports
│   ├── summary/           # Financial summary
│   ├── settings/          # User preferences
│   └── onboarding/        # Initial setup flow
├── services/              # External services integration
├── state/                 # State management (Riverpod providers)
└── main.dart              # Application entry point
```

### State Management
- **Riverpod**: Modern, type-safe state management with provider pattern
- **Automatic Dependencies**: Built-in dependency injection and caching

### Database Layer
- **Drift (SQLite ORM)**: Type-safe database operations with compile-time verification
- **Reactive Queries**: Real-time data updates across the application

## 🛠️ Tech Stack

### Framework & Language
- **Flutter 3.9.2+**: Cross-platform mobile framework
- **Dart 3.9.2+**: Modern programming language

### State Management & DI
- `flutter_riverpod` (^2.5.1): Reactive state management
- `riverpod_annotation` & `riverpod_generator`: Code generation for providers

### Database & Storage
- `drift` (2.20.0): Type-safe SQLite ORM with code generation
- `sqlite3_flutter_libs` (^0.5.28): SQLite native bindings
- `flutter_secure_storage` (^9.2.2): Encrypted local storage
- `path_provider` (^2.1.5): Platform-specific file access

### Payment & QR Code
- `url_launcher` (^6.3.0): UPI intent handling
- `mobile_scanner` (^5.1.1): QR code scanning

### Security & Authentication
- `local_auth` (^3.0.1): Biometric authentication (fingerprint, face ID)
- `crypto` (^3.0.6): Cryptographic operations

### UI & Visualization
- `google_fonts` (^6.2.1): Custom fonts
- `fl_chart` (^0.70.2): Interactive charts and graphs
- `material` & `cupertino`: Material Design & iOS components

### Utilities
- `uuid` (^4.4.0): Unique identifier generation
- `share_plus` (^10.0.0): Social sharing functionality
- `csv` (^6.0.0): CSV file generation and parsing
- `permission_handler` (^11.3.1): Runtime permissions
- `flutter_contacts` (^1.1.9+2): Contact integration
- `flutter_local_notifications` (^18.0.1): Local push notifications
- `workmanager` (^0.6.0): Background task scheduling
- `intl` (^0.19.0): Internationalization support

## 📋 Prerequisites

Before running PayTrace, ensure you have:

- **Flutter SDK**: 3.9.2 or higher ([Download](https://flutter.dev/docs/get-started/install))
- **Dart SDK**: 3.9.2 or higher (included with Flutter)
- **Android Development Kit** (for Android builds)
- **Xcode** (for iOS/macOS builds)
- **Git**: For version control

## 🚀 Getting Started

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd PayTrace
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate code** (for Drift, Riverpod, and other builders)
   ```bash
   flutter pub run build_runner build
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

### Development Setup

#### Generate/Rebuild Database Models
```bash
flutter pub run build_runner watch
```
This watches for file changes and automatically regenerates Drift models and Riverpod providers.

#### Build for Release
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web
```

## 📦 Project Structure

### Features Module
Each feature is self-contained with its own:
- **UI Screens**: User interface components
- **Providers**: Riverpod state management
- **Models**: Data structures and entities
- **Repositories**: Data access patterns

### Core Module
- **Theme**: Application theming and styling
- **Constants**: Application-wide constants
- **Utils**: Reusable utility functions

### Data Layer
- **Database**: Drift database models and migrations
- **Repositories**: Abstract repositories for data access
- **Models**: Domain and data transfer objects

### Services Module
- **Payment Integration**: UPI and payment processing
- **Notification**: Push and local notification handling
- **Authentication**: Biometric and secure authentication

## 🔐 Security Considerations

- All sensitive data is encrypted and stored securely using `flutter_secure_storage`
- Biometric authentication provides an additional security layer
- API calls and payment intents follow secure UPI standards
- Regular security audits recommended for production deployments

## 📊 Testing

Run tests using:
```bash
flutter test
```

Test files are located in the `test/` directory and include:
- SMS transaction parsing tests
- Widget and integration tests
- Business logic tests

## 📄 Build Information

Latest build logs are available in:
- `build_log.txt`
- `build_log_2.txt`
- `build_log_3.txt`

## 🤝 Contributing

For contributions, please ensure:
1. Code follows Dart/Flutter style guidelines
2. All tests pass before submitting
3. Code is properly formatted using `dartfmt`
4. Commit messages are clear and descriptive

## 📝 License

This project is proprietary and confidential. Unauthorized copying or distribution is prohibited.

## 📞 Support & Contact

For issues, feature requests, or questions, please open an issue in the project repository or contact the development team.

---

**Version**: 1.0.0  
**Last Updated**: May 2026  
**Framework**: Flutter 3.9.2+
