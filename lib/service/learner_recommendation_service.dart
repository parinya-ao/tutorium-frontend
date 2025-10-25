import 'package:flutter/foundation.dart';
import 'package:tutorium_frontend/models/recommendation_models.dart';
import 'package:tutorium_frontend/service/learners.dart';

/// Service for managing learner-specific recommendations based on interests
class LearnerRecommendationService {
  LearnerRecommendationService._();

  static final LearnerRecommendationService instance =
      LearnerRecommendationService._();

  // Cache for recommendations
  final Map<int, _RecommendationCache> _cache = {};
  static const Duration _cacheValidDuration = Duration(minutes: 10);

  /// Get personalized recommended classes for a learner
  /// Uses caching to avoid excessive API calls
  Future<RecommendedClassesResponse> getRecommendedClasses(
    int learnerId, {
    bool forceRefresh = false,
  }) async {
    // Check cache first
    if (!forceRefresh && _cache.containsKey(learnerId)) {
      final cached = _cache[learnerId]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheValidDuration) {
        debugPrint('📦 Using cached recommendations for learner $learnerId');
        return cached.response;
      }
    }

    debugPrint('🔄 Fetching fresh recommendations for learner $learnerId');

    try {
      final response = await Learner.getRecommendedClasses(learnerId);

      // Update cache
      _cache[learnerId] = _RecommendationCache(
        response: response,
        timestamp: DateTime.now(),
      );

      return response;
    } catch (e) {
      debugPrint('❌ Error fetching recommendations: $e');
      // If we have stale cache, return it as fallback
      if (_cache.containsKey(learnerId)) {
        debugPrint('📦 Returning stale cache as fallback');
        return _cache[learnerId]!.response;
      }
      rethrow;
    }
  }

  /// Get learner's interests (categories they're interested in)
  Future<LearnerInterests> getInterests(int learnerId) async {
    try {
      return await Learner.getInterests(learnerId);
    } catch (e) {
      debugPrint('❌ Error fetching interests: $e');
      rethrow;
    }
  }

  /// Add interests for a learner
  /// Invalidates the recommendation cache
  Future<Learner> addInterests(
    int learnerId,
    List<int> classCategoryIds,
  ) async {
    try {
      final result = await Learner.addInterests(learnerId, classCategoryIds);
      // Invalidate cache since interests changed
      _invalidateCache(learnerId);
      return result;
    } catch (e) {
      debugPrint('❌ Error adding interests: $e');
      rethrow;
    }
  }

  /// Remove interests for a learner
  /// Invalidates the recommendation cache
  Future<Learner> removeInterests(
    int learnerId,
    List<int> classCategoryIds,
  ) async {
    try {
      final result = await Learner.removeInterests(learnerId, classCategoryIds);
      // Invalidate cache since interests changed
      _invalidateCache(learnerId);
      return result;
    } catch (e) {
      debugPrint('❌ Error removing interests: $e');
      rethrow;
    }
  }

  /// Clear cached recommendations for a specific learner
  void _invalidateCache(int learnerId) {
    _cache.remove(learnerId);
    debugPrint('🗑️  Invalidated cache for learner $learnerId');
  }

  /// Clear all cached recommendations
  void clearAllCache() {
    _cache.clear();
    debugPrint('🗑️  Cleared all recommendation cache');
  }

  /// Convert RecommendedClass to a format compatible with search page
  /// This helps maintain consistency with existing code
  Map<String, dynamic> toSearchFormat(RecommendedClass rec) {
    return {
      'class_name': rec.className,
      'class_description': rec.classDescription,
      'teacher_id': rec.teacherId,
      'banner_picture': rec.bannerPicture,
      'banner_picture_url': rec.bannerPicture,
      // Note: These fields are not in the API response
      // You may need to fetch additional data if needed
      'teacher_name': 'Unknown Teacher',
      'rating': 0.0,
    };
  }

  /// Convert list of recommended classes to search format
  List<Map<String, dynamic>> toSearchFormatList(
    List<RecommendedClass> classes,
  ) {
    return classes.map(toSearchFormat).toList();
  }
}

class _RecommendationCache {
  final RecommendedClassesResponse response;
  final DateTime timestamp;

  _RecommendationCache({required this.response, required this.timestamp});
}
