/// Conditional preferences storage backend.
///
/// Native platforms use the SQLite-backed implementation
/// ([preferences_dao_io.dart]); the web uses a SharedPreferences-backed
/// implementation ([preferences_dao_web.dart]) because sqflite and
/// path_provider have no web implementations.
export 'preferences_dao_io.dart'
    if (dart.library.js_interop) 'preferences_dao_web.dart';
