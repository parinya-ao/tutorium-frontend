// Recommendation Models for Learner Personalization

/// Model representing a recommended class from the API
class RecommendedClass {
  final String bannerPicture;
  final String classDescription;
  final String className;
  final int teacherId;

  RecommendedClass({
    required this.bannerPicture,
    required this.classDescription,
    required this.className,
    required this.teacherId,
  });

  factory RecommendedClass.fromJson(Map<String, dynamic> json) {
    return RecommendedClass(
      bannerPicture: json['banner_picture'] ?? '',
      classDescription: json['class_description'] ?? '',
      className: json['class_name'] ?? '',
      teacherId: json['teacher_id'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'banner_picture': bannerPicture,
      'class_description': classDescription,
      'class_name': className,
      'teacher_id': teacherId,
    };
  }
}

/// Model representing the API response for recommended classes
class RecommendedClassesResponse {
  final List<RecommendedClass> recommendedClasses;
  final bool recommendedFound;
  final List<RecommendedClass> remainingClasses;

  RecommendedClassesResponse({
    required this.recommendedClasses,
    required this.recommendedFound,
    required this.remainingClasses,
  });

  factory RecommendedClassesResponse.fromJson(Map<String, dynamic> json) {
    return RecommendedClassesResponse(
      recommendedClasses:
          (json['recommended_classes'] as List<dynamic>?)
              ?.map((e) => RecommendedClass.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      recommendedFound: json['recommended_found'] ?? false,
      remainingClasses:
          (json['remaining_classes'] as List<dynamic>?)
              ?.map((e) => RecommendedClass.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recommended_classes': recommendedClasses.map((e) => e.toJson()).toList(),
      'recommended_found': recommendedFound,
      'remaining_classes': remainingClasses.map((e) => e.toJson()).toList(),
    };
  }
}

/// Model for learner interests (categories)
class LearnerInterests {
  final List<String> categories;

  LearnerInterests({required this.categories});

  factory LearnerInterests.fromJson(Map<String, dynamic> json) {
    // API returns: {"categories": ["Math", "Science", ...]}
    return LearnerInterests(
      categories:
          (json['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {'categories': categories};
  }
}

/// Request model for adding/removing interests
class InterestRequest {
  final List<int> classCategoryIds;

  InterestRequest({required this.classCategoryIds});

  Map<String, dynamic> toJson() {
    return {'class_category_ids': classCategoryIds};
  }
}
