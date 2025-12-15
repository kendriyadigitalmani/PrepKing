// lib/screens/leaderboard/leaderboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import '../../providers/user_provider.dart';
import '../../core/services/api_service.dart';

class LeaderboardEntry {
  final int rank;
  final int userId;
  final String name;
  final String? profilePicture;
  final int score;
  final bool isCurrentUser;

  LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.name,
    this.profilePicture,
    required this.score,
    this.isCurrentUser = false,
  });
}

enum LeaderboardType { global, quiz, course }

// Providers remain unchanged
final currentUserIdProvider = FutureProvider<int?>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  return user?.id;
});

final globalLeaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) async {
  final api = ref.read(apiProvider);
  final response = await api.get('/leaderboard');
  final data = (response['data'] as List<dynamic>?) ?? [];
  return data.asMap().entries.map((e) {
    final index = e.key;
    final item = e.value as Map<String, dynamic>;
    return LeaderboardEntry(
      rank: index + 1,
      userId: int.tryParse(item['id']?.toString() ?? '0') ?? 0,
      name: item['name']?.toString() ?? 'Anonymous',
      profilePicture: item['profile_picture'] as String?,
      score: int.tryParse(item['total_score']?.toString() ?? '0') ??
          int.tryParse(item['score']?.toString() ?? '0') ??
          0,
    );
  }).toList();
});

final personalLeaderboardProvider = FutureProvider.family<List<LeaderboardEntry>, LeaderboardType>((ref, type) async {
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) return [];
  final api = ref.read(apiProvider);
  String path = '/leaderboard/$userId';
  if (type == LeaderboardType.quiz) path += '/quiz';
  if (type == LeaderboardType.course) path += '/course';
  final response = await api.get(path);
  final data = (response['data'] as List<dynamic>?) ?? [];
  return data.map((itemRaw) {
    final item = itemRaw as Map<String, dynamic>;
    final isCurrent = (int.tryParse(item['id']?.toString() ?? '0') ?? 0) == userId;
    return LeaderboardEntry(
      rank: int.tryParse(item['rank']?.toString() ?? '0') ?? 0,
      userId: int.tryParse(item['id']?.toString() ?? '0') ?? 0,
      name: item['name']?.toString() ?? 'Anonymous',
      profilePicture: item['profile_picture'] as String?,
      score: int.tryParse(item['score']?.toString() ?? '0') ??
          int.tryParse(item['total_score']?.toString() ?? '0') ??
          0,
      isCurrentUser: isCurrent,
    );
  }).toList();
});

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);
    return Scaffold(
      body: SafeArea( // 👈 ONLY CHANGE: Wrap in SafeArea
        child: Column(
          children: [
            // Gradient Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 48, bottom: 24), // 👈 ONLY CHANGE: Reduced padding
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFFa29bfe)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  FadeInDown(
                    child: const Icon(Icons.emoji_events_rounded, size: 90, color: Colors.amber),
                  ),
                  const SizedBox(height: 16),
                  FadeInUp(
                    child: const Text(
                      'Leaderboard',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  currentUserAsync.when(
                    data: (user) => FadeIn(
                      child: Text(
                        user != null
                            ? 'Streak: ${user.streak} 🔥 • Coins: ${user.coins} 🪙'
                            : 'Log in to compete',
                        style: const TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                    ),
                    loading: () => const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                    error: (_, __) => const Text('Stats unavailable', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(text: 'Global'),
                Tab(text: 'Quiz Masters'),
                Tab(text: 'Course Champions'),
              ],
            ),
            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLeaderboardTab(globalLeaderboardProvider, false),
                  _buildLeaderboardTab(personalLeaderboardProvider(LeaderboardType.quiz), true),
                  _buildLeaderboardTab(personalLeaderboardProvider(LeaderboardType.course), true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardTab(
      ProviderListenable<AsyncValue<List<LeaderboardEntry>>> provider,
      bool highlightCurrentUser,
      ) {
    final asyncValue = ref.watch(provider);
    return asyncValue.when(
      data: (entries) => _buildList(entries, highlightCurrentUser, provider),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sentiment_dissatisfied, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Failed to load leaderboard', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(provider as ProviderBase), // Safe cast
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(
      List<LeaderboardEntry> entries,
      bool highlightCurrentUser,
      ProviderListenable<AsyncValue<List<LeaderboardEntry>>> provider,
      ) {
    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'No rankings yet.\nBe the first! 🏆',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(provider as ProviderBase);
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final isTop3 = entry.rank <= 3;
          return FadeInLeft(
            duration: Duration(milliseconds: 500 + index * 100),
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: entry.isCurrentUser ? 12 : 4,
              color: entry.isCurrentUser
                  ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4)
                  : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                leading: Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: entry.profilePicture != null
                          ? NetworkImage(entry.profilePicture!)
                          : null,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: entry.profilePicture == null
                          ? Text(
                        entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      )
                          : null,
                    ),
                    if (isTop3)
                      Positioned(
                        right: -6,
                        bottom: -6,
                        child: Icon(
                          Icons.star_rounded,
                          size: 32,
                          color: entry.rank == 1
                              ? Colors.amber
                              : entry.rank == 2
                              ? Colors.grey.shade400
                              : const Color(0xFFCD7F32), // Bronze
                        ),
                      ),
                  ],
                ),
                title: Text(
                  entry.name,
                  style: TextStyle(
                    fontWeight: entry.isCurrentUser ? FontWeight.bold : FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: entry.isCurrentUser
                    ? const Text('You', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6C5CE7)))
                    : null,
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '#${entry.rank}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      '${entry.score} pts',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}