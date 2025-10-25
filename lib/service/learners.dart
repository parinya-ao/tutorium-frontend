import 'package:tutorium_frontend/models/recommendation_models.dart';
import 'package:tutorium_frontend/service/api_client.dart';

class Learner {
  final int? id;
  final int flagCount;
  final int userId;

  const Learner({this.id, required this.flagCount, required this.userId});

  factory Learner.fromJson(Map<String, dynamic> json) {
    return Learner(
      id: json['ID'] ?? json['id'],
      flagCount: json['flag_count'] ?? 0,
      userId: json['user_id'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'flag_count': flagCount,
      'user_id': userId,
    };
  }

  static final ApiClient _client = ApiClient();

  static Future<List<Learner>> fetchAll({Map<String, dynamic>? query}) async {
    final response = await _client.getJsonList(
      '/learners',
      queryParameters: query,
    );
    return response.map(Learner.fromJson).toList();
  }

  static Future<Learner> fetchById(int id) async {
    final response = await _client.getJsonMap('/learners/$id');
    return Learner.fromJson(response);
  }

  static Future<Learner> create(Learner learner) async {
    final response = await _client.postJsonMap(
      '/learners',
      body: learner.toJson(),
    );
    return Learner.fromJson(response);
  }

  static Future<void> delete(int id) async {
    await _client.delete('/learners/$id');
  }

  // Interests Management

  /// Get a learner's interested class categories
  /// GET /learners/{id}/interests
  static Future<LearnerInterests> getInterests(int learnerId) async {
    final response = await _client.getJsonMap('/learners/$learnerId/interests');
    return LearnerInterests.fromJson(response);
  }

  /// Add categories to a learner's interests
  /// POST /learners/{id}/interests
  static Future<Learner> addInterests(
    int learnerId,
    List<int> classCategoryIds,
  ) async {
    final request = InterestRequest(classCategoryIds: classCategoryIds);
    final response = await _client.postJsonMap(
      '/learners/$learnerId/interests',
      body: request.toJson(),
    );
    return Learner.fromJson(response);
  }

  /// Remove categories from a learner's interests
  /// DELETE /learners/{id}/interests
  static Future<Learner> removeInterests(
    int learnerId,
    List<int> classCategoryIds,
  ) async {
    final request = InterestRequest(classCategoryIds: classCategoryIds);
    final response = await _client.deleteWithBody(
      '/learners/$learnerId/interests',
      body: request.toJson(),
    );
    return Learner.fromJson(response);
  }

  /// Get recommended classes for a learner based on their interests
  /// GET /learners/{id}/recommended
  static Future<RecommendedClassesResponse> getRecommendedClasses(
    int learnerId,
  ) async {
    final response = await _client.getJsonMap(
      '/learners/$learnerId/recommended',
    );
    return RecommendedClassesResponse.fromJson(response);
  }
}
