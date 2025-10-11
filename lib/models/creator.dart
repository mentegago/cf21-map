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

  Creator({
    required this.name,
    required this.booths,
    required this.day,
    this.profileImage,
    this.informations = const [],
    this.urls = const [],
  });

  factory Creator.fromJson(Map<String, dynamic> json) {
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
}

