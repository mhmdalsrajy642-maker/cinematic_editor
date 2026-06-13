import 'dart:async';

import '../models/template_models.dart';

/// Service responsible for template download and local cache management.
class TemplateDownloadService {
  final Map<String, TemplateItem> _cachedTemplates = {};

  /// Downloads the specified template.
  ///
  /// This is an architectural stub; actual network/download logic is not implemented.
  Future<TemplateItem> downloadTemplate(TemplateItem template) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final cachedTemplate = template.copyWith();
    _cachedTemplates[cachedTemplate.id] = cachedTemplate;
    return cachedTemplate;
  }

  /// Caches the provided template locally.
  Future<TemplateItem> cacheTemplate(TemplateItem template) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    _cachedTemplates[template.id] = template;
    return template;
  }

  /// Deletes a cached template by its identifier.
  Future<bool> deleteTemplate(String templateId) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return _cachedTemplates.remove(templateId) != null;
  }

  /// Returns a cached template if available.
  TemplateItem? getCachedTemplate(String templateId) {
    return _cachedTemplates[templateId];
  }

  /// Lists all currently cached templates.
  List<TemplateItem> get cachedTemplates => List.unmodifiable(_cachedTemplates.values);
}
