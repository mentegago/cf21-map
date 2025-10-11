class Creator {
  final String name;
  final List<String> booths;
  final String day;

  Creator({
    required this.name,
    required this.booths,
    required this.day,
  });

  factory Creator.fromJson(Map<String, dynamic> json) {
    return Creator(
      name: json['name'] as String,
      booths: (json['booths'] as List<dynamic>).map((e) => e.toString()).toList(),
      day: json['day'] as String,
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

