# Buzz App - Dependencies

This document lists all external dependencies required for the Buzz app.

## Swift Package Manager Dependencies

Add these packages through Xcode (File → Add Package Dependencies):

### 1. Supabase Swift SDK
- **Repository**: https://github.com/supabase/supabase-swift
- **Version**: 2.0.0 or later
- **Purpose**: Backend services including authentication, database, and storage
- **Modules Used**:
  - Supabase
  - Auth
  - PostgREST
  - Storage
  - Realtime (optional, for future features)

### 2. Google Sign-In iOS SDK
- **Repository**: https://github.com/google/GoogleSignIn-iOS
- **Version**: 7.0.0 or later
- **Purpose**: Google OAuth authentication
- **Modules Used**:
  - GoogleSignIn

## Apple Frameworks (Built-in)

These are native iOS frameworks that don't require external installation:

- **SwiftUI**: Modern declarative UI framework
- **MapKit**: Map display and location services
- **CoreLocation**: Location services for bookings
- **AuthenticationServices**: Sign in with Apple
- **PhotosUI**: Photo library access
- **UniformTypeIdentifiers**: File type handling for document picker

## Minimum Requirements

- **iOS**: 16.0+
- **Xcode**: 15.0+
- **Swift**: 5.9+

## Installation Instructions

### Using Xcode

1. Open your project in Xcode
2. Select File → Add Package Dependencies
3. Enter the package URL
4. Select version or branch
5. Click "Add Package"
6. Select the modules you need
7. Click "Add Package" to confirm

### Package Resolution Issues

If you encounter package resolution issues:

```bash
# Delete derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# In Xcode:
# File → Packages → Reset Package Caches
# Clean Build Folder (Shift + Cmd + K)
# Rebuild (Cmd + B)
```

## Dependency Tree

```
Buzz
├── Supabase (2.0.0+)
│   ├── Auth
│   ├── PostgREST
│   ├── Storage
│   └── Functions
└── GoogleSignIn (7.0.0+)
```

## Security Considerations

- Always use the latest stable versions of dependencies
- Review package sources before adding them
- Keep dependencies updated for security patches
- Use Swift Package Manager's checksum verification

## Future Dependencies (Planned)

These dependencies may be added in future versions:

- **Firebase Cloud Messaging**: Push notifications
- **Stripe iOS SDK**: Payment processing
- **Charts**: Advanced analytics and statistics
- **Lottie**: Animated UI elements
- **Kingfisher** or **SDWebImage**: Advanced image loading and caching

## License Compliance

Ensure you comply with the licenses of all dependencies:

- **Supabase Swift SDK**: MIT License
- **Google Sign-In iOS SDK**: Apache License 2.0

Review each dependency's license file for full details.

## Version Compatibility Matrix

| Buzz Version | iOS | Xcode | Swift | Supabase SDK | Google Sign-In |
|--------------|-----|-------|-------|--------------|----------------|
| 1.0.0        | 16+ | 15+   | 5.9+  | 2.0+         | 7.0+           |

## Troubleshooting

### Common Issues

1. **"Module not found" error**
   - Solution: Reset package caches and clean build

2. **"Unable to resolve package dependencies"**
   - Solution: Check internet connection and package URLs

3. **Version conflicts**
   - Solution: Update to compatible versions or use exact version pins

4. **Build errors after updating packages**
   - Solution: Clean build folder and rebuild

## Support

For dependency-specific issues:
- **Supabase**: https://github.com/supabase/supabase-swift/issues
- **Google Sign-In**: https://github.com/google/GoogleSignIn-iOS/issues

