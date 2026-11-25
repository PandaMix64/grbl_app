// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MachineProfilesTable extends MachineProfiles
    with TableInfo<$MachineProfilesTable, MachineProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MachineProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toolMeta = const VerificationMeta('tool');
  @override
  late final GeneratedColumn<String> tool = GeneratedColumn<String>(
    'tool',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _travelXmmMeta = const VerificationMeta(
    'travelXmm',
  );
  @override
  late final GeneratedColumn<double> travelXmm = GeneratedColumn<double>(
    'travel_xmm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _travelYmmMeta = const VerificationMeta(
    'travelYmm',
  );
  @override
  late final GeneratedColumn<double> travelYmm = GeneratedColumn<double>(
    'travel_ymm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _travelZmmMeta = const VerificationMeta(
    'travelZmm',
  );
  @override
  late final GeneratedColumn<double> travelZmm = GeneratedColumn<double>(
    'travel_zmm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _safeZmmMeta = const VerificationMeta(
    'safeZmm',
  );
  @override
  late final GeneratedColumn<double> safeZmm = GeneratedColumn<double>(
    'safe_zmm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  static const VerificationMeta _backlashXmmMeta = const VerificationMeta(
    'backlashXmm',
  );
  @override
  late final GeneratedColumn<double> backlashXmm = GeneratedColumn<double>(
    'backlash_xmm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _backlashYmmMeta = const VerificationMeta(
    'backlashYmm',
  );
  @override
  late final GeneratedColumn<double> backlashYmm = GeneratedColumn<double>(
    'backlash_ymm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _defaultFeedMmMinMeta = const VerificationMeta(
    'defaultFeedMmMin',
  );
  @override
  late final GeneratedColumn<double> defaultFeedMmMin = GeneratedColumn<double>(
    'default_feed_mm_min',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(800),
  );
  static const VerificationMeta _maxSpindleRpmMeta = const VerificationMeta(
    'maxSpindleRpm',
  );
  @override
  late final GeneratedColumn<double> maxSpindleRpm = GeneratedColumn<double>(
    'max_spindle_rpm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1000),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    tool,
    travelXmm,
    travelYmm,
    travelZmm,
    safeZmm,
    backlashXmm,
    backlashYmm,
    defaultFeedMmMin,
    maxSpindleRpm,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'machine_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<MachineProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('tool')) {
      context.handle(
        _toolMeta,
        tool.isAcceptableOrUnknown(data['tool']!, _toolMeta),
      );
    } else if (isInserting) {
      context.missing(_toolMeta);
    }
    if (data.containsKey('travel_xmm')) {
      context.handle(
        _travelXmmMeta,
        travelXmm.isAcceptableOrUnknown(data['travel_xmm']!, _travelXmmMeta),
      );
    } else if (isInserting) {
      context.missing(_travelXmmMeta);
    }
    if (data.containsKey('travel_ymm')) {
      context.handle(
        _travelYmmMeta,
        travelYmm.isAcceptableOrUnknown(data['travel_ymm']!, _travelYmmMeta),
      );
    } else if (isInserting) {
      context.missing(_travelYmmMeta);
    }
    if (data.containsKey('travel_zmm')) {
      context.handle(
        _travelZmmMeta,
        travelZmm.isAcceptableOrUnknown(data['travel_zmm']!, _travelZmmMeta),
      );
    } else if (isInserting) {
      context.missing(_travelZmmMeta);
    }
    if (data.containsKey('safe_zmm')) {
      context.handle(
        _safeZmmMeta,
        safeZmm.isAcceptableOrUnknown(data['safe_zmm']!, _safeZmmMeta),
      );
    }
    if (data.containsKey('backlash_xmm')) {
      context.handle(
        _backlashXmmMeta,
        backlashXmm.isAcceptableOrUnknown(
          data['backlash_xmm']!,
          _backlashXmmMeta,
        ),
      );
    }
    if (data.containsKey('backlash_ymm')) {
      context.handle(
        _backlashYmmMeta,
        backlashYmm.isAcceptableOrUnknown(
          data['backlash_ymm']!,
          _backlashYmmMeta,
        ),
      );
    }
    if (data.containsKey('default_feed_mm_min')) {
      context.handle(
        _defaultFeedMmMinMeta,
        defaultFeedMmMin.isAcceptableOrUnknown(
          data['default_feed_mm_min']!,
          _defaultFeedMmMinMeta,
        ),
      );
    }
    if (data.containsKey('max_spindle_rpm')) {
      context.handle(
        _maxSpindleRpmMeta,
        maxSpindleRpm.isAcceptableOrUnknown(
          data['max_spindle_rpm']!,
          _maxSpindleRpmMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MachineProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MachineProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      tool: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tool'],
      )!,
      travelXmm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}travel_xmm'],
      )!,
      travelYmm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}travel_ymm'],
      )!,
      travelZmm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}travel_zmm'],
      )!,
      safeZmm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}safe_zmm'],
      )!,
      backlashXmm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}backlash_xmm'],
      )!,
      backlashYmm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}backlash_ymm'],
      )!,
      defaultFeedMmMin: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}default_feed_mm_min'],
      )!,
      maxSpindleRpm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_spindle_rpm'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MachineProfilesTable createAlias(String alias) {
    return $MachineProfilesTable(attachedDatabase, alias);
  }
}

