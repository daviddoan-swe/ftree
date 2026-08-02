// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $FamiliesTable extends Families with TableInfo<$FamiliesTable, Family> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FamiliesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
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
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _usesLunarCalendarMeta = const VerificationMeta(
    'usesLunarCalendar',
  );
  @override
  late final GeneratedColumn<bool> usesLunarCalendar = GeneratedColumn<bool>(
    'uses_lunar_calendar',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("uses_lunar_calendar" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deletedAt,
    id,
    name,
    description,
    usesLunarCalendar,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'families';
  @override
  VerificationContext validateIntegrity(
    Insertable<Family> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
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
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('uses_lunar_calendar')) {
      context.handle(
        _usesLunarCalendarMeta,
        usesLunarCalendar.isAcceptableOrUnknown(
          data['uses_lunar_calendar']!,
          _usesLunarCalendarMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Family map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Family(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      usesLunarCalendar: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}uses_lunar_calendar'],
      )!,
    );
  }

  @override
  $FamiliesTable createAlias(String alias) {
    return $FamiliesTable(attachedDatabase, alias);
  }
}

class Family extends DataClass implements Insertable<Family> {
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String id;
  final String name;
  final String? description;

  /// Whether the family keeps its dates and anniversaries by the lunar
  /// calendar. Travels with the tree rather than following the viewer.
  final bool usesLunarCalendar;
  const Family({
    required this.updatedAt,
    this.deletedAt,
    required this.id,
    required this.name,
    this.description,
    required this.usesLunarCalendar,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['uses_lunar_calendar'] = Variable<bool>(usesLunarCalendar);
    return map;
  }

  FamiliesCompanion toCompanion(bool nullToAbsent) {
    return FamiliesCompanion(
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      usesLunarCalendar: Value(usesLunarCalendar),
    );
  }

  factory Family.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Family(
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      usesLunarCalendar: serializer.fromJson<bool>(json['usesLunarCalendar']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'usesLunarCalendar': serializer.toJson<bool>(usesLunarCalendar),
    };
  }

  Family copyWith({
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    bool? usesLunarCalendar,
  }) => Family(
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    usesLunarCalendar: usesLunarCalendar ?? this.usesLunarCalendar,
  );
  Family copyWithCompanion(FamiliesCompanion data) {
    return Family(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      usesLunarCalendar: data.usesLunarCalendar.present
          ? data.usesLunarCalendar.value
          : this.usesLunarCalendar,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Family(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('usesLunarCalendar: $usesLunarCalendar')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    updatedAt,
    deletedAt,
    id,
    name,
    description,
    usesLunarCalendar,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Family &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.usesLunarCalendar == this.usesLunarCalendar);
}

class FamiliesCompanion extends UpdateCompanion<Family> {
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<bool> usesLunarCalendar;
  final Value<int> rowid;
  const FamiliesCompanion({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.usesLunarCalendar = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FamiliesCompanion.insert({
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    required String id,
    required String name,
    this.description = const Value.absent(),
    this.usesLunarCalendar = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : updatedAt = Value(updatedAt),
       id = Value(id),
       name = Value(name);
  static Insertable<Family> custom({
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<bool>? usesLunarCalendar,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (usesLunarCalendar != null) 'uses_lunar_calendar': usesLunarCalendar,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FamiliesCompanion copyWith({
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<bool>? usesLunarCalendar,
    Value<int>? rowid,
  }) {
    return FamiliesCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      usesLunarCalendar: usesLunarCalendar ?? this.usesLunarCalendar,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (usesLunarCalendar.present) {
      map['uses_lunar_calendar'] = Variable<bool>(usesLunarCalendar.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FamiliesCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('usesLunarCalendar: $usesLunarCalendar, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PersonsTable extends Persons with TableInfo<$PersonsTable, Person> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PersonsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyIdMeta = const VerificationMeta(
    'familyId',
  );
  @override
  late final GeneratedColumn<String> familyId = GeneratedColumn<String>(
    'family_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES families (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _givenNameMeta = const VerificationMeta(
    'givenName',
  );
  @override
  late final GeneratedColumn<String> givenName = GeneratedColumn<String>(
    'given_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _additionalNamesMeta = const VerificationMeta(
    'additionalNames',
  );
  @override
  late final GeneratedColumn<String> additionalNames = GeneratedColumn<String>(
    'additional_names',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _familyNameMeta = const VerificationMeta(
    'familyName',
  );
  @override
  late final GeneratedColumn<String> familyName = GeneratedColumn<String>(
    'family_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _birthFamilyNameMeta = const VerificationMeta(
    'birthFamilyName',
  );
  @override
  late final GeneratedColumn<String> birthFamilyName = GeneratedColumn<String>(
    'birth_family_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Sex, String> sex =
      GeneratedColumn<String>(
        'sex',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Sex>($PersonsTable.$convertersex);
  static const VerificationMeta _birthDateIsoMeta = const VerificationMeta(
    'birthDateIso',
  );
  @override
  late final GeneratedColumn<String> birthDateIso = GeneratedColumn<String>(
    'birth_date_iso',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _birthDateApproximateMeta =
      const VerificationMeta('birthDateApproximate');
  @override
  late final GeneratedColumn<bool> birthDateApproximate = GeneratedColumn<bool>(
    'birth_date_approximate',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("birth_date_approximate" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _birthLunarYearMeta = const VerificationMeta(
    'birthLunarYear',
  );
  @override
  late final GeneratedColumn<int> birthLunarYear = GeneratedColumn<int>(
    'birth_lunar_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _birthLunarMonthMeta = const VerificationMeta(
    'birthLunarMonth',
  );
  @override
  late final GeneratedColumn<int> birthLunarMonth = GeneratedColumn<int>(
    'birth_lunar_month',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _birthLunarDayMeta = const VerificationMeta(
    'birthLunarDay',
  );
  @override
  late final GeneratedColumn<int> birthLunarDay = GeneratedColumn<int>(
    'birth_lunar_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _birthLunarIsLeapMonthMeta =
      const VerificationMeta('birthLunarIsLeapMonth');
  @override
  late final GeneratedColumn<bool> birthLunarIsLeapMonth =
      GeneratedColumn<bool>(
        'birth_lunar_is_leap_month',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("birth_lunar_is_leap_month" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _deathDateIsoMeta = const VerificationMeta(
    'deathDateIso',
  );
  @override
  late final GeneratedColumn<String> deathDateIso = GeneratedColumn<String>(
    'death_date_iso',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deathDateApproximateMeta =
      const VerificationMeta('deathDateApproximate');
  @override
  late final GeneratedColumn<bool> deathDateApproximate = GeneratedColumn<bool>(
    'death_date_approximate',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("death_date_approximate" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deathLunarYearMeta = const VerificationMeta(
    'deathLunarYear',
  );
  @override
  late final GeneratedColumn<int> deathLunarYear = GeneratedColumn<int>(
    'death_lunar_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deathLunarMonthMeta = const VerificationMeta(
    'deathLunarMonth',
  );
  @override
  late final GeneratedColumn<int> deathLunarMonth = GeneratedColumn<int>(
    'death_lunar_month',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deathLunarDayMeta = const VerificationMeta(
    'deathLunarDay',
  );
  @override
  late final GeneratedColumn<int> deathLunarDay = GeneratedColumn<int>(
    'death_lunar_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deathLunarIsLeapMonthMeta =
      const VerificationMeta('deathLunarIsLeapMonth');
  @override
  late final GeneratedColumn<bool> deathLunarIsLeapMonth =
      GeneratedColumn<bool>(
        'death_lunar_is_leap_month',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("death_lunar_is_leap_month" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _birthPlaceMeta = const VerificationMeta(
    'birthPlace',
  );
  @override
  late final GeneratedColumn<String> birthPlace = GeneratedColumn<String>(
    'birth_place',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deathPlaceMeta = const VerificationMeta(
    'deathPlace',
  );
  @override
  late final GeneratedColumn<String> deathPlace = GeneratedColumn<String>(
    'death_place',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _biographyMeta = const VerificationMeta(
    'biography',
  );
  @override
  late final GeneratedColumn<String> biography = GeneratedColumn<String>(
    'biography',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _profileMediaRefMeta = const VerificationMeta(
    'profileMediaRef',
  );
  @override
  late final GeneratedColumn<String> profileMediaRef = GeneratedColumn<String>(
    'profile_media_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deletedAt,
    id,
    familyId,
    displayName,
    givenName,
    additionalNames,
    familyName,
    birthFamilyName,
    sex,
    birthDateIso,
    birthDateApproximate,
    birthLunarYear,
    birthLunarMonth,
    birthLunarDay,
    birthLunarIsLeapMonth,
    deathDateIso,
    deathDateApproximate,
    deathLunarYear,
    deathLunarMonth,
    deathLunarDay,
    deathLunarIsLeapMonth,
    birthPlace,
    deathPlace,
    biography,
    profileMediaRef,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'persons';
  @override
  VerificationContext validateIntegrity(
    Insertable<Person> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('family_id')) {
      context.handle(
        _familyIdMeta,
        familyId.isAcceptableOrUnknown(data['family_id']!, _familyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_familyIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('given_name')) {
      context.handle(
        _givenNameMeta,
        givenName.isAcceptableOrUnknown(data['given_name']!, _givenNameMeta),
      );
    }
    if (data.containsKey('additional_names')) {
      context.handle(
        _additionalNamesMeta,
        additionalNames.isAcceptableOrUnknown(
          data['additional_names']!,
          _additionalNamesMeta,
        ),
      );
    }
    if (data.containsKey('family_name')) {
      context.handle(
        _familyNameMeta,
        familyName.isAcceptableOrUnknown(data['family_name']!, _familyNameMeta),
      );
    }
    if (data.containsKey('birth_family_name')) {
      context.handle(
        _birthFamilyNameMeta,
        birthFamilyName.isAcceptableOrUnknown(
          data['birth_family_name']!,
          _birthFamilyNameMeta,
        ),
      );
    }
    if (data.containsKey('birth_date_iso')) {
      context.handle(
        _birthDateIsoMeta,
        birthDateIso.isAcceptableOrUnknown(
          data['birth_date_iso']!,
          _birthDateIsoMeta,
        ),
      );
    }
    if (data.containsKey('birth_date_approximate')) {
      context.handle(
        _birthDateApproximateMeta,
        birthDateApproximate.isAcceptableOrUnknown(
          data['birth_date_approximate']!,
          _birthDateApproximateMeta,
        ),
      );
    }
    if (data.containsKey('birth_lunar_year')) {
      context.handle(
        _birthLunarYearMeta,
        birthLunarYear.isAcceptableOrUnknown(
          data['birth_lunar_year']!,
          _birthLunarYearMeta,
        ),
      );
    }
    if (data.containsKey('birth_lunar_month')) {
      context.handle(
        _birthLunarMonthMeta,
        birthLunarMonth.isAcceptableOrUnknown(
          data['birth_lunar_month']!,
          _birthLunarMonthMeta,
        ),
      );
    }
    if (data.containsKey('birth_lunar_day')) {
      context.handle(
        _birthLunarDayMeta,
        birthLunarDay.isAcceptableOrUnknown(
          data['birth_lunar_day']!,
          _birthLunarDayMeta,
        ),
      );
    }
    if (data.containsKey('birth_lunar_is_leap_month')) {
      context.handle(
        _birthLunarIsLeapMonthMeta,
        birthLunarIsLeapMonth.isAcceptableOrUnknown(
          data['birth_lunar_is_leap_month']!,
          _birthLunarIsLeapMonthMeta,
        ),
      );
    }
    if (data.containsKey('death_date_iso')) {
      context.handle(
        _deathDateIsoMeta,
        deathDateIso.isAcceptableOrUnknown(
          data['death_date_iso']!,
          _deathDateIsoMeta,
        ),
      );
    }
    if (data.containsKey('death_date_approximate')) {
      context.handle(
        _deathDateApproximateMeta,
        deathDateApproximate.isAcceptableOrUnknown(
          data['death_date_approximate']!,
          _deathDateApproximateMeta,
        ),
      );
    }
    if (data.containsKey('death_lunar_year')) {
      context.handle(
        _deathLunarYearMeta,
        deathLunarYear.isAcceptableOrUnknown(
          data['death_lunar_year']!,
          _deathLunarYearMeta,
        ),
      );
    }
    if (data.containsKey('death_lunar_month')) {
      context.handle(
        _deathLunarMonthMeta,
        deathLunarMonth.isAcceptableOrUnknown(
          data['death_lunar_month']!,
          _deathLunarMonthMeta,
        ),
      );
    }
    if (data.containsKey('death_lunar_day')) {
      context.handle(
        _deathLunarDayMeta,
        deathLunarDay.isAcceptableOrUnknown(
          data['death_lunar_day']!,
          _deathLunarDayMeta,
        ),
      );
    }
    if (data.containsKey('death_lunar_is_leap_month')) {
      context.handle(
        _deathLunarIsLeapMonthMeta,
        deathLunarIsLeapMonth.isAcceptableOrUnknown(
          data['death_lunar_is_leap_month']!,
          _deathLunarIsLeapMonthMeta,
        ),
      );
    }
    if (data.containsKey('birth_place')) {
      context.handle(
        _birthPlaceMeta,
        birthPlace.isAcceptableOrUnknown(data['birth_place']!, _birthPlaceMeta),
      );
    }
    if (data.containsKey('death_place')) {
      context.handle(
        _deathPlaceMeta,
        deathPlace.isAcceptableOrUnknown(data['death_place']!, _deathPlaceMeta),
      );
    }
    if (data.containsKey('biography')) {
      context.handle(
        _biographyMeta,
        biography.isAcceptableOrUnknown(data['biography']!, _biographyMeta),
      );
    }
    if (data.containsKey('profile_media_ref')) {
      context.handle(
        _profileMediaRefMeta,
        profileMediaRef.isAcceptableOrUnknown(
          data['profile_media_ref']!,
          _profileMediaRefMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Person map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Person(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      familyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      givenName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}given_name'],
      ),
      additionalNames: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}additional_names'],
      ),
      familyName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_name'],
      ),
      birthFamilyName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}birth_family_name'],
      ),
      sex: $PersonsTable.$convertersex.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}sex'],
        )!,
      ),
      birthDateIso: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}birth_date_iso'],
      ),
      birthDateApproximate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}birth_date_approximate'],
      )!,
      birthLunarYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}birth_lunar_year'],
      ),
      birthLunarMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}birth_lunar_month'],
      ),
      birthLunarDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}birth_lunar_day'],
      ),
      birthLunarIsLeapMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}birth_lunar_is_leap_month'],
      )!,
      deathDateIso: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}death_date_iso'],
      ),
      deathDateApproximate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}death_date_approximate'],
      )!,
      deathLunarYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}death_lunar_year'],
      ),
      deathLunarMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}death_lunar_month'],
      ),
      deathLunarDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}death_lunar_day'],
      ),
      deathLunarIsLeapMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}death_lunar_is_leap_month'],
      )!,
      birthPlace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}birth_place'],
      ),
      deathPlace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}death_place'],
      ),
      biography: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}biography'],
      ),
      profileMediaRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_media_ref'],
      ),
    );
  }

  @override
  $PersonsTable createAlias(String alias) {
    return $PersonsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<Sex, String, String> $convertersex =
      const EnumNameConverter<Sex>(Sex.values);
}

