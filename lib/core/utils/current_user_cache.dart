/// Simple in-memory cache for current user ID.
/// Provides fast synchronous access for API interceptors during requests.
/// Cleared on logout to prevent data leaks.
class CurrentUserCache {
  static int? userId;

  /// Sets the current logged-in user ID
  static void setUserId(int id) {
    userId = id;
  }

  /// Clears the cached user ID (call this on logout)
  static void clear() {
    userId = null;
  }
}