import '../models/template_models.dart';

/// Repository for managing template marketplace data.
class TemplateRepository {
  final List<TemplateItem> _templates;

  TemplateRepository({List<TemplateItem>? templates})
      : _templates = templates ?? const [];

  /// Loads all available templates.
  Future<List<TemplateItem>> loadTemplates() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return List<TemplateItem>.unmodifiable(_templates);
  }

  /// Searches templates by name, description, author, or tags.
  Future<List<TemplateItem>> searchTemplates(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return _templates.where((template) {
      final combined = <String>[
        template.name,
        template.description,
        template.author.name,
        ...template.tags,
      ].join(' ').toLowerCase();
      return combined.contains(normalizedQuery);
    }).toList(growable: false);
  }

  /// Filters templates by category identifier.
  Future<List<TemplateItem>> filterByCategory(String categoryId) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return _templates
        .where((template) => template.category.id == categoryId)
        .toList(growable: false);
  }

  /// Loads templates marked as featured.
  Future<List<TemplateItem>> loadFeaturedTemplates() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return _templates.where((template) => template.tags.contains('featured')).toList(growable: false);
  }
}
