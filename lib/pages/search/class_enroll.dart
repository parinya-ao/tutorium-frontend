import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:tutorium_frontend/pages/home/teacher/register/payment_screen.dart';
import 'package:tutorium_frontend/pages/profile/teacher_profile.dart';
import 'package:tutorium_frontend/pages/search/enrollment_error_handler.dart';
import 'package:tutorium_frontend/pages/widgets/class_session_service.dart';
import 'package:tutorium_frontend/models/class_models.dart' as class_models;
import 'package:tutorium_frontend/service/api_client.dart';
import 'package:tutorium_frontend/service/enrollments.dart' as enrollment_api;
import 'package:tutorium_frontend/service/notifications.dart'
    as notification_api;
import 'package:tutorium_frontend/service/users.dart' as user_api;
import 'package:tutorium_frontend/util/cache_user.dart';
import 'package:tutorium_frontend/util/local_storage.dart';

class Review {
  final int? id;
  final int? classId;
  final int? learnerId;
  final int? userId;
  final int? rating;
  final String? comment;

  Review({
    this.id,
    this.classId,
    this.learnerId,
    this.userId,
    this.rating,
    this.comment,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: int.tryParse(json['ID']?.toString() ?? '0'),
      classId: int.tryParse(json['class_id']?.toString() ?? '0'),
      learnerId: int.tryParse(json['learner_id']?.toString() ?? '0'),
      userId: int.tryParse(
        (json['Learner'] != null ? json['Learner']['user_id'] : '0').toString(),
      ),
      rating: int.tryParse(json['rating']?.toString() ?? '0'),
      comment: json['comment'],
    );
  }
}

class _CapacityCheckResult {
  final int currentCount;
  final int limit;
  final bool isFull;

  _CapacityCheckResult({
    required this.currentCount,
    required this.limit,
    required this.isFull,
  });
}

class _EnrollmentTransactionResult {
  final bool success;
  final EnrollmentError? error;

  _EnrollmentTransactionResult({required this.success, this.error});
}

class User {
  final int id;
  final String firstName;
  final String lastName;
  final String? profilePicture;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.profilePicture,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final idValue = json['ID'] ?? json['id'] ?? 0;
    return User(
      id: (idValue is String) ? int.tryParse(idValue) ?? 0 : idValue,
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      profilePicture: json['profile_picture']?.toString(),
    );
  }

  String get fullName => "$firstName $lastName".trim();
}

class ClassEnrollPage extends StatefulWidget {
  final int classId;
  final String teacherName;
  final double rating;

  const ClassEnrollPage({
    super.key,
    required this.classId,
    required this.teacherName,
    required this.rating,
  });

  @override
  State<ClassEnrollPage> createState() => _ClassEnrollPageState();
}

class _ClassEnrollPageState extends State<ClassEnrollPage> {
  class_models.ClassSession? selectedSession;
  ClassInfo? classInfo;
  UserInfo? userInfo;
  List<class_models.ClassSession> sessions = [];
  List<Review> reviews = [];
  List<User> users = [];
  Map<int, User> usersMap = {};
  final Map<int, User> _userCache = {};
  final Map<int, Future<User?>> _userRequests = {};
  final Map<int, String> _teacherNameCache = {};
  final Map<int, Future<String?>> _teacherNameRequests = {};
  bool isLoadingReviews = true;
  bool isLoading = true;
  bool showAllReviews = false;
  bool hasError = false;
  String errorMessage = '';
  bool isProcessingEnrollment = false;
  String teacherName = '';

  @override
  void initState() {
    super.initState();
    teacherName = widget.teacherName;
    loadAllData();
  }

  Future<void> loadAllData() async {
    setState(() {
      isLoading = true;
      isLoadingReviews = true;
      hasError = false;
    });

    try {
      final classDataFuture = fetchClassData();
      final reviewsFuture = fetchReviews();

      await classDataFuture;
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      final fetchedReviews = await reviewsFuture;
      final fetchedUsers = await _fetchUsersForReviews(fetchedReviews);

      if (!mounted) return;
      setState(() {
        usersMap = fetchedUsers;
        isLoadingReviews = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        hasError = true;
        errorMessage = "Failed to load data: $e";
        isLoading = false;
        isLoadingReviews = false;
      });
      debugPrint("Error loading data: $e");
    }
  }

