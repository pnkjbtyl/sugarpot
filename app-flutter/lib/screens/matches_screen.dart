import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/match_provider.dart';
import '../main.dart';
import '../utils/config.dart';
import 'chat_screen.dart';
import 'user_profile_details_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final matchProvider = Provider.of<MatchProvider>(context, listen: false);
      matchProvider.loadMyMatches();
      matchProvider.loadReceivedHearts(reset: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryColor,
          tabs: const [
            Tab(text: 'Matches'),
            Tab(text: 'Received Hearts'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMatchesTab(),
              _buildReceivedRequestsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatchesTab() {
    return Consumer<MatchProvider>(
      builder: (context, matchProvider, _) {
        if (matchProvider.isLoading && matchProvider.myMatches.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (matchProvider.myMatches.isEmpty && !matchProvider.isLoading) {
          return RefreshIndicator(
            onRefresh: () => matchProvider.loadMyMatches(),
            child: ListView(
              children: const [
                SizedBox(height: 200),
                Center(
                  child: Text('No matches yet. Start swiping!'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => matchProvider.loadMyMatches(),
          child: ListView.builder(
            itemCount: matchProvider.myMatches.length,
            itemBuilder: (context, index) {
            final match = matchProvider.myMatches[index];
            final user = match['user'];
            final location = match['location'];
            final profileImageUrl = user['profileImage'] != null
                ? AppConfig.buildImageUrl(user['profileImage'])
                : null;

            // Check if user was active in last 3 minutes
            final lastSeenAt = user['lastSeenAt'];
            final isActive = lastSeenAt != null && _isUserActive(lastSeenAt);
            
            // Debug logging
            if (lastSeenAt != null) {
              debugPrint('[MATCHES_SCREEN] User: ${user['name']}, lastSeenAt: $lastSeenAt, isActive: $isActive');
            }

            return ListTile(
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey[300],
                    child: profileImageUrl != null
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: profileImageUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              errorWidget: (context, url, error) => const Icon(Icons.person),
                            ),
                          )
                        : const Icon(Icons.person),
                  ),
                  // Green dot indicator for active users
                  if (isActive)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              title: Text(user['name'] ?? 'Unknown'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (location != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on, size: 16, color: primaryColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              location['name'] ?? 'Selected location',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      matchId: match['matchId'],
                      otherUser: user,
                      location: location,
                    ),
                  ),
                );
              },
            );
          },
          ),
        );
      },
    );
  }

  bool _isUserActive(dynamic lastSeenAt) {
    if (lastSeenAt == null) {
      debugPrint('[MATCHES_SCREEN] lastSeenAt is null');
      return false;
    }
    
    try {
      DateTime lastSeen;
      
      if (lastSeenAt is String) {
        lastSeen = DateTime.parse(lastSeenAt);
      } else if (lastSeenAt is Map) {
        // Handle MongoDB date object format
        final milliseconds = lastSeenAt['\$date'] ?? lastSeenAt['_seconds'] * 1000;
        lastSeen = DateTime.fromMillisecondsSinceEpoch(milliseconds is int ? milliseconds : milliseconds.toInt());
      } else if (lastSeenAt is int) {
        lastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenAt);
      } else {
        debugPrint('[MATCHES_SCREEN] Unknown lastSeenAt type: ${lastSeenAt.runtimeType}');
        return false;
      }
      
      final now = DateTime.now();
      final difference = now.difference(lastSeen);
      final minutesAgo = difference.inMinutes;
      
      debugPrint('[MATCHES_SCREEN] lastSeen: $lastSeen, now: $now, difference: ${difference.inMinutes} minutes');
      
      // User is active if last seen within 3 minutes
      final isActive = minutesAgo < 3;
      debugPrint('[MATCHES_SCREEN] isActive: $isActive (${minutesAgo} minutes ago)');
      
      return isActive;
    } catch (e, stackTrace) {
      debugPrint('[MATCHES_SCREEN] Error parsing lastSeenAt: $e');
      debugPrint('[MATCHES_SCREEN] Stack trace: $stackTrace');
      debugPrint('[MATCHES_SCREEN] lastSeenAt value: $lastSeenAt');
      return false;
    }
  }

  Widget _buildReceivedRequestsTab() {
    return Consumer<MatchProvider>(
      builder: (context, matchProvider, _) {
        // Show error if any
        if (matchProvider.error != null && matchProvider.receivedHearts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: ${matchProvider.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    matchProvider.loadReceivedHearts(reset: true);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (matchProvider.isLoading && matchProvider.receivedHearts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (matchProvider.receivedHearts.isEmpty && !matchProvider.isLoading) {
          return RefreshIndicator(
            onRefresh: () => matchProvider.loadReceivedHearts(reset: true),
            child: ListView(
              children: const [
                SizedBox(height: 200),
                Center(
                  child: Text('No heart requests yet.'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => matchProvider.loadReceivedHearts(reset: true),
          child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (!matchProvider.isLoadingMoreReceivedHearts &&
                matchProvider.hasMoreReceivedHearts &&
                scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
              // User has scrolled to the bottom, load more
              matchProvider.loadMoreReceivedHearts();
            }
            return false;
          },
          child: ListView.builder(
            itemCount: matchProvider.receivedHearts.length + (matchProvider.hasMoreReceivedHearts ? 1 : 0),
            itemBuilder: (context, index) {
              // Show loading indicator at the bottom if loading more
              if (index == matchProvider.receivedHearts.length) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
            final request = matchProvider.receivedHearts[index];
            final user = request['user'];
            final matchId = request['matchId'];
            final profileImageUrl = user['profileImage'] != null
                ? AppConfig.buildImageUrl(user['profileImage'])
                : null;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UserProfileDetailsScreen(user: user),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 30,
                    backgroundImage: profileImageUrl != null
                        ? CachedNetworkImageProvider(profileImageUrl)
                        : null,
                    child: profileImageUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                ),
                title: Text(user['name'] ?? 'Unknown'),
                subtitle: Text('Sent you a heart.'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () async {
                        try {
                          await matchProvider.declineHeart(matchId);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Heart from ${user['name'] ?? 'Unknown'} is declined'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.favorite, color: primaryColor),
                      onPressed: () async {
                        try {
                          // Send heart request back to accept
                          final response = await matchProvider.sendHeartRequest(
                            user['id'] ?? user['_id'],
                          );
                          if (mounted) {
                            if (response['match'] == true) {
                              // Navigate to Matches tab when it becomes a match
                              _tabController.animateTo(0);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('It\'s a match with ${user['name'] ?? 'User'}!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Heart request sent!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UserProfileDetailsScreen(user: user),
                    ),
                  );
                },
              ),
            );
          },
        ),
          ),
        );
      },
    );
  }
}
