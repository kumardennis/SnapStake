import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository class for user-related database operations
/// Handles CRUD operations for users using Supabase
class UsersRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Map<String, dynamic>?> upsertUserProfile({
    required String userId,
    required String email,
    String? firstname,
    String? lastname,
    String? avatarUrl,
  }) async {
    try {
      final userData = {
        'auth_id': userId,
        'email': email,
        'username': firstname ?? email.split('@').first,
        'firstname': firstname,
        'lastname': lastname,
        'avatar': avatarUrl,
      };

      final response =
          await _client.from('users').upsert(userData).select().single();

      print('✅ User profile upserted: ${response['email']}');
      return response;
    } catch (e) {
      print('❌ Error upserting user profile: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response =
          await _client
              .from('users')
              .select()
              .eq('auth_id', userId)
              .maybeSingle();

      if (response != null) {
        print('✅ Fetched user profile: ${response['username']}');
        return response;
      } else {
        print('ℹ️ No user profile found for: $userId');
        return null;
      }
    } catch (e) {
      print('❌ Error getting user profile: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .or('firstname.ilike.%$query%,username.ilike.%$query%')
          .order('firstname');

      print('🔍 Found ${response.length} users for query: "$query"');
      return response;
    } catch (e) {
      print('❌ Error searching users: $e');
      return [];
    }
  }

  /// Get user statistics (moments created, bets placed, etc.)
  Future<Map<String, dynamic>?> getUserStats(String userId) async {
    try {
      // This would use a database function or multiple queries
      final response = await _client.rpc(
        'get_user_statistics',
        params: {'user_id': userId},
      );

      return response;
    } catch (e) {
      print('❌ Error getting user stats: $e');
      return null;
    }
  }
}