class Person extends DataClass implements Insertable<Person> {
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String id;
  final String familyId;
  final String displayName;
  final String? givenName;
  final String? additionalNames;
  final String? familyName;

  /// Surname at birth. Present from the first schema because by the time
  /// anyone notices it missing, the values are no longer known (§3.1).
  final String? birthFamilyName;

  /// Stored by name, so the database is readable and adding a value later does
  /// not renumber the existing rows.
  final Sex sex;
  final String? birthDateIso;
  final bool birthDateApproximate;
  final int? birthLunarYear;
  final int? birthLunarMonth;
  final int? birthLunarDay;
  final bool birthLunarIsLeapMonth;
  final String? deathDateIso;
  final bool deathDateApproximate;
  final int? deathLunarYear;
  final int? deathLunarMonth;
  final int? deathLunarDay;
  final bool deathLunarIsLeapMonth;
  final String? birthPlace;
  final String? deathPlace;
  final String? biography;

  /// An opaque reference, deliberately not a foreign key: the media table does
  /// not exist yet (§3.3).
  final String? profileMediaRef;
  const Person({
    required this.updatedAt,
    this.deletedAt,
    required this.id,
    required this.familyId,
    required this.displayName,
    this.givenName,
    this.additionalNames,
    this.familyName,
    this.birthFamilyName,
    required this.sex,
    this.birthDateIso,
    required this.birthDateApproximate,
    this.birthLunarYear,
    this.birthLunarMonth,
    this.birthLunarDay,
    required this.birthLunarIsLeapMonth,
    this.deathDateIso,
    required this.deathDateApproximate,
    this.deathLunarYear,
    this.deathLunarMonth,
    this.deathLunarDay,
    required this.deathLunarIsLeapMonth,
    this.birthPlace,
    this.deathPlace,
    this.biography,
    this.profileMediaRef,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['id'] = Variable<String>(id);
    map['family_id'] = Variable<String>(familyId);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || givenName != null) {
      map['given_name'] = Variable<String>(givenName);
    }
    if (!nullToAbsent || additionalNames != null) {
      map['additional_names'] = Variable<String>(additionalNames);
    }
    if (!nullToAbsent || familyName != null) {
      map['family_name'] = Variable<String>(familyName);
    }
    if (!nullToAbsent || birthFamilyName != null) {
      map['birth_family_name'] = Variable<String>(birthFamilyName);
    }
    {
      map['sex'] = Variable<String>($PersonsTable.$convertersex.toSql(sex));
    }
    if (!nullToAbsent || birthDateIso != null) {
      map['birth_date_iso'] = Variable<String>(birthDateIso);
    }
    map['birth_date_approximate'] = Variable<bool>(birthDateApproximate);
    if (!nullToAbsent || birthLunarYear != null) {
      map['birth_lunar_year'] = Variable<int>(birthLunarYear);
    }
    if (!nullToAbsent || birthLunarMonth != null) {
      map['birth_lunar_month'] = Variable<int>(birthLunarMonth);
    }
    if (!nullToAbsent || birthLunarDay != null) {
      map['birth_lunar_day'] = Variable<int>(birthLunarDay);
    }
    map['birth_lunar_is_leap_month'] = Variable<bool>(birthLunarIsLeapMonth);
    if (!nullToAbsent || deathDateIso != null) {
      map['death_date_iso'] = Variable<String>(deathDateIso);
    }
    map['death_date_approximate'] = Variable<bool>(deathDateApproximate);
    if (!nullToAbsent || deathLunarYear != null) {
      map['death_lunar_year'] = Variable<int>(deathLunarYear);
    }
    if (!nullToAbsent || deathLunarMonth != null) {
      map['death_lunar_month'] = Variable<int>(deathLunarMonth);
    }
    if (!nullToAbsent || deathLunarDay != null) {
      map['death_lunar_day'] = Variable<int>(deathLunarDay);
    }
    map['death_lunar_is_leap_month'] = Variable<bool>(deathLunarIsLeapMonth);
    if (!nullToAbsent || birthPlace != null) {
      map['birth_place'] = Variable<String>(birthPlace);
    }
    if (!nullToAbsent || deathPlace != null) {
      map['death_place'] = Variable<String>(deathPlace);
    }
    if (!nullToAbsent || biography != null) {
      map['biography'] = Variable<String>(biography);
    }
    if (!nullToAbsent || profileMediaRef != null) {
      map['profile_media_ref'] = Variable<String>(profileMediaRef);
    }
    return map;
  }

