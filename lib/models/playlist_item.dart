class EpgProgram {
  final String title;
  final String start;
  final String end;
  final String? desc;

  EpgProgram({
    required this.title,
    required this.start,
    required this.end,
    this.desc,
  });

  factory EpgProgram.fromJson(Map<String, dynamic> json) {
    return EpgProgram(
      title: json['title'] ?? '',
      start: json['start'] ?? '',
      end: json['end'] ?? '',
      desc: json['desc'],
    );
  }
}

class PlaylistItem {
  final int? num;
  final String streamId;
  final String name;
  final String streamIcon;
  final String categoryId;
  final String categoryName;
  final String url;
  final String type; // 'live' | 'movie' | 'series'
  final String? rating;
  final String? year;
  final String? duration;
  final String? plot;
  final List<EpgProgram>? epg;
  final String? customUserAgent;
  final String? customReferer;
  final Map<String, String>? clearKeys;

  PlaylistItem({
    this.num,
    required this.streamId,
    required this.name,
    required this.streamIcon,
    required this.categoryId,
    required this.categoryName,
    required this.url,
    required this.type,
    this.rating,
    this.year,
    this.duration,
    this.plot,
    this.epg,
    this.customUserAgent,
    this.customReferer,
    this.clearKeys,
  });

  Map<String, dynamic> toJson() => {
    'num': num,
    'streamId': streamId,
    'name': name,
    'streamIcon': streamIcon,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'url': url,
    'type': type,
    'rating': rating,
    'year': year,
    'duration': duration,
    'plot': plot,
    'customUserAgent': customUserAgent,
    'customReferer': customReferer,
    'clearKeys': clearKeys,
  };

  factory PlaylistItem.fromJson(Map<String, dynamic> json) {
    Map<String, String>? parsedKeys;
    if (json['clearKeys'] != null) {
      if (json['clearKeys'] is Map) {
        parsedKeys = Map<String, String>.from(json['clearKeys']);
      } else if (json['clearKeys'] is String && json['clearKeys'].toString().contains(':')) {
        final parts = json['clearKeys'].toString().split(':');
        if (parts.length >= 2) {
          parsedKeys = {parts[0].trim(): parts[1].trim()};
        }
      }
    }
    return PlaylistItem(
      num: json['num'],
      streamId: json['streamId'] ?? '',
      name: json['name'] ?? '',
      streamIcon: json['streamIcon'] ?? '',
      categoryId: json['categoryId'] ?? '',
      categoryName: json['categoryName'] ?? '',
      url: json['url'] ?? '',
      type: json['type'] ?? 'live',
      rating: json['rating'],
      year: json['year'],
      duration: json['duration'],
      plot: json['plot'],
      customUserAgent: json['customUserAgent'],
      customReferer: json['customReferer'],
      clearKeys: parsedKeys,
    );
  }
}

class UserPlaylist {
  final String id;
  final String name;
  final String type; // 'm3u' | 'xtream'
  final String? url;
  final String? host;
  final String? username;
  final String? password;

  UserPlaylist({
    required this.id,
    required this.name,
    required this.type,
    this.url,
    this.host,
    this.username,
    this.password,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'url': url,
    'host': host,
    'username': username,
    'password': password,
  };

  factory UserPlaylist.fromJson(Map<String, dynamic> json) {
    return UserPlaylist(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      url: json['url'],
      host: json['host'],
      username: json['username'],
      password: json['password'],
    );
  }
}
