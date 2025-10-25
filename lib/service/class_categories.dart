import 'package:tutorium_frontend/service/api_client.dart';

class ClassCategory {
  final int? id;
  final String classCategory;

  const ClassCategory({this.id, required this.classCategory});

  factory ClassCategory.fromJson(Map<String, dynamic> json) {
    return ClassCategory(
      id: json['ID'] ?? json['id'],
      classCategory: json['class_category'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {if (id != null) 'ID': id, 'class_category': classCategory};
  }

  static final ApiClient _client = ApiClient();

  /// GET /class_categories - Get all class categories
  static Future<List<ClassCategory>> fetchAll() async {
    final response = await _client.getJsonList('/class_categories');
    return response.map(ClassCategory.fromJson).toList();
  }

  /// GET /class_categories/:id - Get a specific category
  static Future<ClassCategory> fetchById(int id) async {
    final response = await _client.getJsonMap('/class_categories/$id');
    return ClassCategory.fromJson(response);
  }

  /// POST /class_categories - Create a new category (admin only)
  static Future<ClassCategory> create(ClassCategory category) async {
    final response = await _client.postJsonMap(
      '/class_categories',
      body: category.toJson(),
    );
    return ClassCategory.fromJson(response);
  }

  /// PUT /class_categories/:id - Update a category (admin only)
  static Future<ClassCategory> update(int id, ClassCategory category) async {
    final response = await _client.putJsonMap(
      '/class_categories/$id',
      body: category.toJson(),
    );
    return ClassCategory.fromJson(response);
  }

  /// DELETE /class_categories/:id - Delete a category (admin only)
  static Future<void> delete(int id) async {
    await _client.delete('/class_categories/$id');
  }

  /// Helper: Get category ID by name
  static Future<int?> getCategoryIdByName(String categoryName) async {
    try {
      final categories = await fetchAll();
      for (final category in categories) {
        if (category.classCategory.toLowerCase() ==
            categoryName.toLowerCase()) {
          return category.id;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Helper: Get multiple category IDs by names
  static Future<List<int>> getCategoryIdsByNames(
    List<String> categoryNames,
  ) async {
    try {
      final categories = await fetchAll();
      final ids = <int>[];

      for (final name in categoryNames) {
        for (final category in categories) {
          if (category.classCategory.toLowerCase() == name.toLowerCase()) {
            if (category.id != null) {
              ids.add(category.id!);
            }
            break;
          }
        }
      }

      return ids;
    } catch (e) {
      return [];
    }
  }
}