  PersonsCompanion toCompanion(bool nullToAbsent) {
    return PersonsCompanion(
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      id: Value(id),
      familyId: Value(familyId),
      displayName: Value(displayName),
      givenName: givenName == null && nullToAbsent
          ? const Value.absent()
          : Value(givenName),
      additionalNames: additionalNames == null && nullToAbsent
          ? const Value.absent()
          : Value(additionalNames),
      familyName: familyName == null && nullToAbsent
          ? const Value.absent()
          : Value(familyName),
      birthFamilyName: birthFamilyName == null && nullToAbsent
          ? const Value.absent()
          : Value(birthFamilyName),
      sex: Value(sex),
      birthDateIso: birthDateIso == null && nullToAbsent
          ? const Value.absent()
          : Value(birthDateIso),
      birthDateApproximate: Value(birthDateApproximate),
      birthLunarYear: birthLunarYear == null && nullToAbsent
          ? const Value.absent()
          : Value(birthLunarYear),
      birthLunarMonth: birthLunarMonth == null && nullToAbsent
          ? const Value.absent()
          : Value(birthLunarMonth),
      birthLunarDay: birthLunarDay == null && nullToAbsent
          ? const Value.absent()
          : Value(birthLunarDay),
      birthLunarIsLeapMonth: Value(birthLunarIsLeapMonth),
      deathDateIso: deathDateIso == null && nullToAbsent
          ? const Value.absent()
          : Value(deathDateIso),
      deathDateApproximate: Value(deathDateApproximate),
      deathLunarYear: deathLunarYear == null && nullToAbsent
          ? const Value.absent()
          : Value(deathLunarYear),
      deathLunarMonth: deathLunarMonth == null && nullToAbsent
          ? const Value.absent()
          : Value(deathLunarMonth),
      deathLunarDay: deathLunarDay == null && nullToAbsent
          ? const Value.absent()
          : Value(deathLunarDay),
      deathLunarIsLeapMonth: Value(deathLunarIsLeapMonth),
      birthPlace: birthPlace == null && nullToAbsent
          ? const Value.absent()
          : Value(birthPlace),
      deathPlace: deathPlace == null && nullToAbsent
          ? const Value.absent()
          : Value(deathPlace),
      biography: biography == null && nullToAbsent
          ? const Value.absent()
          : Value(biography),
      profileMediaRef: profileMediaRef == null && nullToAbsent
          ? const Value.absent()
          : Value(profileMediaRef),
    );
  }

