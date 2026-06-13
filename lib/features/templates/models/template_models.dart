// lib/features/templates/models/template_models.dart

import 'package:equatable/equatable.dart';

class TemplateAuthor extends Equatable {
  final String id;
  final String name;
  final String profileUrl;

  const TemplateAuthor({
    required this.id,
    required this.name,
    required this.profileUrl,
  });

  TemplateAuthor copyWith({
    String? id,
    String? name,
    String? profileUrl,
  }) {
    return TemplateAuthor(
      id: id ?? this.id,
      name: name ?? this.name,
      profileUrl: profileUrl ?? this.profileUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'profileUrl': profileUrl,
    };
  }

  factory TemplateAuthor.fromJson(Map<String, dynamic> json) {
    return TemplateAuthor(
      id: json['id'] as String,
      name: json['name'] as String,
      profileUrl: json['profileUrl'] as String,
    );
  }

  @override
  List<Object?> get props => [id, name, profileUrl];
}

class TemplateRating extends Equatable {
  final double average;
  final int count;
  final int fiveStarCount;
  final int fourStarCount;
  final int threeStarCount;
  final int twoStarCount;
  final int oneStarCount;

  const TemplateRating({
    required this.average,
    required this.count,
    required this.fiveStarCount,
    required this.fourStarCount,
    required this.threeStarCount,
    required this.twoStarCount,
    required this.oneStarCount,
  });

  TemplateRating copyWith({
    double? average,
    int? count,
    int? fiveStarCount,
    int? fourStarCount,
    int? threeStarCount,
    int? twoStarCount,
    int? oneStarCount,
  }) {
    return TemplateRating(
      average: average ?? this.average,
      count: count ?? this.count,
      fiveStarCount: fiveStarCount ?? this.fiveStarCount,
      fourStarCount: fourStarCount ?? this.fourStarCount,
      threeStarCount: threeStarCount ?? this.threeStarCount,
      twoStarCount: twoStarCount ?? this.twoStarCount,
      oneStarCount: oneStarCount ?? this.oneStarCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'average': average,
      'count': count,
      'fiveStarCount': fiveStarCount,
      'fourStarCount': fourStarCount,
      'threeStarCount': threeStarCount,
      'twoStarCount': twoStarCount,
      'oneStarCount': oneStarCount,
    };
  }

  factory TemplateRating.fromJson(Map<String, dynamic> json) {
    return TemplateRating(
      average: (json['average'] as num).toDouble(),
      count: json['count'] as int,
      fiveStarCount: json['fiveStarCount'] as int,
      fourStarCount: json['fourStarCount'] as int,
      threeStarCount: json['threeStarCount'] as int,
      twoStarCount: json['twoStarCount'] as int,
      oneStarCount: json['oneStarCount'] as int,
    );
  }

  @override
  List<Object?> get props => [average, count, fiveStarCount, fourStarCount, threeStarCount, twoStarCount, oneStarCount];
}

class TemplatePrice extends Equatable {
  final double amount;
  final String currency;
  final bool isFree;

  const TemplatePrice({
    required this.amount,
    required this.currency,
    required this.isFree,
  });

  TemplatePrice copyWith({
    double? amount,
    String? currency,
    bool? isFree,
  }) {
    return TemplatePrice(
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      isFree: isFree ?? this.isFree,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'currency': currency,
      'isFree': isFree,
    };
  }

  factory TemplatePrice.fromJson(Map<String, dynamic> json) {
    return TemplatePrice(
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      isFree: json['isFree'] as bool,
    );
  }

  @override
  List<Object?> get props => [amount, currency, isFree];
}

class TemplateCategory extends Equatable {
  final String id;
  final String title;
  final String description;

  const TemplateCategory({
    required this.id,
    required this.title,
    required this.description,
  });

  TemplateCategory copyWith({
    String? id,
    String? title,
    String? description,
  }) {
    return TemplateCategory(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
    };
  }

  factory TemplateCategory.fromJson(Map<String, dynamic> json) {
    return TemplateCategory(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
    );
  }

  @override
  List<Object?> get props => [id, title, description];
}

class TemplateItem extends Equatable {
  final String id;
  final String name;
  final String description;
  final TemplateCategory category;
  final TemplateAuthor author;
  final TemplateRating rating;
  final TemplatePrice price;
  final List<String> tags;
  final String previewUrl;
  final DateTime createdAt;

  const TemplateItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.author,
    required this.rating,
    required this.price,
    this.tags = const [],
    required this.previewUrl,
    required this.createdAt,
  });

  TemplateItem copyWith({
    String? id,
    String? name,
    String? description,
    TemplateCategory? category,
    TemplateAuthor? author,
    TemplateRating? rating,
    TemplatePrice? price,
    List<String>? tags,
    String? previewUrl,
    DateTime? createdAt,
  }) {
    return TemplateItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      author: author ?? this.author,
      rating: rating ?? this.rating,
      price: price ?? this.price,
      tags: tags ?? this.tags,
      previewUrl: previewUrl ?? this.previewUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category.toJson(),
      'author': author.toJson(),
      'rating': rating.toJson(),
      'price': price.toJson(),
      'tags': tags,
      'previewUrl': previewUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TemplateItem.fromJson(Map<String, dynamic> json) {
    return TemplateItem(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      category: TemplateCategory.fromJson(json['category'] as Map<String, dynamic>),
      author: TemplateAuthor.fromJson(json['author'] as Map<String, dynamic>),
      rating: TemplateRating.fromJson(json['rating'] as Map<String, dynamic>),
      price: TemplatePrice.fromJson(json['price'] as Map<String, dynamic>),
      tags: (json['tags'] as List<dynamic>).cast<String>(),
      previewUrl: json['previewUrl'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        category,
        author,
        rating,
        price,
        tags,
        previewUrl,
        createdAt,
      ];
}
