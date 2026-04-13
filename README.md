# Medicine Reminder App

A simple Flutter-based medicine reminder application designed to help users track and manage their medication schedules.

## Features

- **Medicine List**: View all your medicines with dosages and reminder times
- **Add Medicine**: Add new medicines with custom reminder times
- **Mark as Taken**: Quick button to mark medicines as taken
- **Reminder Times**: Set multiple reminder times for each medicine
- **Notes**: Add notes to medicines (e.g., "Take with food")
- **Delete Medicine**: Remove medicines from the list

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   └── medicine.dart         # Medicine data model
└── screens/
    ├── home_screen.dart      # Main screen with medicine list
    └── add_medicine_screen.dart # Screen to add new medicines
```

## Getting Started

### Prerequisites
- Flutter SDK (version 2.19.0 or higher)
- Dart SDK
- Android Studio / VS Code with Flutter extension

### Installation

1. Navigate to the project directory:
```bash
cd c:\Users\achan\Desktop\App
```

2. Get dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## Build

### Android
```bash
flutter build apk
```

### iOS
```bash
flutter build ios
```

## Usage

1. **Launch the app** - You'll see the home screen with sample medicines
2. **Add a medicine** - Click the floating action button (+) to add a new medicine
3. **Fill in details** - Enter medicine name, dosage, reminder times, and notes
4. **Set reminder times** - Tap on time slots to set custom times
5. **Save** - Click "Save Medicine" to add it to your list
6. **Mark as taken** - Click "Mark as Taken" button to track when you've taken a medicine
7. **Delete** - Click the delete icon to remove a medicine

## Sample Data

The app comes with two sample medicines:
- **Aspirin** - 500mg (reminders at 08:00 and 20:00)
- **Vitamin D** - 1000 IU (reminder at 09:00)

Feel free to delete these and add your own medicines.

## Future Enhancements

- Local notifications/alarms
- Persistent storage (local database)
- Medicine history/logs
- Search and filter functionality
- Dark mode support
- Push notifications

## Built With

- Flutter - UI framework
- Dart - Programming language

## License

This project is open source and available for personal use.
