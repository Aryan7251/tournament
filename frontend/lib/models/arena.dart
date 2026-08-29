class PrizeBreakdown {
  final String rank;
  final int amount;

  PrizeBreakdown({
    required this.rank,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
        'rank': rank,
        'amount': amount,
      };

  factory PrizeBreakdown.fromJson(Map<String, dynamic> json) => PrizeBreakdown(
        rank: json['rank'] as String,
        amount: json['amount'] as int,
      );
}

class RegisteredPlayer {
  final String userId;
  final String username;
  final String inGameId;
  final String joinedAt;

  RegisteredPlayer({
    required this.userId,
    required this.username,
    required this.inGameId,
    required this.joinedAt,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'inGameId': inGameId,
        'joinedAt': joinedAt,
      };

  factory RegisteredPlayer.fromJson(Map<String, dynamic> json) =>
      RegisteredPlayer(
        userId: json['userId'] as String,
        username: json['username'] as String,
        inGameId: json['inGameId'] as String,
        joinedAt: json['joinedAt'] as String,
      );
}

enum ArenaFormat { solo, duo, squad }

extension ArenaFormatExtension on ArenaFormat {
  String get label {
    switch (this) {
      case ArenaFormat.solo:
        return 'Solo';
      case ArenaFormat.duo:
        return 'Duo';
      case ArenaFormat.squad:
        return 'Squad';
    }
  }

  static ArenaFormat fromString(String val) {
    switch (val.toLowerCase()) {
      case 'solo':
        return ArenaFormat.solo;
      case 'duo':
        return ArenaFormat.duo;
      case 'squad':
      default:
        return ArenaFormat.squad;
    }
  }
}

enum ArenaStatus { upcoming, live, completed }

extension ArenaStatusExtension on ArenaStatus {
  String get label {
    switch (this) {
      case ArenaStatus.upcoming:
        return 'Upcoming';
      case ArenaStatus.live:
        return 'Live';
      case ArenaStatus.completed:
        return 'Completed';
    }
  }

  static ArenaStatus fromString(String val) {
    switch (val.toLowerCase()) {
      case 'live':
        return ArenaStatus.live;
      case 'completed':
        return ArenaStatus.completed;
      case 'upcoming':
      default:
        return ArenaStatus.upcoming;
    }
  }
}

class Arena {
  final String id;
  final String title;
  final String game;
  final ArenaFormat format;
  final String map;
  final String server;
  final int entryFee;
  final int prizePool;
  final int perKillPrize;
  final int maxSlots;
  final List<RegisteredPlayer> registeredPlayers;
  final String startTime;
  final ArenaStatus status;
  final String? roomId;
  final String? roomPassword;
  final List<String> rules;
  final List<PrizeBreakdown> prizeDistribution;
  final String? winner;
  final String createdBy;

  Arena({
    required this.id,
    required this.title,
    required this.game,
    required this.format,
    required this.map,
    required this.server,
    required this.entryFee,
    required this.prizePool,
    this.perKillPrize = 0,
    required this.maxSlots,
    required this.registeredPlayers,
    required this.startTime,
    required this.status,
    this.roomId,
    this.roomPassword,
    required this.rules,
    required this.prizeDistribution,
    this.winner,
    required this.createdBy,
  });

  int get filledSlots => registeredPlayers.length;
  bool get isFull => filledSlots >= maxSlots;

  Arena copyWith({
    String? id,
    String? title,
    String? game,
    ArenaFormat? format,
    String? map,
    String? server,
    int? entryFee,
    int? prizePool,
    int? perKillPrize,
    int? maxSlots,
    List<RegisteredPlayer>? registeredPlayers,
    String? startTime,
    ArenaStatus? status,
    String? roomId,
    String? roomPassword,
    List<String>? rules,
    List<PrizeBreakdown>? prizeDistribution,
    String? winner,
    String? createdBy,
  }) {
    return Arena(
      id: id ?? this.id,
      title: title ?? this.title,
      game: game ?? this.game,
      format: format ?? this.format,
      map: map ?? this.map,
      server: server ?? this.server,
      entryFee: entryFee ?? this.entryFee,
      prizePool: prizePool ?? this.prizePool,
      perKillPrize: perKillPrize ?? this.perKillPrize,
      maxSlots: maxSlots ?? this.maxSlots,
      registeredPlayers: registeredPlayers ?? this.registeredPlayers,
      startTime: startTime ?? this.startTime,
      status: status ?? this.status,
      roomId: roomId ?? this.roomId,
      roomPassword: roomPassword ?? this.roomPassword,
      rules: rules ?? this.rules,
      prizeDistribution: prizeDistribution ?? this.prizeDistribution,
      winner: winner ?? this.winner,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'game': game,
        'format': format.label,
        'map': map,
        'server': server,
        'entryFee': entryFee,
        'prizePool': prizePool,
        'perKillPrize': perKillPrize,
        'maxSlots': maxSlots,
        'registeredPlayers':
            registeredPlayers.map((p) => p.toJson()).toList(),
        'startTime': startTime,
        'status': status.name,
        'roomId': roomId,
        'roomPassword': roomPassword,
        'rules': rules,
        'prizeDistribution':
            prizeDistribution.map((p) => p.toJson()).toList(),
        'winner': winner,
        'createdBy': createdBy,
      };

  factory Arena.fromJson(Map<String, dynamic> json) => Arena(
        id: json['id'] as String,
        title: json['title'] as String,
        game: json['game'] as String,
        format: ArenaFormatExtension.fromString(
            json['format'] as String? ?? 'Squad'),
        map: json['map'] as String? ?? 'Erangel',
        server: json['server'] as String? ?? 'Asia',
        entryFee: (json['entryFee'] as num?)?.toInt() ?? 0,
        prizePool: (json['prizePool'] as num?)?.toInt() ?? 0,
        perKillPrize: (json['perKillPrize'] as num?)?.toInt() ?? 0,
        maxSlots: (json['maxSlots'] as num?)?.toInt() ?? 100,
        registeredPlayers: (json['registeredPlayers'] as List<dynamic>?)
                ?.map((e) =>
                    RegisteredPlayer.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        startTime: json['startTime'] as String,
        status: ArenaStatusExtension.fromString(
            json['status'] as String? ?? 'upcoming'),
        roomId: json['roomId'] as String?,
        roomPassword: json['roomPassword'] as String?,
        rules: (json['rules'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        prizeDistribution: (json['prizeDistribution'] as List<dynamic>?)
                ?.map((e) =>
                    PrizeBreakdown.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        winner: json['winner'] as String?,
        createdBy: json['createdBy'] as String? ?? 'official',
      );
}