  factory Person.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Person(
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      id: serializer.fromJson<String>(json['id']),
      familyId: serializer.fromJson<String>(json['familyId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      givenName: serializer.fromJson<String?>(json['givenName']),
      additionalNames: serializer.fromJson<String?>(json['additionalNames']),
      familyName: serializer.fromJson<String?>(json['familyName']),
      birthFamilyName: serializer.fromJson<String?>(json['birthFamilyName']),
      sex: $PersonsTable.$convertersex.fromJson(
        serializer.fromJson<String>(json['sex']),
      ),
      birthDateIso: serializer.fromJson<String?>(json['birthDateIso']),
      birthDateApproximate: serializer.fromJson<bool>(
        json['birthDateApproximate'],
      ),
      birthLunarYear: serializer.fromJson<int?>(json['birthLunarYear']),
      birthLunarMonth: serializer.fromJson<int?>(json['birthLunarMonth']),
      birthLunarDay: serializer.fromJson<int?>(json['birthLunarDay']),
      birthLunarIsLeapMonth: serializer.fromJson<bool>(
        json['birthLunarIsLeapMonth'],
      ),
      deathDateIso: serializer.fromJson<String?>(json['deathDateIso']),
      deathDateApproximate: serializer.fromJson<bool>(
        json['deathDateApproximate'],
      ),
      deathLunarYear: serializer.fromJson<int?>(json['deathLunarYear']),
      deathLunarMonth: serializer.fromJson<int?>(json['deathLunarMonth']),
      deathLunarDay: serializer.fromJson<int?>(json['deathLunarDay']),
      deathLunarIsLeapMonth: serializer.fromJson<bool>(
        json['deathLunarIsLeapMonth'],
      ),
      birthPlace: serializer.fromJson<String?>(json['birthPlace']),
      deathPlace: serializer.fromJson<String?>(json['deathPlace']),
      biography: serializer.fromJson<String?>(json['biography']),
      profileMediaRef: serializer.fromJson<String?>(json['profileMediaRef']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'id': serializer.toJson<String>(id),
      'familyId': serializer.toJson<String>(familyId),
      'displayName': serializer.toJson<String>(displayName),
      'givenName': serializer.toJson<String?>(givenName),
      'additionalNames': serializer.toJson<String?>(additionalNames),
      'familyName': serializer.toJson<String?>(familyName),
      'birthFamilyName': serializer.toJson<String?>(birthFamilyName),
      'sex': serializer.toJson<String>($PersonsTable.$convertersex.toJson(sex)),
      'birthDateIso': serializer.toJson<String?>(birthDateIso),
      'birthDateApproximate': serializer.toJson<bool>(birthDateApproximate),
      'birthLunarYear': serializer.toJson<int?>(birthLunarYear),
      'birthLunarMonth': serializer.toJson<int?>(birthLunarMonth),
      'birthLunarDay': serializer.toJson<int?>(birthLunarDay),
      'birthLunarIsLeapMonth': serializer.toJson<bool>(birthLunarIsLeapMonth),
      'deathDateIso': serializer.toJson<String?>(deathDateIso),
      'deathDateApproximate': serializer.toJson<bool>(deathDateApproximate),
      'deathLunarYear': serializer.toJson<int?>(deathLunarYear),
      'deathLunarMonth': serializer.toJson<int?>(deathLunarMonth),
      'deathLunarDay': serializer.toJson<int?>(deathLunarDay),
      'deathLunarIsLeapMonth': serializer.toJson<bool>(deathLunarIsLeapMonth),
      'birthPlace': serializer.toJson<String?>(birthPlace),
      'deathPlace': serializer.toJson<String?>(deathPlace),
      'biography': serializer.toJson<String?>(biography),
      'profileMediaRef': serializer.toJson<String?>(profileMediaRef),
    };
  }

  Person copyWith({
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? id,
    String? familyId,
    String? displayName,
    Value<String?> givenName = const Value.absent(),
    Value<String?> additionalNames = const Value.absent(),
    Value<String?> familyName = const Value.absent(),
    Value<String?> birthFamilyName = const Value.absent(),
    Sex? sex,
    Value<String?> birthDateIso = const Value.absent(),
    bool? birthDateApproximate,
    Value<int?> birthLunarYear = const Value.absent(),
    Value<int?> birthLunarMonth = const Value.absent(),
    Value<int?> birthLunarDay = const Value.absent(),
    bool? birthLunarIsLeapMonth,
    Value<String?> deathDateIso = const Value.absent(),
    bool? deathDateApproximate,
    Value<int?> deathLunarYear = const Value.absent(),
    Value<int?> deathLunarMonth = const Value.absent(),
    Value<int?> deathLunarDay = const Value.absent(),
    bool? deathLunarIsLeapMonth,
    Value<String?> birthPlace = const Value.absent(),
    Value<String?> deathPlace = const Value.absent(),
    Value<String?> biography = const Value.absent(),
    Value<String?> profileMediaRef = const Value.absent(),
  }) => Person(
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    id: id ?? this.id,
    familyId: familyId ?? this.familyId,
    displayName: displayName ?? this.displayName,
    givenName: givenName.present ? givenName.value : this.givenName,
    additionalNames: additionalNames.present
        ? additionalNames.value
        : this.additionalNames,
    familyName: familyName.present ? familyName.value : this.familyName,
    birthFamilyName: birthFamilyName.present
        ? birthFamilyName.value
        : this.birthFamilyName,
    sex: sex ?? this.sex,
    birthDateIso: birthDateIso.present ? birthDateIso.value : this.birthDateIso,
    birthDateApproximate: birthDateApproximate ?? this.birthDateApproximate,
    birthLunarYear: birthLunarYear.present
        ? birthLunarYear.value
        : this.birthLunarYear,
    birthLunarMonth: birthLunarMonth.present
        ? birthLunarMonth.value
        : this.birthLunarMonth,
    birthLunarDay: birthLunarDay.present
        ? birthLunarDay.value
        : this.birthLunarDay,
    birthLunarIsLeapMonth: birthLunarIsLeapMonth ?? this.birthLunarIsLeapMonth,
    deathDateIso: deathDateIso.present ? deathDateIso.value : this.deathDateIso,
    deathDateApproximate: deathDateApproximate ?? this.deathDateApproximate,
    deathLunarYear: deathLunarYear.present
        ? deathLunarYear.value
        : this.deathLunarYear,
    deathLunarMonth: deathLunarMonth.present
        ? deathLunarMonth.value
        : this.deathLunarMonth,
    deathLunarDay: deathLunarDay.present
        ? deathLunarDay.value
        : this.deathLunarDay,
    deathLunarIsLeapMonth: deathLunarIsLeapMonth ?? this.deathLunarIsLeapMonth,
    birthPlace: birthPlace.present ? birthPlace.value : this.birthPlace,
    deathPlace: deathPlace.present ? deathPlace.value : this.deathPlace,
    biography: biography.present ? biography.value : this.biography,
    profileMediaRef: profileMediaRef.present
        ? profileMediaRef.value
        : this.profileMediaRef,
  );
  Person copyWithCompanion(PersonsCompanion data) {
    return Person(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      id: data.id.present ? data.id.value : this.id,
      familyId: data.familyId.present ? data.familyId.value : this.familyId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      givenName: data.givenName.present ? data.givenName.value : this.givenName,
      additionalNames: data.additionalNames.present
          ? data.additionalNames.value
          : this.additionalNames,
      familyName: data.familyName.present
          ? data.familyName.value
          : this.familyName,
      birthFamilyName: data.birthFamilyName.present
          ? data.birthFamilyName.value
          : this.birthFamilyName,
      sex: data.sex.present ? data.sex.value : this.sex,
      birthDateIso: data.birthDateIso.present
          ? data.birthDateIso.value
          : this.birthDateIso,
      birthDateApproximate: data.birthDateApproximate.present
          ? data.birthDateApproximate.value
          : this.birthDateApproximate,
      birthLunarYear: data.birthLunarYear.present
          ? data.birthLunarYear.value
          : this.birthLunarYear,
      birthLunarMonth: data.birthLunarMonth.present
          ? data.birthLunarMonth.value
          : this.birthLunarMonth,
      birthLunarDay: data.birthLunarDay.present
          ? data.birthLunarDay.value
          : this.birthLunarDay,
      birthLunarIsLeapMonth: data.birthLunarIsLeapMonth.present
          ? data.birthLunarIsLeapMonth.value
          : this.birthLunarIsLeapMonth,
      deathDateIso: data.deathDateIso.present
          ? data.deathDateIso.value
          : this.deathDateIso,
      deathDateApproximate: data.deathDateApproximate.present
          ? data.deathDateApproximate.value
          : this.deathDateApproximate,
      deathLunarYear: data.deathLunarYear.present
          ? data.deathLunarYear.value
          : this.deathLunarYear,
      deathLunarMonth: data.deathLunarMonth.present
          ? data.deathLunarMonth.value
          : this.deathLunarMonth,
      deathLunarDay: data.deathLunarDay.present
          ? data.deathLunarDay.value
          : this.deathLunarDay,
      deathLunarIsLeapMonth: data.deathLunarIsLeapMonth.present
          ? data.deathLunarIsLeapMonth.value
          : this.deathLunarIsLeapMonth,
      birthPlace: data.birthPlace.present
          ? data.birthPlace.value
          : this.birthPlace,
      deathPlace: data.deathPlace.present
          ? data.deathPlace.value
          : this.deathPlace,
      biography: data.biography.present ? data.biography.value : this.biography,
      profileMediaRef: data.profileMediaRef.present
          ? data.profileMediaRef.value
          : this.profileMediaRef,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Person(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('displayName: $displayName, ')
          ..write('givenName: $givenName, ')
          ..write('additionalNames: $additionalNames, ')
          ..write('familyName: $familyName, ')
          ..write('birthFamilyName: $birthFamilyName, ')
          ..write('sex: $sex, ')
          ..write('birthDateIso: $birthDateIso, ')
          ..write('birthDateApproximate: $birthDateApproximate, ')
          ..write('birthLunarYear: $birthLunarYear, ')
          ..write('birthLunarMonth: $birthLunarMonth, ')
          ..write('birthLunarDay: $birthLunarDay, ')
          ..write('birthLunarIsLeapMonth: $birthLunarIsLeapMonth, ')
          ..write('deathDateIso: $deathDateIso, ')
          ..write('deathDateApproximate: $deathDateApproximate, ')
          ..write('deathLunarYear: $deathLunarYear, ')
          ..write('deathLunarMonth: $deathLunarMonth, ')
          ..write('deathLunarDay: $deathLunarDay, ')
          ..write('deathLunarIsLeapMonth: $deathLunarIsLeapMonth, ')
          ..write('birthPlace: $birthPlace, ')
          ..write('deathPlace: $deathPlace, ')
          ..write('biography: $biography, ')
          ..write('profileMediaRef: $profileMediaRef')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    updatedAt,
    deletedAt,
    id,
    familyId,
    displayName,
    givenName,
    additionalNames,
    familyName,
    birthFamilyName,
    sex,
    birthDateIso,
    birthDateApproximate,
    birthLunarYear,
    birthLunarMonth,
    birthLunarDay,
    birthLunarIsLeapMonth,
    deathDateIso,
    deathDateApproximate,
    deathLunarYear,
    deathLunarMonth,
    deathLunarDay,
    deathLunarIsLeapMonth,
    birthPlace,
    deathPlace,
    biography,
    profileMediaRef,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Person &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.id == this.id &&
          other.familyId == this.familyId &&
          other.displayName == this.displayName &&
          other.givenName == this.givenName &&
          other.additionalNames == this.additionalNames &&
          other.familyName == this.familyName &&
          other.birthFamilyName == this.birthFamilyName &&
          other.sex == this.sex &&
          other.birthDateIso == this.birthDateIso &&
          other.birthDateApproximate == this.birthDateApproximate &&
          other.birthLunarYear == this.birthLunarYear &&
          other.birthLunarMonth == this.birthLunarMonth &&
          other.birthLunarDay == this.birthLunarDay &&
          other.birthLunarIsLeapMonth == this.birthLunarIsLeapMonth &&
          other.deathDateIso == this.deathDateIso &&
          other.deathDateApproximate == this.deathDateApproximate &&
          other.deathLunarYear == this.deathLunarYear &&
          other.deathLunarMonth == this.deathLunarMonth &&
          other.deathLunarDay == this.deathLunarDay &&
          other.deathLunarIsLeapMonth == this.deathLunarIsLeapMonth &&
          other.birthPlace == this.birthPlace &&
          other.deathPlace == this.deathPlace &&
          other.biography == this.biography &&
          other.profileMediaRef == this.profileMediaRef);
}

class PersonsCompanion extends UpdateCompanion<Person> {
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> id;
  final Value<String> familyId;
  final Value<String> displayName;
  final Value<String?> givenName;
  final Value<String?> additionalNames;
  final Value<String?> familyName;
  final Value<String?> birthFamilyName;
  final Value<Sex> sex;
  final Value<String?> birthDateIso;
  final Value<bool> birthDateApproximate;
  final Value<int?> birthLunarYear;
  final Value<int?> birthLunarMonth;
  final Value<int?> birthLunarDay;
  final Value<bool> birthLunarIsLeapMonth;
  final Value<String?> deathDateIso;
  final Value<bool> deathDateApproximate;
  final Value<int?> deathLunarYear;
  final Value<int?> deathLunarMonth;
  final Value<int?> deathLunarDay;
  final Value<bool> deathLunarIsLeapMonth;
  final Value<String?> birthPlace;
  final Value<String?> deathPlace;
  final Value<String?> biography;
  final Value<String?> profileMediaRef;
  final Value<int> rowid;
  const PersonsCompanion({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.familyId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.givenName = const Value.absent(),
    this.additionalNames = const Value.absent(),
    this.familyName = const Value.absent(),
    this.birthFamilyName = const Value.absent(),
    this.sex = const Value.absent(),
    this.birthDateIso = const Value.absent(),
    this.birthDateApproximate = const Value.absent(),
    this.birthLunarYear = const Value.absent(),
    this.birthLunarMonth = const Value.absent(),
    this.birthLunarDay = const Value.absent(),
    this.birthLunarIsLeapMonth = const Value.absent(),
    this.deathDateIso = const Value.absent(),
    this.deathDateApproximate = const Value.absent(),
    this.deathLunarYear = const Value.absent(),
    this.deathLunarMonth = const Value.absent(),
    this.deathLunarDay = const Value.absent(),
    this.deathLunarIsLeapMonth = const Value.absent(),
    this.birthPlace = const Value.absent(),
    this.deathPlace = const Value.absent(),
    this.biography = const Value.absent(),
    this.profileMediaRef = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PersonsCompanion.insert({
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    required String id,
    required String familyId,
    required String displayName,
    this.givenName = const Value.absent(),
    this.additionalNames = const Value.absent(),
    this.familyName = const Value.absent(),
    this.birthFamilyName = const Value.absent(),
    required Sex sex,
    this.birthDateIso = const Value.absent(),
    this.birthDateApproximate = const Value.absent(),
    this.birthLunarYear = const Value.absent(),
    this.birthLunarMonth = const Value.absent(),
    this.birthLunarDay = const Value.absent(),
    this.birthLunarIsLeapMonth = const Value.absent(),
    this.deathDateIso = const Value.absent(),
    this.deathDateApproximate = const Value.absent(),
    this.deathLunarYear = const Value.absent(),
    this.deathLunarMonth = const Value.absent(),
    this.deathLunarDay = const Value.absent(),
    this.deathLunarIsLeapMonth = const Value.absent(),
    this.birthPlace = const Value.absent(),
    this.deathPlace = const Value.absent(),
    this.biography = const Value.absent(),
    this.profileMediaRef = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : updatedAt = Value(updatedAt),
       id = Value(id),
       familyId = Value(familyId),
       displayName = Value(displayName),
       sex = Value(sex);
  static Insertable<Person> custom({
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? id,
    Expression<String>? familyId,
    Expression<String>? displayName,
    Expression<String>? givenName,
    Expression<String>? additionalNames,
    Expression<String>? familyName,
    Expression<String>? birthFamilyName,
    Expression<String>? sex,
    Expression<String>? birthDateIso,
    Expression<bool>? birthDateApproximate,
    Expression<int>? birthLunarYear,
    Expression<int>? birthLunarMonth,
    Expression<int>? birthLunarDay,
    Expression<bool>? birthLunarIsLeapMonth,
    Expression<String>? deathDateIso,
    Expression<bool>? deathDateApproximate,
    Expression<int>? deathLunarYear,
    Expression<int>? deathLunarMonth,
    Expression<int>? deathLunarDay,
    Expression<bool>? deathLunarIsLeapMonth,
    Expression<String>? birthPlace,
    Expression<String>? deathPlace,
    Expression<String>? biography,
    Expression<String>? profileMediaRef,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (id != null) 'id': id,
      if (familyId != null) 'family_id': familyId,
      if (displayName != null) 'display_name': displayName,
      if (givenName != null) 'given_name': givenName,
      if (additionalNames != null) 'additional_names': additionalNames,
      if (familyName != null) 'family_name': familyName,
      if (birthFamilyName != null) 'birth_family_name': birthFamilyName,
      if (sex != null) 'sex': sex,
      if (birthDateIso != null) 'birth_date_iso': birthDateIso,
      if (birthDateApproximate != null)
        'birth_date_approximate': birthDateApproximate,
      if (birthLunarYear != null) 'birth_lunar_year': birthLunarYear,
      if (birthLunarMonth != null) 'birth_lunar_month': birthLunarMonth,
      if (birthLunarDay != null) 'birth_lunar_day': birthLunarDay,
      if (birthLunarIsLeapMonth != null)
        'birth_lunar_is_leap_month': birthLunarIsLeapMonth,
      if (deathDateIso != null) 'death_date_iso': deathDateIso,
      if (deathDateApproximate != null)
        'death_date_approximate': deathDateApproximate,
      if (deathLunarYear != null) 'death_lunar_year': deathLunarYear,
      if (deathLunarMonth != null) 'death_lunar_month': deathLunarMonth,
      if (deathLunarDay != null) 'death_lunar_day': deathLunarDay,
      if (deathLunarIsLeapMonth != null)
        'death_lunar_is_leap_month': deathLunarIsLeapMonth,
      if (birthPlace != null) 'birth_place': birthPlace,
      if (deathPlace != null) 'death_place': deathPlace,
      if (biography != null) 'biography': biography,
      if (profileMediaRef != null) 'profile_media_ref': profileMediaRef,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PersonsCompanion copyWith({
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? id,
    Value<String>? familyId,
    Value<String>? displayName,
    Value<String?>? givenName,
    Value<String?>? additionalNames,
    Value<String?>? familyName,
    Value<String?>? birthFamilyName,
    Value<Sex>? sex,
    Value<String?>? birthDateIso,
    Value<bool>? birthDateApproximate,
    Value<int?>? birthLunarYear,
    Value<int?>? birthLunarMonth,
    Value<int?>? birthLunarDay,
    Value<bool>? birthLunarIsLeapMonth,
    Value<String?>? deathDateIso,
    Value<bool>? deathDateApproximate,
    Value<int?>? deathLunarYear,
    Value<int?>? deathLunarMonth,
    Value<int?>? deathLunarDay,
    Value<bool>? deathLunarIsLeapMonth,
    Value<String?>? birthPlace,
    Value<String?>? deathPlace,
    Value<String?>? biography,
    Value<String?>? profileMediaRef,
    Value<int>? rowid,
  }) {
    return PersonsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      displayName: displayName ?? this.displayName,
      givenName: givenName ?? this.givenName,
      additionalNames: additionalNames ?? this.additionalNames,
      familyName: familyName ?? this.familyName,
      birthFamilyName: birthFamilyName ?? this.birthFamilyName,
      sex: sex ?? this.sex,
      birthDateIso: birthDateIso ?? this.birthDateIso,
      birthDateApproximate: birthDateApproximate ?? this.birthDateApproximate,
      birthLunarYear: birthLunarYear ?? this.birthLunarYear,
      birthLunarMonth: birthLunarMonth ?? this.birthLunarMonth,
      birthLunarDay: birthLunarDay ?? this.birthLunarDay,
      birthLunarIsLeapMonth:
          birthLunarIsLeapMonth ?? this.birthLunarIsLeapMonth,
      deathDateIso: deathDateIso ?? this.deathDateIso,
      deathDateApproximate: deathDateApproximate ?? this.deathDateApproximate,
      deathLunarYear: deathLunarYear ?? this.deathLunarYear,
      deathLunarMonth: deathLunarMonth ?? this.deathLunarMonth,
      deathLunarDay: deathLunarDay ?? this.deathLunarDay,
      deathLunarIsLeapMonth:
          deathLunarIsLeapMonth ?? this.deathLunarIsLeapMonth,
      birthPlace: birthPlace ?? this.birthPlace,
      deathPlace: deathPlace ?? this.deathPlace,
      biography: biography ?? this.biography,
      profileMediaRef: profileMediaRef ?? this.profileMediaRef,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (familyId.present) {
      map['family_id'] = Variable<String>(familyId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (givenName.present) {
      map['given_name'] = Variable<String>(givenName.value);
    }
    if (additionalNames.present) {
      map['additional_names'] = Variable<String>(additionalNames.value);
    }
    if (familyName.present) {
      map['family_name'] = Variable<String>(familyName.value);
    }
    if (birthFamilyName.present) {
      map['birth_family_name'] = Variable<String>(birthFamilyName.value);
    }
    if (sex.present) {
      map['sex'] = Variable<String>(
        $PersonsTable.$convertersex.toSql(sex.value),
      );
    }
    if (birthDateIso.present) {
      map['birth_date_iso'] = Variable<String>(birthDateIso.value);
    }
    if (birthDateApproximate.present) {
      map['birth_date_approximate'] = Variable<bool>(
        birthDateApproximate.value,
      );
    }
    if (birthLunarYear.present) {
      map['birth_lunar_year'] = Variable<int>(birthLunarYear.value);
    }
    if (birthLunarMonth.present) {
      map['birth_lunar_month'] = Variable<int>(birthLunarMonth.value);
    }
    if (birthLunarDay.present) {
      map['birth_lunar_day'] = Variable<int>(birthLunarDay.value);
    }
    if (birthLunarIsLeapMonth.present) {
      map['birth_lunar_is_leap_month'] = Variable<bool>(
        birthLunarIsLeapMonth.value,
      );
    }
    if (deathDateIso.present) {
      map['death_date_iso'] = Variable<String>(deathDateIso.value);
    }
    if (deathDateApproximate.present) {
      map['death_date_approximate'] = Variable<bool>(
        deathDateApproximate.value,
      );
    }
    if (deathLunarYear.present) {
      map['death_lunar_year'] = Variable<int>(deathLunarYear.value);
    }
    if (deathLunarMonth.present) {
      map['death_lunar_month'] = Variable<int>(deathLunarMonth.value);
    }
    if (deathLunarDay.present) {
      map['death_lunar_day'] = Variable<int>(deathLunarDay.value);
    }
    if (deathLunarIsLeapMonth.present) {
      map['death_lunar_is_leap_month'] = Variable<bool>(
        deathLunarIsLeapMonth.value,
      );
    }
    if (birthPlace.present) {
      map['birth_place'] = Variable<String>(birthPlace.value);
    }
    if (deathPlace.present) {
      map['death_place'] = Variable<String>(deathPlace.value);
    }
    if (biography.present) {
      map['biography'] = Variable<String>(biography.value);
    }
    if (profileMediaRef.present) {
      map['profile_media_ref'] = Variable<String>(profileMediaRef.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PersonsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('displayName: $displayName, ')
          ..write('givenName: $givenName, ')
          ..write('additionalNames: $additionalNames, ')
          ..write('familyName: $familyName, ')
          ..write('birthFamilyName: $birthFamilyName, ')
          ..write('sex: $sex, ')
          ..write('birthDateIso: $birthDateIso, ')
          ..write('birthDateApproximate: $birthDateApproximate, ')
          ..write('birthLunarYear: $birthLunarYear, ')
          ..write('birthLunarMonth: $birthLunarMonth, ')
          ..write('birthLunarDay: $birthLunarDay, ')
          ..write('birthLunarIsLeapMonth: $birthLunarIsLeapMonth, ')
          ..write('deathDateIso: $deathDateIso, ')
          ..write('deathDateApproximate: $deathDateApproximate, ')
          ..write('deathLunarYear: $deathLunarYear, ')
          ..write('deathLunarMonth: $deathLunarMonth, ')
          ..write('deathLunarDay: $deathLunarDay, ')
          ..write('deathLunarIsLeapMonth: $deathLunarIsLeapMonth, ')
          ..write('birthPlace: $birthPlace, ')
          ..write('deathPlace: $deathPlace, ')
          ..write('biography: $biography, ')
          ..write('profileMediaRef: $profileMediaRef, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RelationshipsTable extends Relationships
    with TableInfo<$RelationshipsTable, Relationship> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RelationshipsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyIdMeta = const VerificationMeta(
    'familyId',
  );
  @override
  late final GeneratedColumn<String> familyId = GeneratedColumn<String>(
    'family_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES families (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<RelationshipType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<RelationshipType>($RelationshipsTable.$convertertype);
  static const VerificationMeta _personAIdMeta = const VerificationMeta(
    'personAId',
  );
  @override
  late final GeneratedColumn<String> personAId = GeneratedColumn<String>(
    'person_a_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES persons (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _personBIdMeta = const VerificationMeta(
    'personBId',
  );
  @override
  late final GeneratedColumn<String> personBId = GeneratedColumn<String>(
    'person_b_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES persons (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deletedAt,
    id,
    familyId,
    type,
    personAId,
    personBId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'relationships';
  @override
  VerificationContext validateIntegrity(
    Insertable<Relationship> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('family_id')) {
      context.handle(
        _familyIdMeta,
        familyId.isAcceptableOrUnknown(data['family_id']!, _familyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_familyIdMeta);
    }
    if (data.containsKey('person_a_id')) {
      context.handle(
        _personAIdMeta,
        personAId.isAcceptableOrUnknown(data['person_a_id']!, _personAIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personAIdMeta);
    }
    if (data.containsKey('person_b_id')) {
      context.handle(
        _personBIdMeta,
        personBId.isAcceptableOrUnknown(data['person_b_id']!, _personBIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personBIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {familyId, type, personAId, personBId},
  ];
  @override
  Relationship map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Relationship(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      familyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_id'],
      )!,
      type: $RelationshipsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      personAId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}person_a_id'],
      )!,
      personBId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}person_b_id'],
      )!,
    );
  }

  @override
  $RelationshipsTable createAlias(String alias) {
    return $RelationshipsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RelationshipType, String, String> $convertertype =
      const EnumNameConverter<RelationshipType>(RelationshipType.values);
}

class Relationship extends DataClass implements Insertable<Relationship> {
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String id;
  final String familyId;
  final RelationshipType type;
  final String personAId;
  final String personBId;
  const Relationship({
    required this.updatedAt,
    this.deletedAt,
    required this.id,
    required this.familyId,
    required this.type,
    required this.personAId,
    required this.personBId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['id'] = Variable<String>(id);
    map['family_id'] = Variable<String>(familyId);
    {
      map['type'] = Variable<String>(
        $RelationshipsTable.$convertertype.toSql(type),
      );
    }
    map['person_a_id'] = Variable<String>(personAId);
    map['person_b_id'] = Variable<String>(personBId);
    return map;
  }

  RelationshipsCompanion toCompanion(bool nullToAbsent) {
    return RelationshipsCompanion(
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      id: Value(id),
      familyId: Value(familyId),
      type: Value(type),
      personAId: Value(personAId),
      personBId: Value(personBId),
    );
  }

  factory Relationship.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Relationship(
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      id: serializer.fromJson<String>(json['id']),
      familyId: serializer.fromJson<String>(json['familyId']),
      type: $RelationshipsTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      personAId: serializer.fromJson<String>(json['personAId']),
      personBId: serializer.fromJson<String>(json['personBId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'id': serializer.toJson<String>(id),
      'familyId': serializer.toJson<String>(familyId),
      'type': serializer.toJson<String>(
        $RelationshipsTable.$convertertype.toJson(type),
      ),
      'personAId': serializer.toJson<String>(personAId),
      'personBId': serializer.toJson<String>(personBId),
    };
  }

  Relationship copyWith({
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? id,
    String? familyId,
    RelationshipType? type,
    String? personAId,
    String? personBId,
  }) => Relationship(
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    id: id ?? this.id,
    familyId: familyId ?? this.familyId,
    type: type ?? this.type,
    personAId: personAId ?? this.personAId,
    personBId: personBId ?? this.personBId,
  );
  Relationship copyWithCompanion(RelationshipsCompanion data) {
    return Relationship(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      id: data.id.present ? data.id.value : this.id,
      familyId: data.familyId.present ? data.familyId.value : this.familyId,
      type: data.type.present ? data.type.value : this.type,
      personAId: data.personAId.present ? data.personAId.value : this.personAId,
      personBId: data.personBId.present ? data.personBId.value : this.personBId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Relationship(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('type: $type, ')
          ..write('personAId: $personAId, ')
          ..write('personBId: $personBId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    updatedAt,
    deletedAt,
    id,
    familyId,
    type,
    personAId,
    personBId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Relationship &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.id == this.id &&
          other.familyId == this.familyId &&
          other.type == this.type &&
          other.personAId == this.personAId &&
          other.personBId == this.personBId);
}

class RelationshipsCompanion extends UpdateCompanion<Relationship> {
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> id;
  final Value<String> familyId;
  final Value<RelationshipType> type;
  final Value<String> personAId;
  final Value<String> personBId;
  final Value<int> rowid;
  const RelationshipsCompanion({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.familyId = const Value.absent(),
    this.type = const Value.absent(),
    this.personAId = const Value.absent(),
    this.personBId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RelationshipsCompanion.insert({
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    required String id,
    required String familyId,
    required RelationshipType type,
    required String personAId,
    required String personBId,
    this.rowid = const Value.absent(),
  }) : updatedAt = Value(updatedAt),
       id = Value(id),
       familyId = Value(familyId),
       type = Value(type),
       personAId = Value(personAId),
       personBId = Value(personBId);
  static Insertable<Relationship> custom({
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? id,
    Expression<String>? familyId,
    Expression<String>? type,
    Expression<String>? personAId,
    Expression<String>? personBId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (id != null) 'id': id,
      if (familyId != null) 'family_id': familyId,
      if (type != null) 'type': type,
      if (personAId != null) 'person_a_id': personAId,
      if (personBId != null) 'person_b_id': personBId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RelationshipsCompanion copyWith({
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? id,
    Value<String>? familyId,
    Value<RelationshipType>? type,
    Value<String>? personAId,
    Value<String>? personBId,
    Value<int>? rowid,
  }) {
    return RelationshipsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      type: type ?? this.type,
      personAId: personAId ?? this.personAId,
      personBId: personBId ?? this.personBId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (familyId.present) {
      map['family_id'] = Variable<String>(familyId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $RelationshipsTable.$convertertype.toSql(type.value),
      );
    }
    if (personAId.present) {
      map['person_a_id'] = Variable<String>(personAId.value);
    }
    if (personBId.present) {
      map['person_b_id'] = Variable<String>(personBId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RelationshipsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('type: $type, ')
          ..write('personAId: $personAId, ')
          ..write('personBId: $personBId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FamiliesTable families = $FamiliesTable(this);
  late final $PersonsTable persons = $PersonsTable(this);
  late final $RelationshipsTable relationships = $RelationshipsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    families,
    persons,
    relationships,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'families',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('persons', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'families',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('relationships', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'persons',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('relationships', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'persons',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('relationships', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$FamiliesTableCreateCompanionBuilder =
    FamiliesCompanion Function({
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      required String id,
      required String name,
      Value<String?> description,
      Value<bool> usesLunarCalendar,
      Value<int> rowid,
    });
typedef $$FamiliesTableUpdateCompanionBuilder =
    FamiliesCompanion Function({
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String> id,
      Value<String> name,
      Value<String?> description,
      Value<bool> usesLunarCalendar,
      Value<int> rowid,
    });

final class $$FamiliesTableReferences
    extends BaseReferences<_$AppDatabase, $FamiliesTable, Family> {
  $$FamiliesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PersonsTable, List<Person>> _personsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.persons,
    aliasName: 'families__id__persons__family_id',
  );

  $$PersonsTableProcessedTableManager get personsRefs {
    final manager = $$PersonsTableTableManager(
      $_db,
      $_db.persons,
    ).filter((f) => f.familyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_personsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RelationshipsTable, List<Relationship>>
  _relationshipsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.relationships,
    aliasName: 'families__id__relationships__family_id',
  );

  $$RelationshipsTableProcessedTableManager get relationshipsRefs {
    final manager = $$RelationshipsTableTableManager(
      $_db,
      $_db.relationships,
    ).filter((f) => f.familyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_relationshipsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FamiliesTableFilterComposer
    extends Composer<_$AppDatabase, $FamiliesTable> {
  $$FamiliesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get usesLunarCalendar => $composableBuilder(
    column: $table.usesLunarCalendar,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> personsRefs(
    Expression<bool> Function($$PersonsTableFilterComposer f) f,
  ) {
    final $$PersonsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.persons,
      getReferencedColumn: (t) => t.familyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonsTableFilterComposer(
            $db: $db,
            $table: $db.persons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> relationshipsRefs(
    Expression<bool> Function($$RelationshipsTableFilterComposer f) f,
  ) {
    final $$RelationshipsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.relationships,
      getReferencedColumn: (t) => t.familyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RelationshipsTableFilterComposer(
            $db: $db,
            $table: $db.relationships,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FamiliesTableOrderingComposer
    extends Composer<_$AppDatabase, $FamiliesTable> {
  $$FamiliesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get usesLunarCalendar => $composableBuilder(
    column: $table.usesLunarCalendar,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FamiliesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FamiliesTable> {
  $$FamiliesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get usesLunarCalendar => $composableBuilder(
    column: $table.usesLunarCalendar,
    builder: (column) => column,
  );

  Expression<T> personsRefs<T extends Object>(
    Expression<T> Function($$PersonsTableAnnotationComposer a) f,
  ) {
    final $$PersonsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.persons,
      getReferencedColumn: (t) => t.familyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonsTableAnnotationComposer(
            $db: $db,
            $table: $db.persons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> relationshipsRefs<T extends Object>(
    Expression<T> Function($$RelationshipsTableAnnotationComposer a) f,
  ) {
    final $$RelationshipsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.relationships,
      getReferencedColumn: (t) => t.familyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RelationshipsTableAnnotationComposer(
            $db: $db,
            $table: $db.relationships,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FamiliesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FamiliesTable,
          Family,
          $$FamiliesTableFilterComposer,
          $$FamiliesTableOrderingComposer,
          $$FamiliesTableAnnotationComposer,
          $$FamiliesTableCreateCompanionBuilder,
          $$FamiliesTableUpdateCompanionBuilder,
          (Family, $$FamiliesTableReferences),
          Family,
          PrefetchHooks Function({bool personsRefs, bool relationshipsRefs})
        > {
  $$FamiliesTableTableManager(_$AppDatabase db, $FamiliesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FamiliesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FamiliesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FamiliesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> usesLunarCalendar = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FamiliesCompanion(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                name: name,
                description: description,
                usesLunarCalendar: usesLunarCalendar,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                required String id,
                required String name,
                Value<String?> description = const Value.absent(),
                Value<bool> usesLunarCalendar = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FamiliesCompanion.insert(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                name: name,
                description: description,
                usesLunarCalendar: usesLunarCalendar,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FamiliesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({personsRefs = false, relationshipsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (personsRefs) db.persons,
                    if (relationshipsRefs) db.relationships,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (personsRefs)
                        await $_getPrefetchedData<
                          Family,
                          $FamiliesTable,
                          Person
                        >(
                          currentTable: table,
                          referencedTable: $$FamiliesTableReferences
                              ._personsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FamiliesTableReferences(
                                db,
                                table,
                                p0,
                              ).personsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.familyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (relationshipsRefs)
                        await $_getPrefetchedData<
                          Family,
                          $FamiliesTable,
                          Relationship
                        >(
                          currentTable: table,
                          referencedTable: $$FamiliesTableReferences
                              ._relationshipsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FamiliesTableReferences(
                                db,
                                table,
                                p0,
                              ).relationshipsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.familyId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FamiliesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FamiliesTable,
      Family,
      $$FamiliesTableFilterComposer,
      $$FamiliesTableOrderingComposer,
      $$FamiliesTableAnnotationComposer,
      $$FamiliesTableCreateCompanionBuilder,
      $$FamiliesTableUpdateCompanionBuilder,
      (Family, $$FamiliesTableReferences),
      Family,
      PrefetchHooks Function({bool personsRefs, bool relationshipsRefs})
    >;
typedef $$PersonsTableCreateCompanionBuilder =
    PersonsCompanion Function({
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      required String id,
      required String familyId,
      required String displayName,
      Value<String?> givenName,
      Value<String?> additionalNames,
      Value<String?> familyName,
      Value<String?> birthFamilyName,
      required Sex sex,
      Value<String?> birthDateIso,
      Value<bool> birthDateApproximate,
      Value<int?> birthLunarYear,
      Value<int?> birthLunarMonth,
      Value<int?> birthLunarDay,
      Value<bool> birthLunarIsLeapMonth,
      Value<String?> deathDateIso,
      Value<bool> deathDateApproximate,
      Value<int?> deathLunarYear,
      Value<int?> deathLunarMonth,
      Value<int?> deathLunarDay,
      Value<bool> deathLunarIsLeapMonth,
      Value<String?> birthPlace,
      Value<String?> deathPlace,
      Value<String?> biography,
      Value<String?> profileMediaRef,
      Value<int> rowid,
    });
typedef $$PersonsTableUpdateCompanionBuilder =
    PersonsCompanion Function({
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String> id,
      Value<String> familyId,
      Value<String> displayName,
      Value<String?> givenName,
      Value<String?> additionalNames,
      Value<String?> familyName,
      Value<String?> birthFamilyName,
      Value<Sex> sex,
      Value<String?> birthDateIso,
      Value<bool> birthDateApproximate,
      Value<int?> birthLunarYear,
      Value<int?> birthLunarMonth,
      Value<int?> birthLunarDay,
      Value<bool> birthLunarIsLeapMonth,
      Value<String?> deathDateIso,
      Value<bool> deathDateApproximate,
      Value<int?> deathLunarYear,
      Value<int?> deathLunarMonth,
      Value<int?> deathLunarDay,
      Value<bool> deathLunarIsLeapMonth,
      Value<String?> birthPlace,
      Value<String?> deathPlace,
      Value<String?> biography,
      Value<String?> profileMediaRef,
      Value<int> rowid,
    });

final class $$PersonsTableReferences
    extends BaseReferences<_$AppDatabase, $PersonsTable, Person> {
  $$PersonsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FamiliesTable _familyIdTable(_$AppDatabase db) =>
      db.families.createAlias('persons__family_id__families__id');

  $$FamiliesTableProcessedTableManager get familyId {
    final $_column = $_itemColumn<String>('family_id')!;

    final manager = $$FamiliesTableTableManager(
      $_db,
      $_db.families,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_familyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$RelationshipsTable, List<Relationship>>
  _relationshipsAsPersonATable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.relationships,
        aliasName: 'persons__id__relationships__person_a_id',
      );

  $$RelationshipsTableProcessedTableManager get relationshipsAsPersonA {
    final manager = $$RelationshipsTableTableManager(
      $_db,
      $_db.relationships,
    ).filter((f) => f.personAId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _relationshipsAsPersonATable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RelationshipsTable, List<Relationship>>
  _relationshipsAsPersonBTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.relationships,
        aliasName: 'persons__id__relationships__person_b_id',
      );

  $$RelationshipsTableProcessedTableManager get relationshipsAsPersonB {
    final manager = $$RelationshipsTableTableManager(
      $_db,
      $_db.relationships,
    ).filter((f) => f.personBId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _relationshipsAsPersonBTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PersonsTableFilterComposer
    extends Composer<_$AppDatabase, $PersonsTable> {
  $$PersonsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get givenName => $composableBuilder(
    column: $table.givenName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get additionalNames => $composableBuilder(
    column: $table.additionalNames,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get familyName => $composableBuilder(
    column: $table.familyName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get birthFamilyName => $composableBuilder(
    column: $table.birthFamilyName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Sex, Sex, String> get sex =>
      $composableBuilder(
        column: $table.sex,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get birthDateIso => $composableBuilder(
    column: $table.birthDateIso,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get birthDateApproximate => $composableBuilder(
    column: $table.birthDateApproximate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get birthLunarYear => $composableBuilder(
    column: $table.birthLunarYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get birthLunarMonth => $composableBuilder(
    column: $table.birthLunarMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get birthLunarDay => $composableBuilder(
    column: $table.birthLunarDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get birthLunarIsLeapMonth => $composableBuilder(
    column: $table.birthLunarIsLeapMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deathDateIso => $composableBuilder(
    column: $table.deathDateIso,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deathDateApproximate => $composableBuilder(
    column: $table.deathDateApproximate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deathLunarYear => $composableBuilder(
    column: $table.deathLunarYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deathLunarMonth => $composableBuilder(
    column: $table.deathLunarMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deathLunarDay => $composableBuilder(
    column: $table.deathLunarDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deathLunarIsLeapMonth => $composableBuilder(
    column: $table.deathLunarIsLeapMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get birthPlace => $composableBuilder(
    column: $table.birthPlace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deathPlace => $composableBuilder(
    column: $table.deathPlace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get biography => $composableBuilder(
    column: $table.biography,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileMediaRef => $composableBuilder(
    column: $table.profileMediaRef,
    builder: (column) => ColumnFilters(column),
  );

  $$FamiliesTableFilterComposer get familyId {
    final $$FamiliesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.families,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamiliesTableFilterComposer(
            $db: $db,
            $table: $db.families,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> relationshipsAsPersonA(
    Expression<bool> Function($$RelationshipsTableFilterComposer f) f,
  ) {
    final $$RelationshipsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.relationships,
      getReferencedColumn: (t) => t.personAId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RelationshipsTableFilterComposer(
            $db: $db,
            $table: $db.relationships,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> relationshipsAsPersonB(
    Expression<bool> Function($$RelationshipsTableFilterComposer f) f,
  ) {
    final $$RelationshipsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.relationships,
      getReferencedColumn: (t) => t.personBId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RelationshipsTableFilterComposer(
            $db: $db,
            $table: $db.relationships,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PersonsTableOrderingComposer
    extends Composer<_$AppDatabase, $PersonsTable> {
  $$PersonsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get givenName => $composableBuilder(
    column: $table.givenName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get additionalNames => $composableBuilder(
    column: $table.additionalNames,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get familyName => $composableBuilder(
    column: $table.familyName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get birthFamilyName => $composableBuilder(
    column: $table.birthFamilyName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get birthDateIso => $composableBuilder(
    column: $table.birthDateIso,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get birthDateApproximate => $composableBuilder(
    column: $table.birthDateApproximate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get birthLunarYear => $composableBuilder(
    column: $table.birthLunarYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get birthLunarMonth => $composableBuilder(
    column: $table.birthLunarMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get birthLunarDay => $composableBuilder(
    column: $table.birthLunarDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get birthLunarIsLeapMonth => $composableBuilder(
    column: $table.birthLunarIsLeapMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deathDateIso => $composableBuilder(
    column: $table.deathDateIso,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deathDateApproximate => $composableBuilder(
    column: $table.deathDateApproximate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deathLunarYear => $composableBuilder(
    column: $table.deathLunarYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deathLunarMonth => $composableBuilder(
    column: $table.deathLunarMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deathLunarDay => $composableBuilder(
    column: $table.deathLunarDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deathLunarIsLeapMonth => $composableBuilder(
    column: $table.deathLunarIsLeapMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get birthPlace => $composableBuilder(
    column: $table.birthPlace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deathPlace => $composableBuilder(
    column: $table.deathPlace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get biography => $composableBuilder(
    column: $table.biography,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileMediaRef => $composableBuilder(
    column: $table.profileMediaRef,
    builder: (column) => ColumnOrderings(column),
  );

  $$FamiliesTableOrderingComposer get familyId {
    final $$FamiliesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.families,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamiliesTableOrderingComposer(
            $db: $db,
            $table: $db.families,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PersonsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PersonsTable> {
  $$PersonsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get givenName =>
      $composableBuilder(column: $table.givenName, builder: (column) => column);

  GeneratedColumn<String> get additionalNames => $composableBuilder(
    column: $table.additionalNames,
    builder: (column) => column,
  );

  GeneratedColumn<String> get familyName => $composableBuilder(
    column: $table.familyName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get birthFamilyName => $composableBuilder(
    column: $table.birthFamilyName,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Sex, String> get sex =>
      $composableBuilder(column: $table.sex, builder: (column) => column);

  GeneratedColumn<String> get birthDateIso => $composableBuilder(
    column: $table.birthDateIso,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get birthDateApproximate => $composableBuilder(
    column: $table.birthDateApproximate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get birthLunarYear => $composableBuilder(
    column: $table.birthLunarYear,
    builder: (column) => column,
  );

  GeneratedColumn<int> get birthLunarMonth => $composableBuilder(
    column: $table.birthLunarMonth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get birthLunarDay => $composableBuilder(
    column: $table.birthLunarDay,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get birthLunarIsLeapMonth => $composableBuilder(
    column: $table.birthLunarIsLeapMonth,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deathDateIso => $composableBuilder(
    column: $table.deathDateIso,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deathDateApproximate => $composableBuilder(
    column: $table.deathDateApproximate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deathLunarYear => $composableBuilder(
    column: $table.deathLunarYear,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deathLunarMonth => $composableBuilder(
    column: $table.deathLunarMonth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deathLunarDay => $composableBuilder(
    column: $table.deathLunarDay,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deathLunarIsLeapMonth => $composableBuilder(
    column: $table.deathLunarIsLeapMonth,
    builder: (column) => column,
  );

  GeneratedColumn<String> get birthPlace => $composableBuilder(
    column: $table.birthPlace,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deathPlace => $composableBuilder(
    column: $table.deathPlace,
    builder: (column) => column,
  );

  GeneratedColumn<String> get biography =>
      $composableBuilder(column: $table.biography, builder: (column) => column);

  GeneratedColumn<String> get profileMediaRef => $composableBuilder(
    column: $table.profileMediaRef,
    builder: (column) => column,
  );

  $$FamiliesTableAnnotationComposer get familyId {
    final $$FamiliesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.families,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamiliesTableAnnotationComposer(
            $db: $db,
            $table: $db.families,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> relationshipsAsPersonA<T extends Object>(
    Expression<T> Function($$RelationshipsTableAnnotationComposer a) f,
  ) {
    final $$RelationshipsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.relationships,
      getReferencedColumn: (t) => t.personAId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RelationshipsTableAnnotationComposer(
            $db: $db,
            $table: $db.relationships,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> relationshipsAsPersonB<T extends Object>(
    Expression<T> Function($$RelationshipsTableAnnotationComposer a) f,
  ) {
    final $$RelationshipsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.relationships,
      getReferencedColumn: (t) => t.personBId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RelationshipsTableAnnotationComposer(
            $db: $db,
            $table: $db.relationships,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PersonsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PersonsTable,
          Person,
          $$PersonsTableFilterComposer,
          $$PersonsTableOrderingComposer,
          $$PersonsTableAnnotationComposer,
          $$PersonsTableCreateCompanionBuilder,
          $$PersonsTableUpdateCompanionBuilder,
          (Person, $$PersonsTableReferences),
          Person,
          PrefetchHooks Function({
            bool familyId,
            bool relationshipsAsPersonA,
            bool relationshipsAsPersonB,
          })
        > {
  $$PersonsTableTableManager(_$AppDatabase db, $PersonsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PersonsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PersonsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PersonsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> familyId = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> givenName = const Value.absent(),
                Value<String?> additionalNames = const Value.absent(),
                Value<String?> familyName = const Value.absent(),
                Value<String?> birthFamilyName = const Value.absent(),
                Value<Sex> sex = const Value.absent(),
                Value<String?> birthDateIso = const Value.absent(),
                Value<bool> birthDateApproximate = const Value.absent(),
                Value<int?> birthLunarYear = const Value.absent(),
                Value<int?> birthLunarMonth = const Value.absent(),
                Value<int?> birthLunarDay = const Value.absent(),
                Value<bool> birthLunarIsLeapMonth = const Value.absent(),
                Value<String?> deathDateIso = const Value.absent(),
                Value<bool> deathDateApproximate = const Value.absent(),
                Value<int?> deathLunarYear = const Value.absent(),
                Value<int?> deathLunarMonth = const Value.absent(),
                Value<int?> deathLunarDay = const Value.absent(),
                Value<bool> deathLunarIsLeapMonth = const Value.absent(),
                Value<String?> birthPlace = const Value.absent(),
                Value<String?> deathPlace = const Value.absent(),
                Value<String?> biography = const Value.absent(),
                Value<String?> profileMediaRef = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonsCompanion(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                familyId: familyId,
                displayName: displayName,
                givenName: givenName,
                additionalNames: additionalNames,
                familyName: familyName,
                birthFamilyName: birthFamilyName,
                sex: sex,
                birthDateIso: birthDateIso,
                birthDateApproximate: birthDateApproximate,
                birthLunarYear: birthLunarYear,
                birthLunarMonth: birthLunarMonth,
                birthLunarDay: birthLunarDay,
                birthLunarIsLeapMonth: birthLunarIsLeapMonth,
                deathDateIso: deathDateIso,
                deathDateApproximate: deathDateApproximate,
                deathLunarYear: deathLunarYear,
                deathLunarMonth: deathLunarMonth,
                deathLunarDay: deathLunarDay,
                deathLunarIsLeapMonth: deathLunarIsLeapMonth,
                birthPlace: birthPlace,
                deathPlace: deathPlace,
                biography: biography,
                profileMediaRef: profileMediaRef,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                required String id,
                required String familyId,
                required String displayName,
                Value<String?> givenName = const Value.absent(),
                Value<String?> additionalNames = const Value.absent(),
                Value<String?> familyName = const Value.absent(),
                Value<String?> birthFamilyName = const Value.absent(),
                required Sex sex,
                Value<String?> birthDateIso = const Value.absent(),
                Value<bool> birthDateApproximate = const Value.absent(),
                Value<int?> birthLunarYear = const Value.absent(),
                Value<int?> birthLunarMonth = const Value.absent(),
                Value<int?> birthLunarDay = const Value.absent(),
                Value<bool> birthLunarIsLeapMonth = const Value.absent(),
                Value<String?> deathDateIso = const Value.absent(),
                Value<bool> deathDateApproximate = const Value.absent(),
                Value<int?> deathLunarYear = const Value.absent(),
                Value<int?> deathLunarMonth = const Value.absent(),
                Value<int?> deathLunarDay = const Value.absent(),
                Value<bool> deathLunarIsLeapMonth = const Value.absent(),
                Value<String?> birthPlace = const Value.absent(),
                Value<String?> deathPlace = const Value.absent(),
                Value<String?> biography = const Value.absent(),
                Value<String?> profileMediaRef = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonsCompanion.insert(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                familyId: familyId,
                displayName: displayName,
                givenName: givenName,
                additionalNames: additionalNames,
                familyName: familyName,
                birthFamilyName: birthFamilyName,
                sex: sex,
                birthDateIso: birthDateIso,
                birthDateApproximate: birthDateApproximate,
                birthLunarYear: birthLunarYear,
                birthLunarMonth: birthLunarMonth,
                birthLunarDay: birthLunarDay,
                birthLunarIsLeapMonth: birthLunarIsLeapMonth,
                deathDateIso: deathDateIso,
                deathDateApproximate: deathDateApproximate,
                deathLunarYear: deathLunarYear,
                deathLunarMonth: deathLunarMonth,
                deathLunarDay: deathLunarDay,
                deathLunarIsLeapMonth: deathLunarIsLeapMonth,
                birthPlace: birthPlace,
                deathPlace: deathPlace,
                biography: biography,
                profileMediaRef: profileMediaRef,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PersonsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                familyId = false,
                relationshipsAsPersonA = false,
                relationshipsAsPersonB = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (relationshipsAsPersonA) db.relationships,
                    if (relationshipsAsPersonB) db.relationships,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (familyId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.familyId,
                                    referencedTable: $$PersonsTableReferences
                                        ._familyIdTable(db),
                                    referencedColumn: $$PersonsTableReferences
                                        ._familyIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (relationshipsAsPersonA)
                        await $_getPrefetchedData<
                          Person,
                          $PersonsTable,
                          Relationship
                        >(
                          currentTable: table,
                          referencedTable: $$PersonsTableReferences
                              ._relationshipsAsPersonATable(db),
                          managerFromTypedResult: (p0) =>
                              $$PersonsTableReferences(
                                db,
                                table,
                                p0,
                              ).relationshipsAsPersonA,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.personAId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (relationshipsAsPersonB)
                        await $_getPrefetchedData<
                          Person,
                          $PersonsTable,
                          Relationship
                        >(
                          currentTable: table,
                          referencedTable: $$PersonsTableReferences
                              ._relationshipsAsPersonBTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PersonsTableReferences(
                                db,
                                table,
                                p0,
                              ).relationshipsAsPersonB,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.personBId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PersonsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PersonsTable,
      Person,
      $$PersonsTableFilterComposer,
      $$PersonsTableOrderingComposer,
      $$PersonsTableAnnotationComposer,
      $$PersonsTableCreateCompanionBuilder,
      $$PersonsTableUpdateCompanionBuilder,
      (Person, $$PersonsTableReferences),
      Person,
      PrefetchHooks Function({
        bool familyId,
        bool relationshipsAsPersonA,
        bool relationshipsAsPersonB,
      })
    >;
typedef $$RelationshipsTableCreateCompanionBuilder =
    RelationshipsCompanion Function({
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      required String id,
      required String familyId,
      required RelationshipType type,
      required String personAId,
      required String personBId,
      Value<int> rowid,
    });
typedef $$RelationshipsTableUpdateCompanionBuilder =
    RelationshipsCompanion Function({
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String> id,
      Value<String> familyId,
      Value<RelationshipType> type,
      Value<String> personAId,
      Value<String> personBId,
      Value<int> rowid,
    });

final class $$RelationshipsTableReferences
    extends BaseReferences<_$AppDatabase, $RelationshipsTable, Relationship> {
  $$RelationshipsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FamiliesTable _familyIdTable(_$AppDatabase db) =>
      db.families.createAlias('relationships__family_id__families__id');

  $$FamiliesTableProcessedTableManager get familyId {
    final $_column = $_itemColumn<String>('family_id')!;

    final manager = $$FamiliesTableTableManager(
      $_db,
      $_db.families,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_familyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PersonsTable _personAIdTable(_$AppDatabase db) =>
      db.persons.createAlias('relationships__person_a_id__persons__id');

  $$PersonsTableProcessedTableManager get personAId {
    final $_column = $_itemColumn<String>('person_a_id')!;

    final manager = $$PersonsTableTableManager(
      $_db,
      $_db.persons,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_personAIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PersonsTable _personBIdTable(_$AppDatabase db) =>
      db.persons.createAlias('relationships__person_b_id__persons__id');

  $$PersonsTableProcessedTableManager get personBId {
    final $_column = $_itemColumn<String>('person_b_id')!;

    final manager = $$PersonsTableTableManager(
      $_db,
      $_db.persons,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_personBIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RelationshipsTableFilterComposer
    extends Composer<_$AppDatabase, $RelationshipsTable> {
  $$RelationshipsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<RelationshipType, RelationshipType, String>
  get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  $$FamiliesTableFilterComposer get familyId {
    final $$FamiliesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.families,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamiliesTableFilterComposer(
            $db: $db,
            $table: $db.families,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PersonsTableFilterComposer get personAId {
    final $$PersonsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personAId,
      referencedTable: $db.persons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonsTableFilterComposer(
            $db: $db,
            $table: $db.persons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PersonsTableFilterComposer get personBId {
    final $$PersonsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personBId,
      referencedTable: $db.persons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonsTableFilterComposer(
            $db: $db,
            $table: $db.persons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RelationshipsTableOrderingComposer
    extends Composer<_$AppDatabase, $RelationshipsTable> {
  $$RelationshipsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  $$FamiliesTableOrderingComposer get familyId {
    final $$FamiliesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.families,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamiliesTableOrderingComposer(
            $db: $db,
            $table: $db.families,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PersonsTableOrderingComposer get personAId {
    final $$PersonsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personAId,
      referencedTable: $db.persons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonsTableOrderingComposer(
            $db: $db,
            $table: $db.persons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PersonsTableOrderingComposer get personBId {
    final $$PersonsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personBId,
      referencedTable: $db.persons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonsTableOrderingComposer(
            $db: $db,
            $table: $db.persons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RelationshipsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RelationshipsTable> {
  $$RelationshipsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RelationshipType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  $$FamiliesTableAnnotationComposer get familyId {
    final $$FamiliesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.families,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamiliesTableAnnotationComposer(
            $db: $db,
            $table: $db.families,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PersonsTableAnnotationComposer get personAId {
    final $$PersonsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personAId,
      referencedTable: $db.persons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonsTableAnnotationComposer(
            $db: $db,
            $table: $db.persons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PersonsTableAnnotationComposer get personBId {
    final $$PersonsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personBId,
      referencedTable: $db.persons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonsTableAnnotationComposer(
            $db: $db,
            $table: $db.persons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RelationshipsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RelationshipsTable,
          Relationship,
          $$RelationshipsTableFilterComposer,
          $$RelationshipsTableOrderingComposer,
          $$RelationshipsTableAnnotationComposer,
          $$RelationshipsTableCreateCompanionBuilder,
          $$RelationshipsTableUpdateCompanionBuilder,
          (Relationship, $$RelationshipsTableReferences),
          Relationship,
          PrefetchHooks Function({
            bool familyId,
            bool personAId,
            bool personBId,
          })
        > {
  $$RelationshipsTableTableManager(_$AppDatabase db, $RelationshipsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RelationshipsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RelationshipsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RelationshipsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> familyId = const Value.absent(),
                Value<RelationshipType> type = const Value.absent(),
                Value<String> personAId = const Value.absent(),
                Value<String> personBId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RelationshipsCompanion(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                familyId: familyId,
                type: type,
                personAId: personAId,
                personBId: personBId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                required String id,
                required String familyId,
                required RelationshipType type,
                required String personAId,
                required String personBId,
                Value<int> rowid = const Value.absent(),
              }) => RelationshipsCompanion.insert(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                familyId: familyId,
                type: type,
                personAId: personAId,
                personBId: personBId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RelationshipsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({familyId = false, personAId = false, personBId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (familyId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.familyId,
                                    referencedTable:
                                        $$RelationshipsTableReferences
                                            ._familyIdTable(db),
                                    referencedColumn:
                                        $$RelationshipsTableReferences
                                            ._familyIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (personAId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.personAId,
                                    referencedTable:
                                        $$RelationshipsTableReferences
                                            ._personAIdTable(db),
                                    referencedColumn:
                                        $$RelationshipsTableReferences
                                            ._personAIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (personBId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.personBId,
                                    referencedTable:
                                        $$RelationshipsTableReferences
                                            ._personBIdTable(db),
                                    referencedColumn:
                                        $$RelationshipsTableReferences
                                            ._personBIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$RelationshipsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RelationshipsTable,
      Relationship,
      $$RelationshipsTableFilterComposer,
      $$RelationshipsTableOrderingComposer,
      $$RelationshipsTableAnnotationComposer,
      $$RelationshipsTableCreateCompanionBuilder,
      $$RelationshipsTableUpdateCompanionBuilder,
      (Relationship, $$RelationshipsTableReferences),
      Relationship,
      PrefetchHooks Function({bool familyId, bool personAId, bool personBId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FamiliesTableTableManager get families =>
      $$FamiliesTableTableManager(_db, _db.families);
  $$PersonsTableTableManager get persons =>
      $$PersonsTableTableManager(_db, _db.persons);
  $$RelationshipsTableTableManager get relationships =>
      $$RelationshipsTableTableManager(_db, _db.relationships);
}