  Future<void> fetchClassData() async {
    final previousSelectedId = selectedSession?.id;
    final service = ClassSessionService();

    try {
      final results = await Future.wait([
        service.fetchClassSessions(widget.classId),
        service.fetchClassInfo(widget.classId),
      ]);

      final fetchedSessions = results[0] as List<class_models.ClassSession>;
      final fetchedClassInfo = results[1] as ClassInfo;

      final teacherFuture = _fetchTeacherDisplayName(
        fetchedClassInfo.teacherId,
      );
      final userFuture = service
          .fetchUser()
          .then<UserInfo?>((user) => user)
          .catchError((error, stackTrace) {
            debugPrint('⚠️ Failed to fetch user info: $error');
            return null;
          });

      class_models.ClassSession? restoredSelection;
      if (previousSelectedId != null) {
        for (final session in fetchedSessions) {
          if (session.id == previousSelectedId) {
            restoredSelection = session;
            break;
          }
        }
      }

      final teacherResult = await teacherFuture;
      final fetchedUserInfo = await userFuture;
      final hydratedUserInfo = await _hydrateUserInfo(fetchedUserInfo);

      if (!mounted) return;
      setState(() {
        sessions = fetchedSessions;
        classInfo = fetchedClassInfo;
        userInfo = hydratedUserInfo;
        selectedSession = restoredSelection;
        if (teacherResult != null && teacherResult.isNotEmpty) {
          teacherName = teacherResult;
        }
      });
    } catch (e) {
      debugPrint('Error fetching class data: $e');
      rethrow;
    }
  }

  Future<List<Review>> fetchReviews() async {
    try {
      final apiKey = dotenv.env["API_URL"];
      final port = dotenv.env["PORT"];
      final apiUrl = "$apiKey:$port/reviews";

      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        final allReviews = jsonData.map((r) => Review.fromJson(r)).toList();
        final filteredReviews = allReviews
            .where((r) => (r.classId ?? -1) == widget.classId)
            .toList();

        if (mounted) {
          setState(() {
            reviews = filteredReviews;
          });
        } else {
          reviews = filteredReviews;
        }

        debugPrint(
          "🎯 Filtered ${filteredReviews.length}/${allReviews.length} reviews for class ${widget.classId}",
        );

        return filteredReviews;
      } else {
        throw Exception("Failed to load reviews: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching reviews: $e");
      if (mounted) {
        setState(() {
          reviews = [];
        });
      } else {
        reviews = [];
      }
      return [];
    }
  }

  Future<Map<int, User>> _fetchUsersForReviews(List<Review> reviewList) async {
    final ids = reviewList
        .map((r) => r.userId)
        .whereType<int>()
        .where((id) => id != 0)
        .toSet();

    if (ids.isEmpty) {
      debugPrint("⚠️ No user IDs found in reviews");
      return {};
    }

    final baseUrl = '${dotenv.env["API_URL"]}:${dotenv.env["PORT"]}';

    final Map<int, User> aggregatedUsers = {
      for (final id in ids)
        if (_userCache.containsKey(id)) id: _userCache[id]!,
    };

    final fetchFutures = ids
        .where((id) => !_userCache.containsKey(id))
        .map((id) async {
          final user = await _getUserWithCache(baseUrl, id);
          if (user != null) {
            aggregatedUsers[id] = user;
          }
        })
        .toList(growable: false);

    if (fetchFutures.isNotEmpty) {
      await Future.wait(fetchFutures, eagerError: false);
    }

    debugPrint("👥 Loaded ${aggregatedUsers.length} users for reviews");
    return aggregatedUsers;
  }

  Future<User?> _getUserWithCache(String baseUrl, int id) {
    if (_userCache.containsKey(id)) {
      return Future.value(_userCache[id]);
    }

    final inFlight = _userRequests[id];
    if (inFlight != null) {
      return inFlight;
    }

    final networkFuture = () async {
      final response = await http.get(Uri.parse('$baseUrl/users/$id'));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return User.fromJson(jsonData);
      }

      debugPrint("⚠️ Failed to fetch user $id: ${response.statusCode}");
      return null;
    }();

    final trackedFuture = () async {
      try {
        final user = await networkFuture;
        if (user != null) {
          _userCache[id] = user;
        }
        return user;
      } catch (error) {
        debugPrint("❌ Error fetching user $id: $error");
        return null;
      } finally {
        _userRequests.remove(id);
      }
    }();

