import 'package:uuid/uuid.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/device_profile_repository.dart';

/// Service to manage the local device identity and user profile.
class DeviceService {
  final DeviceProfileRepository _repository;
  final Uuid _uuid;

  DeviceService({
    required DeviceProfileRepository repository,
    Uuid? uuid,
  })  : _repository = repository,
        _uuid = uuid ?? const Uuid();

  DeviceProfile? _cachedProfile;

  /// Returns the in-memory cached profile if available.
  DeviceProfile? get cachedProfile => _cachedProfile;

  /// Retrieves the existing device profile or creates a default one if none exists.
  Future<DeviceProfile> getOrCreateCurrentProfile() async {
    if (_cachedProfile != null) {
      return _cachedProfile!;
    }

    final existing = await _repository.getProfile();
    if (existing != null) {
      _cachedProfile = existing;
      return existing;
    }

    // Generate a default profile for this device
    final newId = 'dev_${_uuid.v4().substring(0, 8)}';
    final defaultName = 'Reader_${newId.substring(4)}';

    final created = await _repository.saveProfile(
      id: newId,
      displayName: defaultName,
    );
    _cachedProfile = created;
    return created;
  }

  /// Updates the display name of the local user.
  Future<void> updateDisplayName(String name) async {
    await _repository.updateDisplayName(name);
    _cachedProfile = await _repository.getProfile();
  }

  /// Clears in-memory cached profile (useful for testing).
  void clearCache() {
    _cachedProfile = null;
  }
}
