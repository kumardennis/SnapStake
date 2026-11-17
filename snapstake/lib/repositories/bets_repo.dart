import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository class for bet-related database operations
/// Handles CRUD operations for bets using Supabase
class BetsRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // =================== BET CRUD OPERATIONS ===================

  /// Place a new bet on a moment
  Future<Map<String, dynamic>?> placeBet({
    required int momentId,
    required int userId,
    required String outcome, // 'yes' or 'no'
    required double amount,
  }) async {
    try {
      final betData = {
        'moment_id': momentId,
        'user_id': userId,
        'outcome': outcome,
        'amount': amount,
        'status': 'active',
      };

      final response =
          await _client.from('bets').insert(betData).select().single();

      print('✅ Bet placed successfully: ${response['id']}');
      return response;
    } catch (e) {
      print('❌ Error placing bet: $e');
      return null;
    }
  }

  /// Get all bets for a specific moment (only active bets)
  Future<List<Map<String, dynamic>>> getMomentBets(String momentId) async {
    try {
      final response = await _client
          .from('bets')
          .select('''
            *,
            users!inner(
              id,
              username,
              firstname,
              lastname,
              avatar
            )
          ''')
          .eq('moment_id', momentId)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      print('📊 Fetched ${response.length} active bets for moment: $momentId');
      return response;
    } catch (e) {
      print('❌ Error fetching moment bets: $e');
      return [];
    }
  }

  /// Get ALL bets for a specific moment (including resolved bets)
  Future<List<Map<String, dynamic>>> getAllMomentBets(String momentId) async {
    try {
      final response = await _client
          .from('bets')
          .select('''
            *,
            users!inner(
              id,
              username,
              firstname,
              lastname,
              avatar
            )
          ''')
          .eq('moment_id', momentId)
          .order('created_at', ascending: false);

      print('📊 Fetched ${response.length} total bets for moment: $momentId');
      return response;
    } catch (e) {
      print('❌ Error fetching all moment bets: $e');
      return [];
    }
  }

  /// Get all bets placed by a specific user
  Future<List<Map<String, dynamic>>> getUserBets(int userId) async {
    try {
      final response = await _client
          .from('bets')
          .select('''
            *,
            moments!inner(
              id,
              description,
              outcome_timestamp,
              status,
              video_link,
              creator_id
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      print('👤 Fetched ${response.length} bets for user: $userId');
      return response;
    } catch (e) {
      print('❌ Error fetching user bets: $e');
      return [];
    }
  }

  /// Get all bets placed by a specific user with calculated winnings
  Future<List<Map<String, dynamic>>> getUserBetsWithWinnings(int userId) async {
    try {
      // Get user's bets with moment info
      final response = await _client
          .from('bets')
          .select('''
            *,
            moments!inner(
              id,
              description,
              outcome_timestamp,
              outcome_result,
              status,
              video_link,
              creator_id
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      print('👤 Fetched ${response.length} bets for user: $userId');

      // For each bet, calculate actual winnings if it's a winning bet
      List<Map<String, dynamic>> enhancedBets = [];

      for (var bet in response) {
        Map<String, dynamic> enhancedBet = Map.from(bet);

        // Only calculate winnings for resolved moments
        if (bet['moments']['status'] == 'revealed' && bet['status'] == 'won') {
          final actualWinnings = await _calculateActualWinnings(bet);
          enhancedBet['actual_winnings'] = actualWinnings;
          enhancedBet['profit'] =
              actualWinnings - (bet['amount']?.toDouble() ?? 0.0);
        } else {
          enhancedBet['actual_winnings'] = 0.0;
          enhancedBet['profit'] =
              bet['status'] == 'lost'
                  ? -(bet['amount']?.toDouble() ?? 0.0)
                  : 0.0;
        }

        enhancedBets.add(enhancedBet);
      }

      return enhancedBets;
    } catch (e) {
      print('❌ Error fetching user bets with winnings: $e');
      return [];
    }
  }

  /// Calculate actual winnings for a specific bet based on pool system
  Future<double> _calculateActualWinnings(Map<String, dynamic> bet) async {
    try {
      final momentId = bet['moment_id'];
      final userOutcome = bet['outcome'];
      final userBetAmount = (bet['amount'] as num?)?.toDouble() ?? 0.0;
      final actualOutcome = bet['moments']['outcome_result'];

      // Only calculate if user won
      if (userOutcome != actualOutcome) return 0.0;

      // Get all bets for this moment (including resolved bets)
      final allBets = await getAllMomentBets(momentId.toString());

      // Separate winning and losing bets
      final winningBets =
          allBets.where((b) => b['outcome'] == actualOutcome).toList();
      final losingBets =
          allBets.where((b) => b['outcome'] != actualOutcome).toList();

      // Calculate pools
      final winningPool = winningBets.fold<double>(
        0.0,
        (sum, b) => sum + ((b['amount'] as num?)?.toDouble() ?? 0.0),
      );
      final losingPool = losingBets.fold<double>(
        0.0,
        (sum, b) => sum + ((b['amount'] as num?)?.toDouble() ?? 0.0),
      );

      if (winningPool <= 0)
        return userBetAmount; // Return original bet if no winning pool

      // Calculate proportional share: original bet + (user's share of losing pool)
      final userShare = userBetAmount / winningPool;
      final userWinnings = userBetAmount + (losingPool * userShare);

      print(
        '💰 Calculated winnings for bet ${bet['id']}: $userWinnings STK (original: $userBetAmount STK, share: ${(userShare * 100).toStringAsFixed(1)}%)',
      );

      return userWinnings;
    } catch (e) {
      print('❌ Error calculating actual winnings: $e');
      return 0.0;
    }
  }

  /// Get betting statistics for a moment
  Future<Map<String, dynamic>?> getMomentBettingStats(String momentId) async {
    try {
      // Get total counts and amounts for yes/no bets
      final response = await _client.rpc(
        'get_moment_betting_stats',
        params: {'moment_id': momentId},
      );

      return response;
    } catch (e) {
      print('❌ Error getting betting stats: $e');
      // Fallback: Calculate stats manually
      return await _calculateBettingStatsManually(momentId);
    }
  }

  /// Fallback method to calculate betting stats manually
  Future<Map<String, dynamic>> _calculateBettingStatsManually(
    String momentId,
  ) async {
    try {
      final bets = await _client
          .from('bets')
          .select('outcome, amount')
          .eq('moment_id', momentId)
          .eq('status', 'active');

      int totalBets = bets.length;
      double totalAmount = 0.0;
      int yesBets = 0;
      int noBets = 0;
      double yesAmount = 0.0;
      double noAmount = 0.0;

      for (final bet in bets) {
        final amount = (bet['amount'] as num).toDouble();
        totalAmount += amount;

        if (bet['outcome'] == 'yes') {
          yesBets++;
          yesAmount += amount;
        } else if (bet['outcome'] == 'no') {
          noBets++;
          noAmount += amount;
        }
      }

      return {
        'total_bets': totalBets,
        'total_amount': totalAmount,
        'yes_bets': yesBets,
        'no_bets': noBets,
        'yes_amount': yesAmount,
        'no_amount': noAmount,
        'yes_percentage': totalBets > 0 ? (yesBets / totalBets * 100) : 0.0,
        'no_percentage': totalBets > 0 ? (noBets / totalBets * 100) : 0.0,
      };
    } catch (e) {
      print('❌ Error calculating betting stats manually: $e');
      return {
        'total_bets': 0,
        'total_amount': 0.0,
        'yes_bets': 0,
        'no_bets': 0,
        'yes_amount': 0.0,
        'no_amount': 0.0,
        'yes_percentage': 0.0,
        'no_percentage': 0.0,
      };
    }
  }

  /// Update bet status (used for resolving bets when moment expires)
  Future<bool> updateBetStatus(String betId, String status) async {
    try {
      await _client
          .from('bets')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', betId);

      print('✅ Bet status updated: $betId -> $status');
      return true;
    } catch (e) {
      print('❌ Error updating bet status: $e');
      return false;
    }
  }

  /// Resolve all bets for a moment when the outcome is determined
  Future<bool> resolveMomentBets(int momentId, String actualOutcome) async {
    try {
      print('🎯 Starting bet resolution for moment: $momentId');
      print('   Actual outcome: $actualOutcome');

      // First, get all bets for this moment to see what we're working with
      final allBets = await _client
          .from('bets')
          .select('id, outcome, amount, status')
          .eq('moment_id', momentId);

      print('📊 Found ${allBets.length} total bets for moment $momentId:');
      final yesBets = allBets.where((b) => b['outcome'] == 'yes').length;
      final noBets = allBets.where((b) => b['outcome'] == 'no').length;
      final activeBets = allBets.where((b) => b['status'] == 'active').length;
      print('   - YES bets: $yesBets');
      print('   - NO bets: $noBets');
      print('   - Active bets: $activeBets');

      // Update winning bets
      print(
        '✅ Updating winning bets (outcome: ${actualOutcome.toLowerCase()})...',
      );
      final winningResponse = await _client
          .from('bets')
          .update({
            'status': 'won',
            'resolved_at': DateTime.now().toIso8601String(),
          })
          .eq('moment_id', momentId)
          .eq('outcome', actualOutcome.toLowerCase());

      // Update losing bets

      final losingOutcome = actualOutcome.toLowerCase() == 'yes' ? 'no' : 'yes';

      print(
        '❌ Updating losing bets (outcome: ${losingOutcome.toLowerCase()})...',
      );
      final losingResponse =
          await _client
              .from('bets')
              .update({
                'status': 'lost',
                'resolved_at': DateTime.now().toIso8601String(),
              })
              .eq('moment_id', momentId)
              .eq('outcome', losingOutcome.toLowerCase())
              .select();

      print('   Updated ${losingResponse.length} losing bets');

      print(
        '✅ Resolved all bets for moment: $momentId (outcome: $actualOutcome)',
      );
      return true;
    } catch (e) {
      print('❌ Error resolving moment bets: $e');
      return false;
    }
  }

  // =================== REAL-TIME SUBSCRIPTIONS ===================

  /// Subscribe to bet updates for real-time betting activity
  RealtimeChannel subscribeBets({
    required Function(Map<String, dynamic>) onInsert,
    required Function(Map<String, dynamic>) onUpdate,
  }) {
    return _client
        .channel('bets_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'bets',
          callback: (payload) => onInsert(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'bets',
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }
}