class MachineProfileRow extends DataClass
    implements Insertable<MachineProfileRow> {
  final String id;
  final String name;
  final String tool;
  final double travelXmm;
  final double travelYmm;
  final double travelZmm;
  final double safeZmm;
  final double backlashXmm;
  final double backlashYmm;
  final double defaultFeedMmMin;
  final double maxSpindleRpm;
  final DateTime createdAt;
  final DateTime updatedAt;
  const MachineProfileRow({
    required this.id,
    required this.name,
    required this.tool,
    required this.travelXmm,
    required this.travelYmm,
    required this.travelZmm,
    required this.safeZmm,
    required this.backlashXmm,
    required this.backlashYmm,
    required this.defaultFeedMmMin,
    required this.maxSpindleRpm,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['tool'] = Variable<String>(tool);
    map['travel_xmm'] = Variable<double>(travelXmm);
    map['travel_ymm'] = Variable<double>(travelYmm);
    map['travel_zmm'] = Variable<double>(travelZmm);
    map['safe_zmm'] = Variable<double>(safeZmm);
    map['backlash_xmm'] = Variable<double>(backlashXmm);
    map['backlash_ymm'] = Variable<double>(backlashYmm);
    map['default_feed_mm_min'] = Variable<double>(defaultFeedMmMin);
    map['max_spindle_rpm'] = Variable<double>(maxSpindleRpm);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MachineProfilesCompanion toCompanion(bool nullToAbsent) {
    return MachineProfilesCompanion(
      id: Value(id),
      name: Value(name),
      tool: Value(tool),
      travelXmm: Value(travelXmm),
      travelYmm: Value(travelYmm),
      travelZmm: Value(travelZmm),
      safeZmm: Value(safeZmm),
      backlashXmm: Value(backlashXmm),
      backlashYmm: Value(backlashYmm),
      defaultFeedMmMin: Value(defaultFeedMmMin),
      maxSpindleRpm: Value(maxSpindleRpm),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MachineProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MachineProfileRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      tool: serializer.fromJson<String>(json['tool']),
      travelXmm: serializer.fromJson<double>(json['travelXmm']),
      travelYmm: serializer.fromJson<double>(json['travelYmm']),
      travelZmm: serializer.fromJson<double>(json['travelZmm']),
      safeZmm: serializer.fromJson<double>(json['safeZmm']),
      backlashXmm: serializer.fromJson<double>(json['backlashXmm']),
      backlashYmm: serializer.fromJson<double>(json['backlashYmm']),
      defaultFeedMmMin: serializer.fromJson<double>(json['defaultFeedMmMin']),
      maxSpindleRpm: serializer.fromJson<double>(json['maxSpindleRpm']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'tool': serializer.toJson<String>(tool),
      'travelXmm': serializer.toJson<double>(travelXmm),
      'travelYmm': serializer.toJson<double>(travelYmm),
      'travelZmm': serializer.toJson<double>(travelZmm),
      'safeZmm': serializer.toJson<double>(safeZmm),
      'backlashXmm': serializer.toJson<double>(backlashXmm),
      'backlashYmm': serializer.toJson<double>(backlashYmm),
      'defaultFeedMmMin': serializer.toJson<double>(defaultFeedMmMin),
      'maxSpindleRpm': serializer.toJson<double>(maxSpindleRpm),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MachineProfileRow copyWith({
    String? id,
    String? name,
    String? tool,
    double? travelXmm,
    double? travelYmm,
    double? travelZmm,
    double? safeZmm,
    double? backlashXmm,
    double? backlashYmm,
    double? defaultFeedMmMin,
    double? maxSpindleRpm,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MachineProfileRow(
    id: id ?? this.id,
    name: name ?? this.name,
    tool: tool ?? this.tool,
    travelXmm: travelXmm ?? this.travelXmm,
    travelYmm: travelYmm ?? this.travelYmm,
    travelZmm: travelZmm ?? this.travelZmm,
    safeZmm: safeZmm ?? this.safeZmm,
    backlashXmm: backlashXmm ?? this.backlashXmm,
    backlashYmm: backlashYmm ?? this.backlashYmm,
    defaultFeedMmMin: defaultFeedMmMin ?? this.defaultFeedMmMin,
    maxSpindleRpm: maxSpindleRpm ?? this.maxSpindleRpm,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MachineProfileRow copyWithCompanion(MachineProfilesCompanion data) {
    return MachineProfileRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      tool: data.tool.present ? data.tool.value : this.tool,
      travelXmm: data.travelXmm.present ? data.travelXmm.value : this.travelXmm,
      travelYmm: data.travelYmm.present ? data.travelYmm.value : this.travelYmm,
      travelZmm: data.travelZmm.present ? data.travelZmm.value : this.travelZmm,
      safeZmm: data.safeZmm.present ? data.safeZmm.value : this.safeZmm,
      backlashXmm: data.backlashXmm.present
          ? data.backlashXmm.value
          : this.backlashXmm,
      backlashYmm: data.backlashYmm.present
          ? data.backlashYmm.value
          : this.backlashYmm,
      defaultFeedMmMin: data.defaultFeedMmMin.present
          ? data.defaultFeedMmMin.value
          : this.defaultFeedMmMin,
      maxSpindleRpm: data.maxSpindleRpm.present
          ? data.maxSpindleRpm.value
          : this.maxSpindleRpm,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MachineProfileRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('tool: $tool, ')
          ..write('travelXmm: $travelXmm, ')
          ..write('travelYmm: $travelYmm, ')
          ..write('travelZmm: $travelZmm, ')
          ..write('safeZmm: $safeZmm, ')
          ..write('backlashXmm: $backlashXmm, ')
          ..write('backlashYmm: $backlashYmm, ')
          ..write('defaultFeedMmMin: $defaultFeedMmMin, ')
          ..write('maxSpindleRpm: $maxSpindleRpm, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    tool,
    travelXmm,
    travelYmm,
    travelZmm,
    safeZmm,
    backlashXmm,
    backlashYmm,
    defaultFeedMmMin,
    maxSpindleRpm,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MachineProfileRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.tool == this.tool &&
          other.travelXmm == this.travelXmm &&
          other.travelYmm == this.travelYmm &&
          other.travelZmm == this.travelZmm &&
          other.safeZmm == this.safeZmm &&
          other.backlashXmm == this.backlashXmm &&
          other.backlashYmm == this.backlashYmm &&
          other.defaultFeedMmMin == this.defaultFeedMmMin &&
          other.maxSpindleRpm == this.maxSpindleRpm &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MachineProfilesCompanion extends UpdateCompanion<MachineProfileRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> tool;
  final Value<double> travelXmm;
  final Value<double> travelYmm;
  final Value<double> travelZmm;
  final Value<double> safeZmm;
  final Value<double> backlashXmm;
  final Value<double> backlashYmm;
  final Value<double> defaultFeedMmMin;
  final Value<double> maxSpindleRpm;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MachineProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.tool = const Value.absent(),
    this.travelXmm = const Value.absent(),
    this.travelYmm = const Value.absent(),
    this.travelZmm = const Value.absent(),
    this.safeZmm = const Value.absent(),
    this.backlashXmm = const Value.absent(),
    this.backlashYmm = const Value.absent(),
    this.defaultFeedMmMin = const Value.absent(),
    this.maxSpindleRpm = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MachineProfilesCompanion.insert({
    required String id,
    required String name,
    required String tool,
    required double travelXmm,
    required double travelYmm,
    required double travelZmm,
    this.safeZmm = const Value.absent(),
    this.backlashXmm = const Value.absent(),
    this.backlashYmm = const Value.absent(),
    this.defaultFeedMmMin = const Value.absent(),
    this.maxSpindleRpm = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       tool = Value(tool),
       travelXmm = Value(travelXmm),
       travelYmm = Value(travelYmm),
       travelZmm = Value(travelZmm);
  static Insertable<MachineProfileRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? tool,
    Expression<double>? travelXmm,
    Expression<double>? travelYmm,
    Expression<double>? travelZmm,
    Expression<double>? safeZmm,
    Expression<double>? backlashXmm,
    Expression<double>? backlashYmm,
    Expression<double>? defaultFeedMmMin,
    Expression<double>? maxSpindleRpm,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (tool != null) 'tool': tool,
      if (travelXmm != null) 'travel_xmm': travelXmm,
      if (travelYmm != null) 'travel_ymm': travelYmm,
      if (travelZmm != null) 'travel_zmm': travelZmm,
      if (safeZmm != null) 'safe_zmm': safeZmm,
      if (backlashXmm != null) 'backlash_xmm': backlashXmm,
      if (backlashYmm != null) 'backlash_ymm': backlashYmm,
      if (defaultFeedMmMin != null) 'default_feed_mm_min': defaultFeedMmMin,
      if (maxSpindleRpm != null) 'max_spindle_rpm': maxSpindleRpm,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MachineProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? tool,
    Value<double>? travelXmm,
    Value<double>? travelYmm,
    Value<double>? travelZmm,
    Value<double>? safeZmm,
    Value<double>? backlashXmm,
    Value<double>? backlashYmm,
    Value<double>? defaultFeedMmMin,
    Value<double>? maxSpindleRpm,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MachineProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      tool: tool ?? this.tool,
      travelXmm: travelXmm ?? this.travelXmm,
      travelYmm: travelYmm ?? this.travelYmm,
      travelZmm: travelZmm ?? this.travelZmm,
      safeZmm: safeZmm ?? this.safeZmm,
      backlashXmm: backlashXmm ?? this.backlashXmm,
      backlashYmm: backlashYmm ?? this.backlashYmm,
      defaultFeedMmMin: defaultFeedMmMin ?? this.defaultFeedMmMin,
      maxSpindleRpm: maxSpindleRpm ?? this.maxSpindleRpm,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (tool.present) {
      map['tool'] = Variable<String>(tool.value);
    }
    if (travelXmm.present) {
      map['travel_xmm'] = Variable<double>(travelXmm.value);
    }
    if (travelYmm.present) {
      map['travel_ymm'] = Variable<double>(travelYmm.value);
    }
    if (travelZmm.present) {
      map['travel_zmm'] = Variable<double>(travelZmm.value);
    }
    if (safeZmm.present) {
      map['safe_zmm'] = Variable<double>(safeZmm.value);
    }
    if (backlashXmm.present) {
      map['backlash_xmm'] = Variable<double>(backlashXmm.value);
    }
    if (backlashYmm.present) {
      map['backlash_ymm'] = Variable<double>(backlashYmm.value);
    }
    if (defaultFeedMmMin.present) {
      map['default_feed_mm_min'] = Variable<double>(defaultFeedMmMin.value);
    }
    if (maxSpindleRpm.present) {
      map['max_spindle_rpm'] = Variable<double>(maxSpindleRpm.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MachineProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('tool: $tool, ')
          ..write('travelXmm: $travelXmm, ')
          ..write('travelYmm: $travelYmm, ')
          ..write('travelZmm: $travelZmm, ')
          ..write('safeZmm: $safeZmm, ')
          ..write('backlashXmm: $backlashXmm, ')
          ..write('backlashYmm: $backlashYmm, ')
          ..write('defaultFeedMmMin: $defaultFeedMmMin, ')
          ..write('maxSpindleRpm: $maxSpindleRpm, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectsTable extends Projects
    with TableInfo<$ProjectsTable, ProjectRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gcodeMeta = const VerificationMeta('gcode');
  @override
  late final GeneratedColumn<String> gcode = GeneratedColumn<String>(
    'gcode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  @override
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
    'schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resumeLineIndexMeta = const VerificationMeta(
    'resumeLineIndex',
  );
  @override
  late final GeneratedColumn<int> resumeLineIndex = GeneratedColumn<int>(
    'resume_line_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resumeParserStateMeta = const VerificationMeta(
    'resumeParserState',
  );
  @override
  late final GeneratedColumn<String> resumeParserState =
      GeneratedColumn<String>(
        'resume_parser_state',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _resumeWorkPositionMeta =
      const VerificationMeta('resumeWorkPosition');
  @override
  late final GeneratedColumn<String> resumeWorkPosition =
      GeneratedColumn<String>(
        'resume_work_position',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _resumeSpindleOnMeta = const VerificationMeta(
    'resumeSpindleOn',
  );
  @override
  late final GeneratedColumn<bool> resumeSpindleOn = GeneratedColumn<bool>(
    'resume_spindle_on',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("resume_spindle_on" IN (0, 1))',
    ),
  );
  static const VerificationMeta _resumeFeedMmMinMeta = const VerificationMeta(
    'resumeFeedMmMin',
  );
  @override
  late final GeneratedColumn<double> resumeFeedMmMin = GeneratedColumn<double>(
    'resume_feed_mm_min',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resumeSpindleSpeedMeta =
      const VerificationMeta('resumeSpindleSpeed');
  @override
  late final GeneratedColumn<double> resumeSpindleSpeed =
      GeneratedColumn<double>(
        'resume_spindle_speed',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _resumeSavedAtMeta = const VerificationMeta(
    'resumeSavedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resumeSavedAt =
      GeneratedColumn<DateTime>(
        'resume_saved_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    profileId,
    gcode,
    schemaVersion,
    status,
    resumeLineIndex,
    resumeParserState,
    resumeWorkPosition,
    resumeSpindleOn,
    resumeFeedMmMin,
    resumeSpindleSpeed,
    resumeSavedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('gcode')) {
      context.handle(
        _gcodeMeta,
        gcode.isAcceptableOrUnknown(data['gcode']!, _gcodeMeta),
      );
    } else if (isInserting) {
      context.missing(_gcodeMeta);
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('resume_line_index')) {
      context.handle(
        _resumeLineIndexMeta,
        resumeLineIndex.isAcceptableOrUnknown(
          data['resume_line_index']!,
          _resumeLineIndexMeta,
        ),
      );
    }
    if (data.containsKey('resume_parser_state')) {
      context.handle(
        _resumeParserStateMeta,
        resumeParserState.isAcceptableOrUnknown(
          data['resume_parser_state']!,
          _resumeParserStateMeta,
        ),
      );
    }
    if (data.containsKey('resume_work_position')) {
      context.handle(
        _resumeWorkPositionMeta,
        resumeWorkPosition.isAcceptableOrUnknown(
          data['resume_work_position']!,
          _resumeWorkPositionMeta,
        ),
      );
    }
    if (data.containsKey('resume_spindle_on')) {
      context.handle(
        _resumeSpindleOnMeta,
        resumeSpindleOn.isAcceptableOrUnknown(
          data['resume_spindle_on']!,
          _resumeSpindleOnMeta,
        ),
      );
    }
    if (data.containsKey('resume_feed_mm_min')) {
      context.handle(
        _resumeFeedMmMinMeta,
        resumeFeedMmMin.isAcceptableOrUnknown(
          data['resume_feed_mm_min']!,
          _resumeFeedMmMinMeta,
        ),
      );
    }
    if (data.containsKey('resume_spindle_speed')) {
      context.handle(
        _resumeSpindleSpeedMeta,
        resumeSpindleSpeed.isAcceptableOrUnknown(
          data['resume_spindle_speed']!,
          _resumeSpindleSpeedMeta,
        ),
      );
    }
    if (data.containsKey('resume_saved_at')) {
      context.handle(
        _resumeSavedAtMeta,
        resumeSavedAt.isAcceptableOrUnknown(
          data['resume_saved_at']!,
          _resumeSavedAtMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      gcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gcode'],
      )!,
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_version'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      resumeLineIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resume_line_index'],
      ),
      resumeParserState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resume_parser_state'],
      ),
      resumeWorkPosition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resume_work_position'],
      ),
      resumeSpindleOn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}resume_spindle_on'],
      ),
      resumeFeedMmMin: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}resume_feed_mm_min'],
      ),
      resumeSpindleSpeed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}resume_spindle_speed'],
      ),
      resumeSavedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resume_saved_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }
}

class ProjectRow extends DataClass implements Insertable<ProjectRow> {
  final String id;
  final String name;
  final String profileId;
  final String gcode;

  /// Versión del esquema del archivo `.cncproj`, para migrar al exportar.
  final int schemaVersion;
  final String status;
  final int? resumeLineIndex;
  final String? resumeParserState;

  /// Posición de trabajo serializada como lista JSON (X, Y, Z).
  final String? resumeWorkPosition;
  final bool? resumeSpindleOn;
  final double? resumeFeedMmMin;
  final double? resumeSpindleSpeed;
  final DateTime? resumeSavedAt;
  final DateTime updatedAt;
  const ProjectRow({
    required this.id,
    required this.name,
    required this.profileId,
    required this.gcode,
    required this.schemaVersion,
    required this.status,
    this.resumeLineIndex,
    this.resumeParserState,
    this.resumeWorkPosition,
    this.resumeSpindleOn,
    this.resumeFeedMmMin,
    this.resumeSpindleSpeed,
    this.resumeSavedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['profile_id'] = Variable<String>(profileId);
    map['gcode'] = Variable<String>(gcode);
    map['schema_version'] = Variable<int>(schemaVersion);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || resumeLineIndex != null) {
      map['resume_line_index'] = Variable<int>(resumeLineIndex);
    }
    if (!nullToAbsent || resumeParserState != null) {
      map['resume_parser_state'] = Variable<String>(resumeParserState);
    }
    if (!nullToAbsent || resumeWorkPosition != null) {
      map['resume_work_position'] = Variable<String>(resumeWorkPosition);
    }
    if (!nullToAbsent || resumeSpindleOn != null) {
      map['resume_spindle_on'] = Variable<bool>(resumeSpindleOn);
    }
    if (!nullToAbsent || resumeFeedMmMin != null) {
      map['resume_feed_mm_min'] = Variable<double>(resumeFeedMmMin);
    }
    if (!nullToAbsent || resumeSpindleSpeed != null) {
      map['resume_spindle_speed'] = Variable<double>(resumeSpindleSpeed);
    }
    if (!nullToAbsent || resumeSavedAt != null) {
      map['resume_saved_at'] = Variable<DateTime>(resumeSavedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      name: Value(name),
      profileId: Value(profileId),
      gcode: Value(gcode),
      schemaVersion: Value(schemaVersion),
      status: Value(status),
      resumeLineIndex: resumeLineIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(resumeLineIndex),
      resumeParserState: resumeParserState == null && nullToAbsent
          ? const Value.absent()
          : Value(resumeParserState),
      resumeWorkPosition: resumeWorkPosition == null && nullToAbsent
          ? const Value.absent()
          : Value(resumeWorkPosition),
      resumeSpindleOn: resumeSpindleOn == null && nullToAbsent
          ? const Value.absent()
          : Value(resumeSpindleOn),
      resumeFeedMmMin: resumeFeedMmMin == null && nullToAbsent
          ? const Value.absent()
          : Value(resumeFeedMmMin),
      resumeSpindleSpeed: resumeSpindleSpeed == null && nullToAbsent
          ? const Value.absent()
          : Value(resumeSpindleSpeed),
      resumeSavedAt: resumeSavedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resumeSavedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProjectRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      profileId: serializer.fromJson<String>(json['profileId']),
      gcode: serializer.fromJson<String>(json['gcode']),
      schemaVersion: serializer.fromJson<int>(json['schemaVersion']),
      status: serializer.fromJson<String>(json['status']),
      resumeLineIndex: serializer.fromJson<int?>(json['resumeLineIndex']),
      resumeParserState: serializer.fromJson<String?>(
        json['resumeParserState'],
      ),
      resumeWorkPosition: serializer.fromJson<String?>(
        json['resumeWorkPosition'],
      ),
      resumeSpindleOn: serializer.fromJson<bool?>(json['resumeSpindleOn']),
      resumeFeedMmMin: serializer.fromJson<double?>(json['resumeFeedMmMin']),
      resumeSpindleSpeed: serializer.fromJson<double?>(
        json['resumeSpindleSpeed'],
      ),
      resumeSavedAt: serializer.fromJson<DateTime?>(json['resumeSavedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'profileId': serializer.toJson<String>(profileId),
      'gcode': serializer.toJson<String>(gcode),
      'schemaVersion': serializer.toJson<int>(schemaVersion),
      'status': serializer.toJson<String>(status),
      'resumeLineIndex': serializer.toJson<int?>(resumeLineIndex),
      'resumeParserState': serializer.toJson<String?>(resumeParserState),
      'resumeWorkPosition': serializer.toJson<String?>(resumeWorkPosition),
      'resumeSpindleOn': serializer.toJson<bool?>(resumeSpindleOn),
      'resumeFeedMmMin': serializer.toJson<double?>(resumeFeedMmMin),
      'resumeSpindleSpeed': serializer.toJson<double?>(resumeSpindleSpeed),
      'resumeSavedAt': serializer.toJson<DateTime?>(resumeSavedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProjectRow copyWith({
    String? id,
    String? name,
    String? profileId,
    String? gcode,
    int? schemaVersion,
    String? status,
    Value<int?> resumeLineIndex = const Value.absent(),
    Value<String?> resumeParserState = const Value.absent(),
    Value<String?> resumeWorkPosition = const Value.absent(),
    Value<bool?> resumeSpindleOn = const Value.absent(),
    Value<double?> resumeFeedMmMin = const Value.absent(),
    Value<double?> resumeSpindleSpeed = const Value.absent(),
    Value<DateTime?> resumeSavedAt = const Value.absent(),
    DateTime? updatedAt,
  }) => ProjectRow(
    id: id ?? this.id,
    name: name ?? this.name,
    profileId: profileId ?? this.profileId,
    gcode: gcode ?? this.gcode,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    status: status ?? this.status,
    resumeLineIndex: resumeLineIndex.present
        ? resumeLineIndex.value
        : this.resumeLineIndex,
    resumeParserState: resumeParserState.present
        ? resumeParserState.value
        : this.resumeParserState,
    resumeWorkPosition: resumeWorkPosition.present
        ? resumeWorkPosition.value
        : this.resumeWorkPosition,
    resumeSpindleOn: resumeSpindleOn.present
        ? resumeSpindleOn.value
        : this.resumeSpindleOn,
    resumeFeedMmMin: resumeFeedMmMin.present
        ? resumeFeedMmMin.value
        : this.resumeFeedMmMin,
    resumeSpindleSpeed: resumeSpindleSpeed.present
        ? resumeSpindleSpeed.value
        : this.resumeSpindleSpeed,
    resumeSavedAt: resumeSavedAt.present
        ? resumeSavedAt.value
        : this.resumeSavedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ProjectRow copyWithCompanion(ProjectsCompanion data) {
    return ProjectRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      gcode: data.gcode.present ? data.gcode.value : this.gcode,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      status: data.status.present ? data.status.value : this.status,
      resumeLineIndex: data.resumeLineIndex.present
          ? data.resumeLineIndex.value
          : this.resumeLineIndex,
      resumeParserState: data.resumeParserState.present
          ? data.resumeParserState.value
          : this.resumeParserState,
      resumeWorkPosition: data.resumeWorkPosition.present
          ? data.resumeWorkPosition.value
          : this.resumeWorkPosition,
      resumeSpindleOn: data.resumeSpindleOn.present
          ? data.resumeSpindleOn.value
          : this.resumeSpindleOn,
      resumeFeedMmMin: data.resumeFeedMmMin.present
          ? data.resumeFeedMmMin.value
          : this.resumeFeedMmMin,
      resumeSpindleSpeed: data.resumeSpindleSpeed.present
          ? data.resumeSpindleSpeed.value
          : this.resumeSpindleSpeed,
      resumeSavedAt: data.resumeSavedAt.present
          ? data.resumeSavedAt.value
          : this.resumeSavedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('profileId: $profileId, ')
          ..write('gcode: $gcode, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('status: $status, ')
          ..write('resumeLineIndex: $resumeLineIndex, ')
          ..write('resumeParserState: $resumeParserState, ')
          ..write('resumeWorkPosition: $resumeWorkPosition, ')
          ..write('resumeSpindleOn: $resumeSpindleOn, ')
          ..write('resumeFeedMmMin: $resumeFeedMmMin, ')
          ..write('resumeSpindleSpeed: $resumeSpindleSpeed, ')
          ..write('resumeSavedAt: $resumeSavedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    profileId,
    gcode,
    schemaVersion,
    status,
    resumeLineIndex,
    resumeParserState,
    resumeWorkPosition,
    resumeSpindleOn,
    resumeFeedMmMin,
    resumeSpindleSpeed,
    resumeSavedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.profileId == this.profileId &&
          other.gcode == this.gcode &&
          other.schemaVersion == this.schemaVersion &&
          other.status == this.status &&
          other.resumeLineIndex == this.resumeLineIndex &&
          other.resumeParserState == this.resumeParserState &&
          other.resumeWorkPosition == this.resumeWorkPosition &&
          other.resumeSpindleOn == this.resumeSpindleOn &&
          other.resumeFeedMmMin == this.resumeFeedMmMin &&
          other.resumeSpindleSpeed == this.resumeSpindleSpeed &&
          other.resumeSavedAt == this.resumeSavedAt &&
          other.updatedAt == this.updatedAt);
}

class ProjectsCompanion extends UpdateCompanion<ProjectRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> profileId;
  final Value<String> gcode;
  final Value<int> schemaVersion;
  final Value<String> status;
  final Value<int?> resumeLineIndex;
  final Value<String?> resumeParserState;
  final Value<String?> resumeWorkPosition;
  final Value<bool?> resumeSpindleOn;
  final Value<double?> resumeFeedMmMin;
  final Value<double?> resumeSpindleSpeed;
  final Value<DateTime?> resumeSavedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.profileId = const Value.absent(),
    this.gcode = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.status = const Value.absent(),
    this.resumeLineIndex = const Value.absent(),
    this.resumeParserState = const Value.absent(),
    this.resumeWorkPosition = const Value.absent(),
    this.resumeSpindleOn = const Value.absent(),
    this.resumeFeedMmMin = const Value.absent(),
    this.resumeSpindleSpeed = const Value.absent(),
    this.resumeSavedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectsCompanion.insert({
    required String id,
    required String name,
    required String profileId,
    required String gcode,
    this.schemaVersion = const Value.absent(),
    required String status,
    this.resumeLineIndex = const Value.absent(),
    this.resumeParserState = const Value.absent(),
    this.resumeWorkPosition = const Value.absent(),
    this.resumeSpindleOn = const Value.absent(),
    this.resumeFeedMmMin = const Value.absent(),
    this.resumeSpindleSpeed = const Value.absent(),
    this.resumeSavedAt = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       profileId = Value(profileId),
       gcode = Value(gcode),
       status = Value(status),
       updatedAt = Value(updatedAt);
  static Insertable<ProjectRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? profileId,
    Expression<String>? gcode,
    Expression<int>? schemaVersion,
    Expression<String>? status,
    Expression<int>? resumeLineIndex,
    Expression<String>? resumeParserState,
    Expression<String>? resumeWorkPosition,
    Expression<bool>? resumeSpindleOn,
    Expression<double>? resumeFeedMmMin,
    Expression<double>? resumeSpindleSpeed,
    Expression<DateTime>? resumeSavedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (profileId != null) 'profile_id': profileId,
      if (gcode != null) 'gcode': gcode,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (status != null) 'status': status,
      if (resumeLineIndex != null) 'resume_line_index': resumeLineIndex,
      if (resumeParserState != null) 'resume_parser_state': resumeParserState,
      if (resumeWorkPosition != null)
        'resume_work_position': resumeWorkPosition,
      if (resumeSpindleOn != null) 'resume_spindle_on': resumeSpindleOn,
      if (resumeFeedMmMin != null) 'resume_feed_mm_min': resumeFeedMmMin,
      if (resumeSpindleSpeed != null)
        'resume_spindle_speed': resumeSpindleSpeed,
      if (resumeSavedAt != null) 'resume_saved_at': resumeSavedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? profileId,
    Value<String>? gcode,
    Value<int>? schemaVersion,
    Value<String>? status,
    Value<int?>? resumeLineIndex,
    Value<String?>? resumeParserState,
    Value<String?>? resumeWorkPosition,
    Value<bool?>? resumeSpindleOn,
    Value<double?>? resumeFeedMmMin,
    Value<double?>? resumeSpindleSpeed,
    Value<DateTime?>? resumeSavedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ProjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      profileId: profileId ?? this.profileId,
      gcode: gcode ?? this.gcode,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      status: status ?? this.status,
      resumeLineIndex: resumeLineIndex ?? this.resumeLineIndex,
      resumeParserState: resumeParserState ?? this.resumeParserState,
      resumeWorkPosition: resumeWorkPosition ?? this.resumeWorkPosition,
      resumeSpindleOn: resumeSpindleOn ?? this.resumeSpindleOn,
      resumeFeedMmMin: resumeFeedMmMin ?? this.resumeFeedMmMin,
      resumeSpindleSpeed: resumeSpindleSpeed ?? this.resumeSpindleSpeed,
      resumeSavedAt: resumeSavedAt ?? this.resumeSavedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (gcode.present) {
      map['gcode'] = Variable<String>(gcode.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (resumeLineIndex.present) {
      map['resume_line_index'] = Variable<int>(resumeLineIndex.value);
    }
    if (resumeParserState.present) {
      map['resume_parser_state'] = Variable<String>(resumeParserState.value);
    }
    if (resumeWorkPosition.present) {
      map['resume_work_position'] = Variable<String>(resumeWorkPosition.value);
    }
    if (resumeSpindleOn.present) {
      map['resume_spindle_on'] = Variable<bool>(resumeSpindleOn.value);
    }
    if (resumeFeedMmMin.present) {
      map['resume_feed_mm_min'] = Variable<double>(resumeFeedMmMin.value);
    }
    if (resumeSpindleSpeed.present) {
      map['resume_spindle_speed'] = Variable<double>(resumeSpindleSpeed.value);
    }
    if (resumeSavedAt.present) {
      map['resume_saved_at'] = Variable<DateTime>(resumeSavedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('profileId: $profileId, ')
          ..write('gcode: $gcode, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('status: $status, ')
          ..write('resumeLineIndex: $resumeLineIndex, ')
          ..write('resumeParserState: $resumeParserState, ')
          ..write('resumeWorkPosition: $resumeWorkPosition, ')
          ..write('resumeSpindleOn: $resumeSpindleOn, ')
          ..write('resumeFeedMmMin: $resumeFeedMmMin, ')
          ..write('resumeSpindleSpeed: $resumeSpindleSpeed, ')
          ..write('resumeSavedAt: $resumeSavedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecentFilesTable extends RecentFiles
    with TableInfo<$RecentFilesTable, RecentFileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecentFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openedAtMeta = const VerificationMeta(
    'openedAt',
  );
  @override
  late final GeneratedColumn<DateTime> openedAt = GeneratedColumn<DateTime>(
    'opened_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [path, openedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recent_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecentFileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('opened_at')) {
      context.handle(
        _openedAtMeta,
        openedAt.isAcceptableOrUnknown(data['opened_at']!, _openedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_openedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  RecentFileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecentFileRow(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      openedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}opened_at'],
      )!,
    );
  }

  @override
  $RecentFilesTable createAlias(String alias) {
    return $RecentFilesTable(attachedDatabase, alias);
  }
}

class RecentFileRow extends DataClass implements Insertable<RecentFileRow> {
  final String path;
  final DateTime openedAt;
  const RecentFileRow({required this.path, required this.openedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['opened_at'] = Variable<DateTime>(openedAt);
    return map;
  }

  RecentFilesCompanion toCompanion(bool nullToAbsent) {
    return RecentFilesCompanion(path: Value(path), openedAt: Value(openedAt));
  }

  factory RecentFileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecentFileRow(
      path: serializer.fromJson<String>(json['path']),
      openedAt: serializer.fromJson<DateTime>(json['openedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'openedAt': serializer.toJson<DateTime>(openedAt),
    };
  }

  RecentFileRow copyWith({String? path, DateTime? openedAt}) => RecentFileRow(
    path: path ?? this.path,
    openedAt: openedAt ?? this.openedAt,
  );
  RecentFileRow copyWithCompanion(RecentFilesCompanion data) {
    return RecentFileRow(
      path: data.path.present ? data.path.value : this.path,
      openedAt: data.openedAt.present ? data.openedAt.value : this.openedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecentFileRow(')
          ..write('path: $path, ')
          ..write('openedAt: $openedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, openedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecentFileRow &&
          other.path == this.path &&
          other.openedAt == this.openedAt);
}

class RecentFilesCompanion extends UpdateCompanion<RecentFileRow> {
  final Value<String> path;
  final Value<DateTime> openedAt;
  final Value<int> rowid;
  const RecentFilesCompanion({
    this.path = const Value.absent(),
    this.openedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecentFilesCompanion.insert({
    required String path,
    required DateTime openedAt,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       openedAt = Value(openedAt);
  static Insertable<RecentFileRow> custom({
    Expression<String>? path,
    Expression<DateTime>? openedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (openedAt != null) 'opened_at': openedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecentFilesCompanion copyWith({
    Value<String>? path,
    Value<DateTime>? openedAt,
    Value<int>? rowid,
  }) {
    return RecentFilesCompanion(
      path: path ?? this.path,
      openedAt: openedAt ?? this.openedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (openedAt.present) {
      map['opened_at'] = Variable<DateTime>(openedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecentFilesCompanion(')
          ..write('path: $path, ')
          ..write('openedAt: $openedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MachineProfilesTable machineProfiles = $MachineProfilesTable(
    this,
  );
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $RecentFilesTable recentFiles = $RecentFilesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    machineProfiles,
    projects,
    recentFiles,
  ];
}

typedef $$MachineProfilesTableCreateCompanionBuilder =
    MachineProfilesCompanion Function({
      required String id,
      required String name,
      required String tool,
      required double travelXmm,
      required double travelYmm,
      required double travelZmm,
      Value<double> safeZmm,
      Value<double> backlashXmm,
      Value<double> backlashYmm,
      Value<double> defaultFeedMmMin,
      Value<double> maxSpindleRpm,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$MachineProfilesTableUpdateCompanionBuilder =
    MachineProfilesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> tool,
      Value<double> travelXmm,
      Value<double> travelYmm,
      Value<double> travelZmm,
      Value<double> safeZmm,
      Value<double> backlashXmm,
      Value<double> backlashYmm,
      Value<double> defaultFeedMmMin,
      Value<double> maxSpindleRpm,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$MachineProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $MachineProfilesTable> {
  $$MachineProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tool => $composableBuilder(
    column: $table.tool,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get travelXmm => $composableBuilder(
    column: $table.travelXmm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get travelYmm => $composableBuilder(
    column: $table.travelYmm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get travelZmm => $composableBuilder(
    column: $table.travelZmm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get safeZmm => $composableBuilder(
    column: $table.safeZmm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get backlashXmm => $composableBuilder(
    column: $table.backlashXmm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get backlashYmm => $composableBuilder(
    column: $table.backlashYmm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get defaultFeedMmMin => $composableBuilder(
    column: $table.defaultFeedMmMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxSpindleRpm => $composableBuilder(
    column: $table.maxSpindleRpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MachineProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $MachineProfilesTable> {
  $$MachineProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tool => $composableBuilder(
    column: $table.tool,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get travelXmm => $composableBuilder(
    column: $table.travelXmm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get travelYmm => $composableBuilder(
    column: $table.travelYmm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get travelZmm => $composableBuilder(
    column: $table.travelZmm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get safeZmm => $composableBuilder(
    column: $table.safeZmm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get backlashXmm => $composableBuilder(
    column: $table.backlashXmm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get backlashYmm => $composableBuilder(
    column: $table.backlashYmm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get defaultFeedMmMin => $composableBuilder(
    column: $table.defaultFeedMmMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxSpindleRpm => $composableBuilder(
    column: $table.maxSpindleRpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MachineProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MachineProfilesTable> {
  $$MachineProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get tool =>
      $composableBuilder(column: $table.tool, builder: (column) => column);

  GeneratedColumn<double> get travelXmm =>
      $composableBuilder(column: $table.travelXmm, builder: (column) => column);

  GeneratedColumn<double> get travelYmm =>
      $composableBuilder(column: $table.travelYmm, builder: (column) => column);

  GeneratedColumn<double> get travelZmm =>
      $composableBuilder(column: $table.travelZmm, builder: (column) => column);

  GeneratedColumn<double> get safeZmm =>
      $composableBuilder(column: $table.safeZmm, builder: (column) => column);

  GeneratedColumn<double> get backlashXmm => $composableBuilder(
    column: $table.backlashXmm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get backlashYmm => $composableBuilder(
    column: $table.backlashYmm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get defaultFeedMmMin => $composableBuilder(
    column: $table.defaultFeedMmMin,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxSpindleRpm => $composableBuilder(
    column: $table.maxSpindleRpm,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MachineProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MachineProfilesTable,
          MachineProfileRow,
          $$MachineProfilesTableFilterComposer,
          $$MachineProfilesTableOrderingComposer,
          $$MachineProfilesTableAnnotationComposer,
          $$MachineProfilesTableCreateCompanionBuilder,
          $$MachineProfilesTableUpdateCompanionBuilder,
          (
            MachineProfileRow,
            BaseReferences<
              _$AppDatabase,
              $MachineProfilesTable,
              MachineProfileRow
            >,
          ),
          MachineProfileRow,
          PrefetchHooks Function()
        > {
  $$MachineProfilesTableTableManager(
    _$AppDatabase db,
    $MachineProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MachineProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MachineProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MachineProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> tool = const Value.absent(),
                Value<double> travelXmm = const Value.absent(),
                Value<double> travelYmm = const Value.absent(),
                Value<double> travelZmm = const Value.absent(),
                Value<double> safeZmm = const Value.absent(),
                Value<double> backlashXmm = const Value.absent(),
                Value<double> backlashYmm = const Value.absent(),
                Value<double> defaultFeedMmMin = const Value.absent(),
                Value<double> maxSpindleRpm = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MachineProfilesCompanion(
                id: id,
                name: name,
                tool: tool,
                travelXmm: travelXmm,
                travelYmm: travelYmm,
                travelZmm: travelZmm,
                safeZmm: safeZmm,
                backlashXmm: backlashXmm,
                backlashYmm: backlashYmm,
                defaultFeedMmMin: defaultFeedMmMin,
                maxSpindleRpm: maxSpindleRpm,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String tool,
                required double travelXmm,
                required double travelYmm,
                required double travelZmm,
                Value<double> safeZmm = const Value.absent(),
                Value<double> backlashXmm = const Value.absent(),
                Value<double> backlashYmm = const Value.absent(),
                Value<double> defaultFeedMmMin = const Value.absent(),
                Value<double> maxSpindleRpm = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MachineProfilesCompanion.insert(
                id: id,
                name: name,
                tool: tool,
                travelXmm: travelXmm,
                travelYmm: travelYmm,
                travelZmm: travelZmm,
                safeZmm: safeZmm,
                backlashXmm: backlashXmm,
                backlashYmm: backlashYmm,
                defaultFeedMmMin: defaultFeedMmMin,
                maxSpindleRpm: maxSpindleRpm,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MachineProfilesTable, MachineProfileRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $MachineProfilesTable,
                    MachineProfileRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MachineProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MachineProfilesTable,
      MachineProfileRow,
      $$MachineProfilesTableFilterComposer,
      $$MachineProfilesTableOrderingComposer,
      $$MachineProfilesTableAnnotationComposer,
      $$MachineProfilesTableCreateCompanionBuilder,
      $$MachineProfilesTableUpdateCompanionBuilder,
      (
        MachineProfileRow,
        BaseReferences<_$AppDatabase, $MachineProfilesTable, MachineProfileRow>,
      ),
      MachineProfileRow,
      PrefetchHooks Function()
    >;
typedef $$ProjectsTableCreateCompanionBuilder = ProjectsCompanion Function({
  required String id,
  required String name,
  required String profileId,
  required String gcode,
  Value<int> schemaVersion,
  required String status,
  Value<int?> resumeLineIndex,
  Value<String?> resumeParserState,
  Value<String?> resumeWorkPosition,
  Value<bool?> resumeSpindleOn,
  Value<double?> resumeFeedMmMin,
  Value<double?> resumeSpindleSpeed,
  Value<DateTime?> resumeSavedAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ProjectsTableUpdateCompanionBuilder = ProjectsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> profileId,
  Value<String> gcode,
  Value<int> schemaVersion,
  Value<String> status,
  Value<int?> resumeLineIndex,
  Value<String?> resumeParserState,
  Value<String?> resumeWorkPosition,
  Value<bool?> resumeSpindleOn,
  Value<double?> resumeFeedMmMin,
  Value<double?> resumeSpindleSpeed,
  Value<DateTime?> resumeSavedAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$ProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gcode => $composableBuilder(
    column: $table.gcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resumeLineIndex => $composableBuilder(
    column: $table.resumeLineIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resumeParserState => $composableBuilder(
    column: $table.resumeParserState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resumeWorkPosition => $composableBuilder(
    column: $table.resumeWorkPosition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get resumeSpindleOn => $composableBuilder(
    column: $table.resumeSpindleOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get resumeFeedMmMin => $composableBuilder(
    column: $table.resumeFeedMmMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get resumeSpindleSpeed => $composableBuilder(
    column: $table.resumeSpindleSpeed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resumeSavedAt => $composableBuilder(
    column: $table.resumeSavedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gcode => $composableBuilder(
    column: $table.gcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resumeLineIndex => $composableBuilder(
    column: $table.resumeLineIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resumeParserState => $composableBuilder(
    column: $table.resumeParserState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resumeWorkPosition => $composableBuilder(
    column: $table.resumeWorkPosition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get resumeSpindleOn => $composableBuilder(
    column: $table.resumeSpindleOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get resumeFeedMmMin => $composableBuilder(
    column: $table.resumeFeedMmMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get resumeSpindleSpeed => $composableBuilder(
    column: $table.resumeSpindleSpeed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resumeSavedAt => $composableBuilder(
    column: $table.resumeSavedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get gcode =>
      $composableBuilder(column: $table.gcode, builder: (column) => column);

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get resumeLineIndex => $composableBuilder(
    column: $table.resumeLineIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resumeParserState => $composableBuilder(
    column: $table.resumeParserState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resumeWorkPosition => $composableBuilder(
    column: $table.resumeWorkPosition,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get resumeSpindleOn => $composableBuilder(
    column: $table.resumeSpindleOn,
    builder: (column) => column,
  );

  GeneratedColumn<double> get resumeFeedMmMin => $composableBuilder(
    column: $table.resumeFeedMmMin,
    builder: (column) => column,
  );

  GeneratedColumn<double> get resumeSpindleSpeed => $composableBuilder(
    column: $table.resumeSpindleSpeed,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get resumeSavedAt => $composableBuilder(
    column: $table.resumeSavedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectsTable,
          ProjectRow,
          $$ProjectsTableFilterComposer,
          $$ProjectsTableOrderingComposer,
          $$ProjectsTableAnnotationComposer,
          $$ProjectsTableCreateCompanionBuilder,
          $$ProjectsTableUpdateCompanionBuilder,
          (
            ProjectRow,
            BaseReferences<_$AppDatabase, $ProjectsTable, ProjectRow>,
          ),
          ProjectRow,
          PrefetchHooks Function()
        > {
  $$ProjectsTableTableManager(_$AppDatabase db, $ProjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> gcode = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> resumeLineIndex = const Value.absent(),
                Value<String?> resumeParserState = const Value.absent(),
                Value<String?> resumeWorkPosition = const Value.absent(),
                Value<bool?> resumeSpindleOn = const Value.absent(),
                Value<double?> resumeFeedMmMin = const Value.absent(),
                Value<double?> resumeSpindleSpeed = const Value.absent(),
                Value<DateTime?> resumeSavedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion(
                id: id,
                name: name,
                profileId: profileId,
                gcode: gcode,
                schemaVersion: schemaVersion,
                status: status,
                resumeLineIndex: resumeLineIndex,
                resumeParserState: resumeParserState,
                resumeWorkPosition: resumeWorkPosition,
                resumeSpindleOn: resumeSpindleOn,
                resumeFeedMmMin: resumeFeedMmMin,
                resumeSpindleSpeed: resumeSpindleSpeed,
                resumeSavedAt: resumeSavedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String profileId,
                required String gcode,
                Value<int> schemaVersion = const Value.absent(),
                required String status,
                Value<int?> resumeLineIndex = const Value.absent(),
                Value<String?> resumeParserState = const Value.absent(),
                Value<String?> resumeWorkPosition = const Value.absent(),
                Value<bool?> resumeSpindleOn = const Value.absent(),
                Value<double?> resumeFeedMmMin = const Value.absent(),
                Value<double?> resumeSpindleSpeed = const Value.absent(),
                Value<DateTime?> resumeSavedAt = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion.insert(
                id: id,
                name: name,
                profileId: profileId,
                gcode: gcode,
                schemaVersion: schemaVersion,
                status: status,
                resumeLineIndex: resumeLineIndex,
                resumeParserState: resumeParserState,
                resumeWorkPosition: resumeWorkPosition,
                resumeSpindleOn: resumeSpindleOn,
                resumeFeedMmMin: resumeFeedMmMin,
                resumeSpindleSpeed: resumeSpindleSpeed,
                resumeSavedAt: resumeSavedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProjectsTable, ProjectRow>(table),
                  BaseReferences<_$AppDatabase, $ProjectsTable, ProjectRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectsTable,
      ProjectRow,
      $$ProjectsTableFilterComposer,
      $$ProjectsTableOrderingComposer,
      $$ProjectsTableAnnotationComposer,
      $$ProjectsTableCreateCompanionBuilder,
      $$ProjectsTableUpdateCompanionBuilder,
      (ProjectRow, BaseReferences<_$AppDatabase, $ProjectsTable, ProjectRow>),
      ProjectRow,
      PrefetchHooks Function()
    >;
typedef $$RecentFilesTableCreateCompanionBuilder =
    RecentFilesCompanion Function({
      required String path,
      required DateTime openedAt,
      Value<int> rowid,
    });
typedef $$RecentFilesTableUpdateCompanionBuilder =
    RecentFilesCompanion Function({
      Value<String> path,
      Value<DateTime> openedAt,
      Value<int> rowid,
    });

class $$RecentFilesTableFilterComposer
    extends Composer<_$AppDatabase, $RecentFilesTable> {
  $$RecentFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecentFilesTableOrderingComposer
    extends Composer<_$AppDatabase, $RecentFilesTable> {
  $$RecentFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecentFilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecentFilesTable> {
  $$RecentFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<DateTime> get openedAt =>
      $composableBuilder(column: $table.openedAt, builder: (column) => column);
}

class $$RecentFilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecentFilesTable,
          RecentFileRow,
          $$RecentFilesTableFilterComposer,
          $$RecentFilesTableOrderingComposer,
          $$RecentFilesTableAnnotationComposer,
          $$RecentFilesTableCreateCompanionBuilder,
          $$RecentFilesTableUpdateCompanionBuilder,
          (
            RecentFileRow,
            BaseReferences<_$AppDatabase, $RecentFilesTable, RecentFileRow>,
          ),
          RecentFileRow,
          PrefetchHooks Function()
        > {
  $$RecentFilesTableTableManager(_$AppDatabase db, $RecentFilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecentFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecentFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecentFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<DateTime> openedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecentFilesCompanion(
                path: path,
                openedAt: openedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required DateTime openedAt,
                Value<int> rowid = const Value.absent(),
              }) => RecentFilesCompanion.insert(
                path: path,
                openedAt: openedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecentFilesTable, RecentFileRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $RecentFilesTable,
                    RecentFileRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecentFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecentFilesTable,
      RecentFileRow,
      $$RecentFilesTableFilterComposer,
      $$RecentFilesTableOrderingComposer,
      $$RecentFilesTableAnnotationComposer,
      $$RecentFilesTableCreateCompanionBuilder,
      $$RecentFilesTableUpdateCompanionBuilder,
      (
        RecentFileRow,
        BaseReferences<_$AppDatabase, $RecentFilesTable, RecentFileRow>,
      ),
      RecentFileRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MachineProfilesTableTableManager get machineProfiles =>
      $$MachineProfilesTableTableManager(_db, _db.machineProfiles);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$RecentFilesTableTableManager get recentFiles =>
      $$RecentFilesTableTableManager(_db, _db.recentFiles);
}
