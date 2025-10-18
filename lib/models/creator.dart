import 'package:flutter/foundation.dart';

enum DataSource {
  catalog,
  local;

  String get displayName {
    switch (this) {
      case DataSource.catalog:
        return 'Online Catalog';
      case DataSource.local:
        return 'Local Data';
    }
  }

  String get shortName {
    switch (this) {
      case DataSource.catalog:
        return 'ONLINE';
      case DataSource.local:
        return 'LOCAL';
    }
  }
}

class CreatorInformation {
  final String title;
  final String content;

  const CreatorInformation({required this.title, required this.content});

  factory CreatorInformation.fromJson(Map<String, dynamic> json) {
    return CreatorInformation(
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
    );
  }
}

class CreatorUrl {
  final String title;
  final String url;

  const CreatorUrl({required this.title, required this.url});

  factory CreatorUrl.fromJson(Map<String, dynamic> json) {
    return CreatorUrl(
      title: (json['title'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
    );
  }
}

class Creator {
  final String name;
  final List<String> booths;
  final String day;
  final String? profileImage;
  final List<CreatorInformation> informations;
  final List<CreatorUrl> urls;
  final DataSource dataSource;

  // Catalog-specific fields
  final String? circleCode;
  final String? circleCutUrl;
  final String? fandom;
  final String? otherFandom;
  final String? rating;
  final String? circleType;
  final Map<String, bool> sellsWhat; // What they sell (comics, artbooks, etc.)
  final Map<String, String?> socialLinks; // Instagram, Facebook, Twitter, etc.

  Creator({
    required this.name,
    required this.booths,
    required this.day,
    this.profileImage,
    this.informations = const [],
    this.urls = const [],
    required this.dataSource,
    this.circleCode,
    this.circleCutUrl,
    this.fandom,
    this.otherFandom,
    this.rating,
    this.circleType,
    this.sellsWhat = const {},
    this.socialLinks = const {},
  });

  factory Creator.fromJson(Map<String, dynamic> json, {DataSource? dataSource}) {
    final source = dataSource ?? DataSource.local;

    if (source == DataSource.catalog) {
      return Creator._fromCatalogJson(json);
    } else {
      return Creator._fromLocalJson(json);
    }
  }

  // Factory for catalog API data
  factory Creator._fromCatalogJson(Map<String, dynamic> json) {
    final circleCode = json['circle_code'] as String?;
    final day = json['day'] as String? ?? 'UNKNOWN';

    // Parse booths from circle_code (handle multi-booth like "AB-37/AB-38")
    final booths = _parseBoothsFromCircleCode(circleCode);

    // Parse sellsWhat from boolean fields
    final sellsWhat = <String, bool>{};
    final sellFields = [
      'SellsCommision', 'SellsComic', 'SellsArtbook', 'SellsPhotobookGeneral',
      'SellsNovel', 'SellsGame', 'SellsMusic', 'SellsGoods', 'SellsHandmadeCrafts',
      'SellsMagazine', 'SellsPhotobookCosplay'
    ];

    for (final field in sellFields) {
      if (json[field] != null) {
        sellsWhat[field.replaceFirst('Sells', '').toLowerCase()] = json[field] as bool;
      }
    }

    // Parse social links
    final socialLinks = <String, String?>{};
    final socialFields = ['circle_facebook', 'circle_instagram', 'circle_twitter', 'circle_other_socials'];
    for (final field in socialFields) {
      socialLinks[field.replaceFirst('circle_', '')] = json[field] as String?;
    }

    return Creator(
      name: json['name'] as String? ?? 'Unknown',
      booths: booths,
      day: day,
      profileImage: json['circle_cut'] as String?,
      dataSource: DataSource.catalog,
      circleCode: circleCode,
      circleCutUrl: json['circle_cut'] as String?,
      fandom: json['fandom'] as String?,
      otherFandom: json['other_fandom'] as String?,
      rating: json['rating'] as String?,
      circleType: json['circle_type'] as String?,
      sellsWhat: sellsWhat,
      socialLinks: socialLinks,
    );
  }

  // Factory for local JSON data
  factory Creator._fromLocalJson(Map<String, dynamic> json) {
    final infosJson = (json['informations'] as List?) ?? const [];
    final urlsJson = (json['urls'] as List?) ?? const [];
    return Creator(
      name: json['name'] as String,
      booths: (json['booths'] as List<dynamic>).map((e) => e.toString()).toList(),
      day: json['day'] as String,
      profileImage: json['profileImage'] as String?,
      informations: infosJson
          .whereType<Map<String, dynamic>>()
          .map((e) => CreatorInformation.fromJson(e))
          .toList(),
      urls: urlsJson
          .whereType<Map<String, dynamic>>()
          .map((e) => CreatorUrl.fromJson(e))
          .toList(),
      dataSource: DataSource.local,
    );
  }

  String get dayDisplay {
    switch (day) {
      case 'BOTH':
        return 'Sat & Sun';
      case 'SAT':
        return 'Saturday';
      case 'SUN':
        return 'Sunday';
      default:
        return day;
    }
  }

  String get boothsDisplay => booths.join(', ');

  // Helper method to parse booths from circle_code (handles multi-booth codes like "AB-37/AB-38")
  static List<String> _parseBoothsFromCircleCode(String? circleCode) {
    if (circleCode == null || circleCode.isEmpty) {
      return [];
    }

    // Split by "/" to handle multi-booth codes
    final boothCodes = circleCode.split('/').map((code) => code.trim()).toList();

    // Further process each booth code to handle day suffixes and letter expansions
    final processedBooths = <String>[];
    for (final code in boothCodes) {
      // Remove day suffix if present (e.g., "AB-37 (SAT)" -> "AB-37")
      final cleanCode = code.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
      
      if (cleanCode.isNotEmpty) {
        // Expand booth codes with multiple letter suffixes
        // e.g., "B-10ab" -> ["B-10a", "B-10b"]
        final expandedBooths = _expandBoothLetterSuffixes(cleanCode);
        processedBooths.addAll(expandedBooths);
      }
    }

    return processedBooths;
  }

  // Helper method to expand booth codes with multiple letter suffixes
  // e.g., "B-10ab" -> ["B-10a", "B-10b"]
  // e.g., "B-09abcd" -> ["B-09a", "B-09b", "B-09c", "B-09d"]
  static List<String> _expandBoothLetterSuffixes(String boothCode) {
    // Match pattern: PREFIX-NUMBER + LETTERS (e.g., "B-10" + "ab")
    final match = RegExp(r'^([A-Z]+-\d+)([a-z]+)$').firstMatch(boothCode);
    
    if (match != null) {
      final prefix = match.group(1)!; // e.g., "B-10"
      final letters = match.group(2)!; // e.g., "ab"
      
      // If there are multiple letters, expand them
      if (letters.length > 1) {
        return letters.split('').map((letter) => '$prefix$letter').toList();
        // e.g., ["B-10a", "B-10b"]
      }
    }
    
    // No expansion needed, return as-is
    return [boothCode];
  }
}

