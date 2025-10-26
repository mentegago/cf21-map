import 'package:collection/collection.dart';

import '../utils/string_utils.dart';

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
  final int id;
  final String userId;
  final String name;
  final List<String> booths;
  final String day;
  final String? profileImage;
  final List<CreatorInformation> informations;
  final List<CreatorUrl> urls;
  final List<String> worksType;
  final List<String> fandoms;
  final List<String> sampleworksImages;
  final String? circleCut;
  final String? circleCode;

  // Used for search optimization
  final List<String> searchOptimizedBooths;
  final List<String> searchOptimizedFandoms;

  Creator({
    required this.id,
    required this.userId,
    required this.name,
    required this.booths,
    required this.day,
    this.profileImage,
    this.informations = const [],
    this.urls = const [],
    this.worksType = const [],
    this.fandoms = const [],
    this.sampleworksImages = const [],
    this.circleCut,
    this.circleCode,
  })  : searchOptimizedBooths = booths.map((booth) => optimizedBoothFormat(booth)).toList(),
        searchOptimizedFandoms = 
          fandoms
            .map((fandom) => optimizeStringFormat(fandom))
            .where((fandom) => fandom.isNotEmpty)
            .toList();

  factory Creator.fromJson(Map<String, dynamic> json) {
    final infosJson = (json['informations'] as List?) ?? const [];
    final urlsJson = (json['urls'] as List?) ?? const [];
    final worksTypeJson = (json['works_type'] as List?) ?? const [];
    final fandomsJson = (json['fandoms'] as List?) ?? const [];
    final sampleworksImagesJson = (json['sampleworks_images'] as List?) ?? const [];
    
    return Creator(
      id: json['id'] as int,
      userId: json['user_id'] as String,
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
      worksType: worksTypeJson.map((e) => e.toString()).toList(),
      fandoms: fandomsJson.map((e) => e.toString()).toList().sortedBy((e) => e),
      sampleworksImages: sampleworksImagesJson.map((e) => e.toString()).toList(),
      circleCut: json['circle_cut'] as String?,
      circleCode: json['circle_code'] as String?,
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
  
  String get worksTypeDisplay => worksType.join(', ');
  
  String get fandomsDisplay => fandoms.join(', ');
}