    _userRequests[id] = trackedFuture;
    return trackedFuture;
  }

  Future<String?> _fetchTeacherDisplayName(int? teacherId) {
    final id = teacherId ?? 0;
    if (id <= 0) return Future.value(null);

    if (_teacherNameCache.containsKey(id)) {
      return Future.value(_teacherNameCache[id]);
    }

    final inFlight = _teacherNameRequests[id];
    if (inFlight != null) {
      return inFlight;
    }

    final future = () async {
      final baseUrl = '${dotenv.env["API_URL"]}:${dotenv.env["PORT"]}';
      try {
        final teacherResponse = await http.get(
          Uri.parse('$baseUrl/teachers/$id'),
        );
        if (teacherResponse.statusCode != 200) {
          debugPrint(
            '⚠️ Failed to fetch teacher $id: ${teacherResponse.statusCode}',
          );
          return null;
        }

        final teacherData =
            jsonDecode(teacherResponse.body) as Map<String, dynamic>;
        final userId = teacherData['user_id'];
        if (userId == null) {
          return null;
        }

        final userResponse = await http.get(
          Uri.parse('$baseUrl/users/$userId'),
        );
        if (userResponse.statusCode != 200) {
          debugPrint(
            '⚠️ Failed to fetch teacher user $userId: ${userResponse.statusCode}',
          );
          return null;
        }

        final userData = jsonDecode(userResponse.body) as Map<String, dynamic>;
        final fetchedName =
            '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}'
                .trim();
        if (fetchedName.isEmpty) {
          return null;
        }

        _teacherNameCache[id] = fetchedName;
        return fetchedName;
      } catch (error) {
        debugPrint('⚠️ Failed to fetch teacher name for $id: $error');
        return null;
      } finally {
        _teacherNameRequests.remove(id);
      }
    }();

    _teacherNameRequests[id] = future;
    return future;
  }

  Future<UserInfo?> _hydrateUserInfo(UserInfo? fetchedUserInfo) async {
    var resolvedInfo = fetchedUserInfo;

    if (resolvedInfo != null) {
      if (resolvedInfo.learnerId != null) {
        await LocalStorage.saveLearnerId(resolvedInfo.learnerId!);
      }

      final cachedBalance = await LocalStorage.getUserBalance();
      final latestBalance = _roundToCents(resolvedInfo.balance);

      if (cachedBalance == null ||
          (cachedBalance - latestBalance).abs() > 0.009) {
        await LocalStorage.saveUserBalance(latestBalance);
      }

      final balanceToUse = await LocalStorage.getUserBalance() ?? latestBalance;
      resolvedInfo = resolvedInfo.copyWith(balance: balanceToUse);
    } else {
      final cachedBalance = await LocalStorage.getUserBalance();
      if (cachedBalance != null && userInfo != null) {
        resolvedInfo = userInfo!.copyWith(balance: cachedBalance);
      }
    }

    return resolvedInfo;
  }

  String getUserName(Review review) {
    if (review.userId == null) return "Unknown User";
    final user = usersMap[review.userId!] ?? _userCache[review.userId!];
    return user?.fullName ?? "Unknown User";
  }

  String _formatDate(DateTime dt) {
    const weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return "${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}";
  }

  String _formatTime(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = pad(dt.minute);
    final ampm = dt.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $ampm";
  }

  Widget _buildSessionDropdown() {
    if (sessions.isEmpty) return const Text("No sessions available");

    return FutureBuilder<Map<int, int>>(
      future: _fetchEnrollmentCounts(),
      builder: (context, snapshot) {
        final enrollmentCounts = snapshot.data ?? {};

        return DropdownButton<class_models.ClassSession>(
          isExpanded: true,
          hint: const Text("Choose a session"),
          value: selectedSession,
          items: sessions.map((session) {
            final dateStr = _formatDate(session.classStart);
            final timeStr =
                "${_formatTime(session.classStart)} – ${_formatTime(session.classFinish)}";
            final deadlineStr = _formatDate(session.enrollmentDeadline);

            final enrolledCount = enrollmentCounts[session.id] ?? 0;
            final limit = session.learnerLimit > 20 ? 20 : session.learnerLimit;
            final isFull = enrolledCount >= limit;
            final statusText = isFull
                ? ' 🔴 เต็มแล้ว!'
                : ' ($enrolledCount/$limit คน)';

            return DropdownMenuItem(
              value: session,
              enabled: !isFull,
              child: Text(
                '${dateStr} • ${timeStr} • \$${session.price.toStringAsFixed(2)}$statusText',
                style: TextStyle(
                  fontSize: 14,
                  color: isFull ? Colors.red : Colors.black,
                  fontWeight: isFull ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedSession = value;
            });
          },
        );
      },
    );
  }

  Future<Map<int, int>> _fetchEnrollmentCounts() async {
    final Map<int, int> counts = {};

    try {
      // Fetch all enrollments once
      final allEnrollments = await enrollment_api.Enrollment.fetchAll();

      // Group by session ID and count
      for (final session in sessions) {
        final activeCount = allEnrollments
            .where(
              (e) =>
                  e.classSessionId == session.id &&
                  e.enrollmentStatus == 'active',
            )
            .length;
        counts[session.id] = activeCount;
        debugPrint('📊 Session ${session.id}: $activeCount enrollments');
      }
    } catch (e) {
      debugPrint('❌ Error fetching enrollment counts: $e');
      // Set all to 0 on error
      for (final session in sessions) {
        counts[session.id] = 0;
      }
    }

    return counts;
  }

  Widget _buildReviewsSection() {
    if (isLoadingReviews) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (reviews.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.indigo.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.shade100, width: 2),
        ),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade200,
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.rate_review_rounded,
                  size: 40,
                  color: Colors.blue.shade600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "No reviews yet",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Be the first to share your experience!",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Reviews list with improved design
        ...reviews.take(showAllReviews ? reviews.length : 3).map((review) {
          final reviewerName = getUserName(review);
          final userId = review.userId ?? 0;
          final user = usersMap[userId] ?? _userCache[userId];
          final rating = review.rating ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Picture with gradient border
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.purple.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade200,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(3),
                  child: _buildProfileAvatar(user, reviewerName),
                ),
                const SizedBox(width: 14),
                // Review Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and Rating Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              reviewerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.amber.shade400,
                                  Colors.orange.shade400,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$rating.0',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Star Rating (visual)
                      Row(
                        children: List.generate(
                          5,
                          (i) => Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: Icon(
                              i < rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 18,
                              color: i < rating
                                  ? Colors.amber.shade600
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Comment
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          review.comment?.isNotEmpty == true
                              ? review.comment!
                              : "(No comment provided)",
                          style: TextStyle(
                            fontSize: 14,
                            color: review.comment?.isNotEmpty == true
                                ? Colors.grey.shade800
                                : Colors.grey.shade500,
                            height: 1.5,
                            fontStyle: review.comment?.isNotEmpty == true
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                          maxLines: showAllReviews ? null : 3,
                          overflow: showAllReviews
                              ? null
                              : TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        // See more/less button with better design
        if (reviews.length > 3)
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  showAllReviews = !showAllReviews;
                });
              },
              icon: Icon(
                showAllReviews
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 20,
              ),
              label: Text(
                showAllReviews
                    ? "Show less"
                    : "See all ${reviews.length} reviews",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                foregroundColor: Colors.blue.shade700,
                backgroundColor: Colors.blue.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.blue.shade200),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileAvatar(User? user, String name) {
    final profilePicture = user?.profilePicture;

    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.grey.shade300,
      backgroundImage: profilePicture != null && profilePicture.isNotEmpty
          ? NetworkImage(profilePicture)
          : NetworkImage('https://picsum.photos/seed/${name.hashCode}/200'),
      onBackgroundImageError: (_, __) {
        // Fallback handled by placeholder
      },
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  List<Color> _getGradientForRating(int rating) {
    if (rating >= 5) {
      return [Colors.purple.shade400, Colors.deepPurple.shade600];
    } else if (rating >= 4) {
      return [Colors.blue.shade400, Colors.indigo.shade600];
    } else if (rating >= 3) {
      return [Colors.teal.shade400, Colors.cyan.shade600];
    } else if (rating >= 2) {
      return [Colors.orange.shade400, Colors.deepOrange.shade600];
    } else {
      return [Colors.grey.shade400, Colors.blueGrey.shade600];
    }
  }

  Future<int?> _ensureLearnerId() async {
    if (userInfo?.learnerId != null) {
      await LocalStorage.saveLearnerId(userInfo!.learnerId!);
      return userInfo!.learnerId;
    }

    final cachedLearnerId = await LocalStorage.getLearnerId();
    if (cachedLearnerId != null) {
      if (mounted && userInfo != null) {
        setState(() {
          userInfo = userInfo!.copyWith(learnerId: cachedLearnerId);
        });
      }
      return cachedLearnerId;
    }

    try {
      final userId = await LocalStorage.getUserId();
      if (userId == null) return null;
      final freshUser = await user_api.User.fetchById(userId);
      final learner = freshUser.learner;
      if (learner != null) {
        await LocalStorage.saveLearnerId(learner.id);
        if (mounted && userInfo != null) {
          setState(() {
            userInfo = userInfo!.copyWith(learnerId: learner.id);
          });
        }
        return learner.id;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to resolve learner id: $e');
    }

    return null;
  }

  Future<void> _handleEnrollment(BuildContext parentContext) async {
    EnrollmentLogger.step('Starting enrollment pipeline', {
      'sessionId': selectedSession?.id,
      'classId': widget.classId,
    });

    // Step 1: Pre-validation
    final validationError = await _validateEnrollmentPreconditions();
    if (validationError != null) {
      _showEnrollmentError(parentContext, validationError);
      return;
    }

    final session = selectedSession!;
    final currentUser = userInfo!;
    final learnerId = await _ensureLearnerId();

    if (learnerId == null) {
      _showEnrollmentError(
        parentContext,
        EnrollmentError(
          type: EnrollmentErrorType.noLearnerInfo,
          message: 'Learner ID not found',
          userMessage: EnrollmentErrorMessages.getMessage(
            EnrollmentErrorType.noLearnerInfo,
          ),
        ),
      );
      return;
    }

    if (mounted) {
      setState(() {
        isProcessingEnrollment = true;
      });
    }

    EnrollmentLogger.step('Pre-validation passed', {
      'learnerId': learnerId,
      'sessionId': session.id,
      'balance': currentUser.balance,
      'price': session.price,
    });

    // Step 2: Check for duplicate enrollment
    try {
      final isDuplicate = await _checkDuplicateEnrollment(
        learnerId,
        session.id,
      );
      if (isDuplicate) {
        _showEnrollmentError(
          parentContext,
          EnrollmentError(
            type: EnrollmentErrorType.duplicateEnrollment,
            message: 'Already enrolled in session ${session.id}',
            userMessage: EnrollmentErrorMessages.getMessage(
              EnrollmentErrorType.duplicateEnrollment,
            ),
            context: {'sessionId': session.id, 'learnerId': learnerId},
          ),
        );
        return;
      }
      EnrollmentLogger.step('No duplicate enrollment found', null);
    } catch (e, stackTrace) {
      _handleEnrollmentException(
        parentContext,
        e,
        stackTrace,
        'duplicate check',
      );
      return;
    }

    // Step 3: Check class capacity
    try {
      final capacityCheck = await _checkClassCapacity(session);
      if (capacityCheck.isFull) {
        _showEnrollmentError(
          parentContext,
          EnrollmentError(
            type: EnrollmentErrorType.classFull,
            message: 'Session ${session.id} is full',
            userMessage: EnrollmentErrorMessages.getMessage(
              EnrollmentErrorType.classFull,
            ),
            context: {
              'currentEnrollment': capacityCheck.currentCount,
              'limit': capacityCheck.limit,
            },
          ),
        );
        return;
      }
      EnrollmentLogger.step('Class capacity available', {
        'current': capacityCheck.currentCount,
        'limit': capacityCheck.limit,
      });
    } catch (e, stackTrace) {
      _handleEnrollmentException(
        parentContext,
        e,
        stackTrace,
        'capacity check',
      );
      return;
    }

    // Step 4: Execute enrollment transaction
    final result = await _executeEnrollmentTransaction(
      parentContext: parentContext,
      session: session,
      currentUser: currentUser,
      learnerId: learnerId,
    );

    if (mounted) {
      setState(() {
        isProcessingEnrollment = false;
      });
    }

    if (result.success) {
      EnrollmentLogger.step('Enrollment completed successfully', {
        'sessionId': session.id,
        'learnerId': learnerId,
      });

      if (mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text('✅ ลงทะเบียน ${session.description} สำเร็จ!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else if (result.error != null) {
      _showEnrollmentError(parentContext, result.error!);
    }
  }

  Future<EnrollmentError?> _validateEnrollmentPreconditions() async {
    if (selectedSession == null) {
      return EnrollmentError(
        type: EnrollmentErrorType.noSelectedSession,
        message: 'No session selected',
        userMessage: EnrollmentErrorMessages.getMessage(
          EnrollmentErrorType.noSelectedSession,
        ),
      );
    }

    final session = selectedSession!;
    final currentUser = userInfo;

    // Check teacher status
    if (currentUser != null && classInfo != null) {
      try {
        final userId = await LocalStorage.getUserId();
        if (userId != null) {
          final fullUser = await user_api.User.fetchById(userId);
          if (fullUser.teacher != null &&
              fullUser.teacher!.id == classInfo!.teacherId) {
            return EnrollmentError(
              type: EnrollmentErrorType.teacherCannotEnroll,
              message: 'Teacher cannot enroll in own class',
              userMessage: EnrollmentErrorMessages.getMessage(
                EnrollmentErrorType.teacherCannotEnroll,
              ),
            );
          }
        }
      } catch (e) {
        EnrollmentLogger.warning('Failed to check teacher status', {
          'error': e.toString(),
        });
      }
    }

    if (currentUser == null) {
      return EnrollmentError(
        type: EnrollmentErrorType.noLearnerInfo,
        message: 'User information unavailable',
        userMessage: EnrollmentErrorMessages.getMessage(
          EnrollmentErrorType.noLearnerInfo,
        ),
      );
    }

    if (currentUser.balance < session.price) {
      return EnrollmentError(
        type: EnrollmentErrorType.insufficientBalance,
        message: 'Balance ${currentUser.balance} < ${session.price}',
        userMessage: EnrollmentErrorMessages.getMessage(
          EnrollmentErrorType.insufficientBalance,
        ),
        context: {
          'currentBalance': currentUser.balance,
          'neededAmount': session.price,
        },
      );
    }

    return null;
  }

  Future<bool> _checkDuplicateEnrollment(int learnerId, int sessionId) async {
    try {
      final existingEnrollments = await enrollment_api.Enrollment.fetchAll(
        query: {'learner_id': learnerId, 'class_session_id': sessionId},
      );
      return existingEnrollments.isNotEmpty;
    } catch (e) {
      EnrollmentLogger.error('Duplicate check failed', error: e);
      rethrow;
    }
  }

  Future<_CapacityCheckResult> _checkClassCapacity(
    class_models.ClassSession session,
  ) async {
    try {
      final allEnrollments = await enrollment_api.Enrollment.fetchAll();
      final currentCount = allEnrollments
          .where(
            (e) =>
                e.classSessionId == session.id &&
                e.enrollmentStatus == 'active',
          )
          .length;

      const maxParticipants = 20;
      final effectiveLimit = session.learnerLimit > maxParticipants
          ? maxParticipants
          : session.learnerLimit;

      return _CapacityCheckResult(
        currentCount: currentCount,
        limit: effectiveLimit,
        isFull: currentCount >= effectiveLimit,
      );
    } catch (e) {
      EnrollmentLogger.error('Capacity check failed', error: e);
      rethrow;
    }
  }

  Future<_EnrollmentTransactionResult> _executeEnrollmentTransaction({
    required BuildContext parentContext,
    required class_models.ClassSession session,
    required UserInfo currentUser,
    required int learnerId,
  }) async {
    final originalBalance = currentUser.balance;
    final deductedBalance = _roundToCents(originalBalance - session.price);
    bool balanceDeducted = false;
    user_api.User? updatedServerUser;

    try {
      // Step 4.1: Deduct balance
      EnrollmentLogger.step('Deducting balance', {
        'userId': currentUser.id,
        'original': originalBalance,
        'deducted': deductedBalance,
      });

      updatedServerUser = await _updateRemoteUserBalance(
        userId: currentUser.id,
        balance: deductedBalance,
      );
      balanceDeducted = true;

      EnrollmentLogger.step('Balance deducted successfully', {
        'newBalance': updatedServerUser.balance,
      });

      // Step 4.2: Create enrollment
      EnrollmentLogger.step('Creating enrollment record', {
        'sessionId': session.id,
        'learnerId': learnerId,
      });

      final enrollment = enrollment_api.Enrollment(
        classSessionId: session.id,
        enrollmentStatus: 'active',
        learnerId: learnerId,
      );

      await enrollment_api.Enrollment.create(enrollment);

      EnrollmentLogger.step('Enrollment record created', null);

      // Step 4.3: Update local state
      if (mounted) {
        setState(() {
          userInfo = currentUser.copyWith(
            balance: updatedServerUser?.balance ?? deductedBalance,
            learnerId: learnerId,
          );
        });
      }

      // Step 4.4: Refresh class data
      await fetchClassData();

      // Step 4.5: Create notification
      await _createEnrollmentNotification(
        userId: currentUser.id,
        session: session,
        learnerId: learnerId,
      );

      return _EnrollmentTransactionResult(success: true);
    } catch (e, stackTrace) {
      EnrollmentLogger.error(
        'Transaction failed',
        error: e,
        stackTrace: stackTrace,
        context: {'balanceDeducted': balanceDeducted, 'sessionId': session.id},
      );

      // Rollback balance if it was deducted
      if (balanceDeducted) {
        EnrollmentLogger.rollback('Restoring balance', {
          'userId': currentUser.id,
          'amount': originalBalance,
        });

        try {
          await _updateRemoteUserBalance(
            userId: currentUser.id,
            balance: originalBalance,
          );

          if (mounted) {
            setState(() {
              userInfo = currentUser.copyWith(
                balance: originalBalance,
                learnerId: learnerId,
              );
            });
          }

          EnrollmentLogger.step('Balance restored successfully', null);

          return _EnrollmentTransactionResult(
            success: false,
            error: EnrollmentError(
              type: EnrollmentErrorType.enrollmentCreationFailed,
              message: 'Enrollment creation failed, balance restored',
              userMessage: EnrollmentErrorMessages.getMessage(
                EnrollmentErrorType.enrollmentCreationFailed,
              ),
              originalError: e,
              stackTrace: stackTrace,
            ),
          );
        } catch (restoreError, restoreStack) {
          EnrollmentLogger.error(
            'CRITICAL: Balance restore failed',
            error: restoreError,
            stackTrace: restoreStack,
          );

          return _EnrollmentTransactionResult(
            success: false,
            error: EnrollmentError(
              type: EnrollmentErrorType.balanceRestoreFailed,
              message: 'Failed to restore balance after error',
              userMessage: EnrollmentErrorMessages.getMessage(
                EnrollmentErrorType.balanceRestoreFailed,
              ),
              originalError: restoreError,
              stackTrace: restoreStack,
              context: {
                'originalError': e.toString(),
                'userId': currentUser.id,
                'originalBalance': originalBalance,
              },
            ),
          );
        }
      }

      return _EnrollmentTransactionResult(
        success: false,
        error: EnrollmentError(
          type: EnrollmentErrorType.balanceDeductionFailed,
          message: 'Balance deduction failed',
          userMessage: EnrollmentErrorMessages.getMessage(
            EnrollmentErrorType.balanceDeductionFailed,
          ),
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  void _handleEnrollmentException(
    BuildContext context,
    dynamic error,
    StackTrace stackTrace,
    String step,
  ) {
    EnrollmentLogger.error(
      'Error during $step',
      error: error,
      stackTrace: stackTrace,
    );

    if (!mounted) return;

    setState(() {
      isProcessingEnrollment = false;
    });

    EnrollmentErrorType errorType = EnrollmentErrorType.unknown;

    if (error is ApiException) {
      if (error.statusCode == 408) {
        errorType = EnrollmentErrorType.networkTimeout;
      } else if (error.statusCode == 503) {
        errorType = EnrollmentErrorType.networkUnavailable;
      }
    }

    _showEnrollmentError(
      context,
      EnrollmentError(
        type: errorType,
        message: 'Failed at $step: ${error.toString()}',
        userMessage: EnrollmentErrorMessages.getMessage(errorType),
        originalError: error,
        stackTrace: stackTrace,
      ),
    );
  }

  void _showEnrollmentError(BuildContext context, EnrollmentError error) {
    EnrollmentLogger.error(
      'Showing error to user',
      error: error,
      context: error.context,
    );

    if (mounted) {
      setState(() {
        isProcessingEnrollment = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(EnrollmentErrorMessages.getDetailedMessage(error)),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
          action: error.type == EnrollmentErrorType.insufficientBalance
              ? SnackBarAction(
                  label: 'เติมเงิน',
                  textColor: Colors.white,
                  onPressed: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PaymentScreen(userId: userInfo!.id),
                      ),
                    );
                    if (result == true) {
                      await fetchClassData();
                    }
                  },
                )
              : null,
        ),
      );
    }
  }

  double _roundToCents(double value) {
    final rounded = (value * 100).round() / 100;
    return rounded < 0 ? 0 : rounded;
  }

  Future<user_api.User> _updateRemoteUserBalance({
    required int userId,
    required double balance,
  }) async {
    user_api.User? baseUser = UserCache().user;
    if (baseUser == null || baseUser.id != userId) {
      baseUser = await user_api.User.fetchById(userId);
    }

    final payloadUser = user_api.User(
      id: baseUser.id,
      studentId: baseUser.studentId,
      firstName: baseUser.firstName,
      lastName: baseUser.lastName,
      gender: baseUser.gender,
      phoneNumber: baseUser.phoneNumber,
      balance: balance,
      banCount: baseUser.banCount,
      profilePicture: baseUser.profilePicture,
      teacher: baseUser.teacher,
      learner: baseUser.learner,
    );

    final serverUser = await user_api.User.update(userId, payloadUser);
    UserCache().saveUser(serverUser);
    await LocalStorage.saveUserBalance(serverUser.balance);
    return serverUser;
  }

  Future<void> _createEnrollmentNotification({
    required int userId,
    required class_models.ClassSession session,
    required int learnerId,
  }) async {
    final className = classInfo?.name ?? session.description;
    final description =
        'Enrollment confirmed for $className (Session: ${session.description}) [Learner #$learnerId].';

    final notification = notification_api.NotificationModel(
      notificationDate: DateTime.now().toUtc(),
      notificationDescription: description,
      notificationType: 'Enrollment',
      readFlag: false,
      userId: userId,
    );

    try {
      await notification_api.NotificationModel.create(notification);
    } catch (e) {
      debugPrint('⚠️ Failed to create enrollment notification: $e');
    }
  }

  Future<void> _showEnrollConfirmationDialog(BuildContext parentContext) async {
    if (isProcessingEnrollment || selectedSession == null) return;

    final cachedBalance = await LocalStorage.getUserBalance();
    if (mounted && cachedBalance != null && userInfo != null) {
      setState(() {
        userInfo = userInfo!.copyWith(balance: cachedBalance);
      });
    }

    final currentUser = userInfo;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          const SnackBar(content: Text('User information unavailable.')),
        );
      }
      return;
    }

    final hasEnoughBalance = currentUser.balance >= selectedSession!.price;

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Confirm Enrollment"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Class: ${classInfo?.name ?? "Unknown"}"),
              Text("Session: ${selectedSession!.description}"),
              Text("Price: \$${selectedSession!.price.toStringAsFixed(2)}"),
              const SizedBox(height: 12),
              if (hasEnoughBalance)
                const Icon(Icons.check_circle, color: Colors.green, size: 48)
              else
                const Icon(Icons.cancel, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              hasEnoughBalance
                  ? const Text("Your balance is enough to enroll ✅")
                  : Text(
                      "Not enough balance ❌\n"
                      "Your balance: \$${currentUser.balance.toStringAsFixed(2)}\n"
                      "Needed: \$${selectedSession!.price.toStringAsFixed(2)}",
                      textAlign: TextAlign.center,
                    ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancel"),
            ),
            if (hasEnoughBalance)
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _handleEnrollment(parentContext);
                },
                child: const Text("Confirm"),
              )
            else
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  final result = await Navigator.of(parentContext).push(
                    MaterialPageRoute(
                      builder: (_) => PaymentScreen(userId: currentUser.id),
                    ),
                  );
                  if (result == true) {
                    await fetchClassData();
                  } else {
                    final latestBalance = await LocalStorage.getUserBalance();
                    if (mounted && latestBalance != null) {
                      setState(() {
                        userInfo = currentUser.copyWith(balance: latestBalance);
                      });
                    }
                  }
                },
                child: const Text("Add Balance"),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBannerImage() {
    const fallback = 'assets/images/guitar.jpg';
    final imagePath = classInfo?.bannerPicture;

    if (imagePath == null || imagePath.isEmpty) {
      return Image.asset(fallback, fit: BoxFit.cover);
    }

    if (imagePath.toLowerCase().startsWith('data:image')) {
      try {
        final payload = imagePath.substring(imagePath.indexOf(',') + 1);
        final bytes = base64Decode(payload);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Image.asset(fallback, fit: BoxFit.cover),
        );
      } catch (e) {
        debugPrint('⚠️ Failed to decode base64 banner: $e');
        return Image.asset(fallback, fit: BoxFit.cover);
      }
    }

    if (imagePath.toLowerCase().startsWith('http')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(fallback, fit: BoxFit.cover),
      );
    }

    return Image.asset(
      imagePath.isNotEmpty ? imagePath : fallback,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Image.asset(fallback, fit: BoxFit.cover),
    );
  }

  @override
  Widget build(BuildContext context) {
    String getCategoryDisplay(List<String>? categories) {
      // Check if the list is null OR empty
      if (categories == null || categories.isEmpty) {
        return "General";
      }

      // If it's not empty, join items with a comma
      return categories.join(
        ', ',
      ); // Turns ["Math", "Programming"] into "Math, Programming"
    }

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildBannerImage(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : hasError
                      ? Column(
                          children: [
                            const Icon(
                              Icons.error,
                              color: Colors.red,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Error loading class data",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(errorMessage),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: loadAllData,
                              child: const Text("Retry"),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "🎨 ${classInfo?.name ?? "Untitled Class"}",
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text("${widget.rating}/5"),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              classInfo?.description ??
                                  "No description available",
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "👨‍🏫 Teacher: $teacherName",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    if (classInfo != null &&
                                        classInfo!.teacherId != 0) {
                                      final teacherId = classInfo!.teacherId;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              TeacherProfilePage(
                                                teacherId: teacherId,
                                              ),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "Teacher ID not found for $teacherName",
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text("View Profile"),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "📂 Category: ${getCategoryDisplay(classInfo?.categories)}",
                            ),
                            const Divider(height: 32),
                            const Text(
                              "📅 Select Session",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildSessionDropdown(),
                            const Divider(height: 32),
                            const Text(
                              "⭐ Reviews",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildReviewsSection(),
                            // Add bottom padding to prevent content from being hidden by button
                            const SizedBox(height: 100),
                          ],
                        ),
                ),
              ),
            ],
          ),
          // Enrollment button with SafeArea to avoid Android navigation buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: ElevatedButton(
                    onPressed:
                        (selectedSession == null || isProcessingEnrollment)
                        ? null
                        : () => _showEnrollConfirmationDialog(context),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 54),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade500,
                    ),
                    child: isProcessingEnrollment
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                selectedSession == null
                                    ? "Select a session first"
                                    : "Enroll Now",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
