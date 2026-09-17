// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalHomesTable extends LocalHomes
    with TableInfo<$LocalHomesTable, LocalHome> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalHomesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('USD'),
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    icon,
    currency,
    createdAt,
    createdBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_homes';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalHome> instance, {
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
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalHome map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalHome(
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
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
    );
  }

  @override
  $LocalHomesTable createAlias(String alias) {
    return $LocalHomesTable(attachedDatabase, alias);
  }
}

class LocalHome extends DataClass implements Insertable<LocalHome> {
  final String id;
  final String name;
  final String? description;
  final String? icon;
  final String currency;
  final DateTime createdAt;
  final String createdBy;
  const LocalHome({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    required this.currency,
    required this.createdAt,
    required this.createdBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    map['currency'] = Variable<String>(currency);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['created_by'] = Variable<String>(createdBy);
    return map;
  }

  LocalHomesCompanion toCompanion(bool nullToAbsent) {
    return LocalHomesCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      currency: Value(currency),
      createdAt: Value(createdAt),
      createdBy: Value(createdBy),
    );
  }

  factory LocalHome.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalHome(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      icon: serializer.fromJson<String?>(json['icon']),
      currency: serializer.fromJson<String>(json['currency']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'icon': serializer.toJson<String?>(icon),
      'currency': serializer.toJson<String>(currency),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'createdBy': serializer.toJson<String>(createdBy),
    };
  }

  LocalHome copyWith({
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    Value<String?> icon = const Value.absent(),
    String? currency,
    DateTime? createdAt,
    String? createdBy,
  }) => LocalHome(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    icon: icon.present ? icon.value : this.icon,
    currency: currency ?? this.currency,
    createdAt: createdAt ?? this.createdAt,
    createdBy: createdBy ?? this.createdBy,
  );
  LocalHome copyWithCompanion(LocalHomesCompanion data) {
    return LocalHome(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      icon: data.icon.present ? data.icon.value : this.icon,
      currency: data.currency.present ? data.currency.value : this.currency,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalHome(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('icon: $icon, ')
          ..write('currency: $currency, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdBy: $createdBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, description, icon, currency, createdAt, createdBy);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalHome &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.icon == this.icon &&
          other.currency == this.currency &&
          other.createdAt == this.createdAt &&
          other.createdBy == this.createdBy);
}

class LocalHomesCompanion extends UpdateCompanion<LocalHome> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String?> icon;
  final Value<String> currency;
  final Value<DateTime> createdAt;
  final Value<String> createdBy;
  final Value<int> rowid;
  const LocalHomesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.icon = const Value.absent(),
    this.currency = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalHomesCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    this.icon = const Value.absent(),
    this.currency = const Value.absent(),
    required DateTime createdAt,
    required String createdBy,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       createdBy = Value(createdBy);
  static Insertable<LocalHome> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? icon,
    Expression<String>? currency,
    Expression<DateTime>? createdAt,
    Expression<String>? createdBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (icon != null) 'icon': icon,
      if (currency != null) 'currency': currency,
      if (createdAt != null) 'created_at': createdAt,
      if (createdBy != null) 'created_by': createdBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalHomesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<String?>? icon,
    Value<String>? currency,
    Value<DateTime>? createdAt,
    Value<String>? createdBy,
    Value<int>? rowid,
  }) {
    return LocalHomesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
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
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalHomesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('icon: $icon, ')
          ..write('currency: $currency, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalListsTable extends LocalLists
    with TableInfo<$LocalListsTable, LocalList> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _homeIdMeta = const VerificationMeta('homeId');
  @override
  late final GeneratedColumn<String> homeId = GeneratedColumn<String>(
    'home_id',
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
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    homeId,
    name,
    isArchived,
    createdAt,
    createdBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_lists';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalList> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('home_id')) {
      context.handle(
        _homeIdMeta,
        homeId.isAcceptableOrUnknown(data['home_id']!, _homeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_homeIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalList map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalList(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      homeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}home_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
    );
  }

  @override
  $LocalListsTable createAlias(String alias) {
    return $LocalListsTable(attachedDatabase, alias);
  }
}

class LocalList extends DataClass implements Insertable<LocalList> {
  final String id;
  final String homeId;
  final String name;
  final bool isArchived;
  final DateTime createdAt;
  final String createdBy;
  const LocalList({
    required this.id,
    required this.homeId,
    required this.name,
    required this.isArchived,
    required this.createdAt,
    required this.createdBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['home_id'] = Variable<String>(homeId);
    map['name'] = Variable<String>(name);
    map['is_archived'] = Variable<bool>(isArchived);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['created_by'] = Variable<String>(createdBy);
    return map;
  }

  LocalListsCompanion toCompanion(bool nullToAbsent) {
    return LocalListsCompanion(
      id: Value(id),
      homeId: Value(homeId),
      name: Value(name),
      isArchived: Value(isArchived),
      createdAt: Value(createdAt),
      createdBy: Value(createdBy),
    );
  }

  factory LocalList.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalList(
      id: serializer.fromJson<String>(json['id']),
      homeId: serializer.fromJson<String>(json['homeId']),
      name: serializer.fromJson<String>(json['name']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'homeId': serializer.toJson<String>(homeId),
      'name': serializer.toJson<String>(name),
      'isArchived': serializer.toJson<bool>(isArchived),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'createdBy': serializer.toJson<String>(createdBy),
    };
  }

  LocalList copyWith({
    String? id,
    String? homeId,
    String? name,
    bool? isArchived,
    DateTime? createdAt,
    String? createdBy,
  }) => LocalList(
    id: id ?? this.id,
    homeId: homeId ?? this.homeId,
    name: name ?? this.name,
    isArchived: isArchived ?? this.isArchived,
    createdAt: createdAt ?? this.createdAt,
    createdBy: createdBy ?? this.createdBy,
  );
  LocalList copyWithCompanion(LocalListsCompanion data) {
    return LocalList(
      id: data.id.present ? data.id.value : this.id,
      homeId: data.homeId.present ? data.homeId.value : this.homeId,
      name: data.name.present ? data.name.value : this.name,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalList(')
          ..write('id: $id, ')
          ..write('homeId: $homeId, ')
          ..write('name: $name, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdBy: $createdBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, homeId, name, isArchived, createdAt, createdBy);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalList &&
          other.id == this.id &&
          other.homeId == this.homeId &&
          other.name == this.name &&
          other.isArchived == this.isArchived &&
          other.createdAt == this.createdAt &&
          other.createdBy == this.createdBy);
}

class LocalListsCompanion extends UpdateCompanion<LocalList> {
  final Value<String> id;
  final Value<String> homeId;
  final Value<String> name;
  final Value<bool> isArchived;
  final Value<DateTime> createdAt;
  final Value<String> createdBy;
  final Value<int> rowid;
  const LocalListsCompanion({
    this.id = const Value.absent(),
    this.homeId = const Value.absent(),
    this.name = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalListsCompanion.insert({
    required String id,
    required String homeId,
    required String name,
    this.isArchived = const Value.absent(),
    required DateTime createdAt,
    required String createdBy,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       homeId = Value(homeId),
       name = Value(name),
       createdAt = Value(createdAt),
       createdBy = Value(createdBy);
  static Insertable<LocalList> custom({
    Expression<String>? id,
    Expression<String>? homeId,
    Expression<String>? name,
    Expression<bool>? isArchived,
    Expression<DateTime>? createdAt,
    Expression<String>? createdBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (homeId != null) 'home_id': homeId,
      if (name != null) 'name': name,
      if (isArchived != null) 'is_archived': isArchived,
      if (createdAt != null) 'created_at': createdAt,
      if (createdBy != null) 'created_by': createdBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalListsCompanion copyWith({
    Value<String>? id,
    Value<String>? homeId,
    Value<String>? name,
    Value<bool>? isArchived,
    Value<DateTime>? createdAt,
    Value<String>? createdBy,
    Value<int>? rowid,
  }) {
    return LocalListsCompanion(
      id: id ?? this.id,
      homeId: homeId ?? this.homeId,
      name: name ?? this.name,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (homeId.present) {
      map['home_id'] = Variable<String>(homeId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalListsCompanion(')
          ..write('id: $id, ')
          ..write('homeId: $homeId, ')
          ..write('name: $name, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalListItemsTable extends LocalListItems
    with TableInfo<$LocalListItemsTable, LocalListItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalListItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _homeIdMeta = const VerificationMeta('homeId');
  @override
  late final GeneratedColumn<String> homeId = GeneratedColumn<String>(
    'home_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
    'list_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCompletedMeta = const VerificationMeta(
    'isCompleted',
  );
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedByMeta = const VerificationMeta(
    'completedBy',
  );
  @override
  late final GeneratedColumn<String> completedBy = GeneratedColumn<String>(
    'completed_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    homeId,
    listId,
    title,
    notes,
    isCompleted,
    completedAt,
    completedBy,
    createdAt,
    createdBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_list_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalListItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('home_id')) {
      context.handle(
        _homeIdMeta,
        homeId.isAcceptableOrUnknown(data['home_id']!, _homeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_homeIdMeta);
    }
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    } else if (isInserting) {
      context.missing(_listIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('is_completed')) {
      context.handle(
        _isCompletedMeta,
        isCompleted.isAcceptableOrUnknown(
          data['is_completed']!,
          _isCompletedMeta,
        ),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('completed_by')) {
      context.handle(
        _completedByMeta,
        completedBy.isAcceptableOrUnknown(
          data['completed_by']!,
          _completedByMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalListItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalListItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      homeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}home_id'],
      )!,
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      isCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_completed'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      completedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
    );
  }

  @override
  $LocalListItemsTable createAlias(String alias) {
    return $LocalListItemsTable(attachedDatabase, alias);
  }
}

class LocalListItem extends DataClass implements Insertable<LocalListItem> {
  final String id;
  final String homeId;
  final String listId;
  final String title;
  final String? notes;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? completedBy;
  final DateTime createdAt;
  final String createdBy;
  const LocalListItem({
    required this.id,
    required this.homeId,
    required this.listId,
    required this.title,
    this.notes,
    required this.isCompleted,
    this.completedAt,
    this.completedBy,
    required this.createdAt,
    required this.createdBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['home_id'] = Variable<String>(homeId);
    map['list_id'] = Variable<String>(listId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['is_completed'] = Variable<bool>(isCompleted);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || completedBy != null) {
      map['completed_by'] = Variable<String>(completedBy);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['created_by'] = Variable<String>(createdBy);
    return map;
  }

  LocalListItemsCompanion toCompanion(bool nullToAbsent) {
    return LocalListItemsCompanion(
      id: Value(id),
      homeId: Value(homeId),
      listId: Value(listId),
      title: Value(title),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      isCompleted: Value(isCompleted),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      completedBy: completedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(completedBy),
      createdAt: Value(createdAt),
      createdBy: Value(createdBy),
    );
  }

  factory LocalListItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalListItem(
      id: serializer.fromJson<String>(json['id']),
      homeId: serializer.fromJson<String>(json['homeId']),
      listId: serializer.fromJson<String>(json['listId']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String?>(json['notes']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      completedBy: serializer.fromJson<String?>(json['completedBy']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'homeId': serializer.toJson<String>(homeId),
      'listId': serializer.toJson<String>(listId),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String?>(notes),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'completedBy': serializer.toJson<String?>(completedBy),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'createdBy': serializer.toJson<String>(createdBy),
    };
  }

  LocalListItem copyWith({
    String? id,
    String? homeId,
    String? listId,
    String? title,
    Value<String?> notes = const Value.absent(),
    bool? isCompleted,
    Value<DateTime?> completedAt = const Value.absent(),
    Value<String?> completedBy = const Value.absent(),
    DateTime? createdAt,
    String? createdBy,
  }) => LocalListItem(
    id: id ?? this.id,
    homeId: homeId ?? this.homeId,
    listId: listId ?? this.listId,
    title: title ?? this.title,
    notes: notes.present ? notes.value : this.notes,
    isCompleted: isCompleted ?? this.isCompleted,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    completedBy: completedBy.present ? completedBy.value : this.completedBy,
    createdAt: createdAt ?? this.createdAt,
    createdBy: createdBy ?? this.createdBy,
  );
  LocalListItem copyWithCompanion(LocalListItemsCompanion data) {
    return LocalListItem(
      id: data.id.present ? data.id.value : this.id,
      homeId: data.homeId.present ? data.homeId.value : this.homeId,
      listId: data.listId.present ? data.listId.value : this.listId,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      isCompleted: data.isCompleted.present
          ? data.isCompleted.value
          : this.isCompleted,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      completedBy: data.completedBy.present
          ? data.completedBy.value
          : this.completedBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalListItem(')
          ..write('id: $id, ')
          ..write('homeId: $homeId, ')
          ..write('listId: $listId, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('completedAt: $completedAt, ')
          ..write('completedBy: $completedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdBy: $createdBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    homeId,
    listId,
    title,
    notes,
    isCompleted,
    completedAt,
    completedBy,
    createdAt,
    createdBy,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalListItem &&
          other.id == this.id &&
          other.homeId == this.homeId &&
          other.listId == this.listId &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.isCompleted == this.isCompleted &&
          other.completedAt == this.completedAt &&
          other.completedBy == this.completedBy &&
          other.createdAt == this.createdAt &&
          other.createdBy == this.createdBy);
}

class LocalListItemsCompanion extends UpdateCompanion<LocalListItem> {
  final Value<String> id;
  final Value<String> homeId;
  final Value<String> listId;
  final Value<String> title;
  final Value<String?> notes;
  final Value<bool> isCompleted;
  final Value<DateTime?> completedAt;
  final Value<String?> completedBy;
  final Value<DateTime> createdAt;
  final Value<String> createdBy;
  final Value<int> rowid;
  const LocalListItemsCompanion({
    this.id = const Value.absent(),
    this.homeId = const Value.absent(),
    this.listId = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.completedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalListItemsCompanion.insert({
    required String id,
    required String homeId,
    required String listId,
    required String title,
    this.notes = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.completedBy = const Value.absent(),
    required DateTime createdAt,
    required String createdBy,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       homeId = Value(homeId),
       listId = Value(listId),
       title = Value(title),
       createdAt = Value(createdAt),
       createdBy = Value(createdBy);
  static Insertable<LocalListItem> custom({
    Expression<String>? id,
    Expression<String>? homeId,
    Expression<String>? listId,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<bool>? isCompleted,
    Expression<DateTime>? completedAt,
    Expression<String>? completedBy,
    Expression<DateTime>? createdAt,
    Expression<String>? createdBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (homeId != null) 'home_id': homeId,
      if (listId != null) 'list_id': listId,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (completedAt != null) 'completed_at': completedAt,
      if (completedBy != null) 'completed_by': completedBy,
      if (createdAt != null) 'created_at': createdAt,
      if (createdBy != null) 'created_by': createdBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalListItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? homeId,
    Value<String>? listId,
    Value<String>? title,
    Value<String?>? notes,
    Value<bool>? isCompleted,
    Value<DateTime?>? completedAt,
    Value<String?>? completedBy,
    Value<DateTime>? createdAt,
    Value<String>? createdBy,
    Value<int>? rowid,
  }) {
    return LocalListItemsCompanion(
      id: id ?? this.id,
      homeId: homeId ?? this.homeId,
      listId: listId ?? this.listId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (homeId.present) {
      map['home_id'] = Variable<String>(homeId.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (completedBy.present) {
      map['completed_by'] = Variable<String>(completedBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalListItemsCompanion(')
          ..write('id: $id, ')
          ..write('homeId: $homeId, ')
          ..write('listId: $listId, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('completedAt: $completedAt, ')
          ..write('completedBy: $completedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSubscriptionsTable extends LocalSubscriptions
    with TableInfo<$LocalSubscriptionsTable, LocalSubscription> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSubscriptionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _homeIdMeta = const VerificationMeta('homeId');
  @override
  late final GeneratedColumn<String> homeId = GeneratedColumn<String>(
    'home_id',
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
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('USD'),
  );
  static const VerificationMeta _billingCycleMeta = const VerificationMeta(
    'billingCycle',
  );
  @override
  late final GeneratedColumn<String> billingCycle = GeneratedColumn<String>(
    'billing_cycle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('monthly'),
  );
  static const VerificationMeta _nextBillingDateMeta = const VerificationMeta(
    'nextBillingDate',
  );
  @override
  late final GeneratedColumn<DateTime> nextBillingDate =
      GeneratedColumn<DateTime>(
        'next_billing_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isPrivateMeta = const VerificationMeta(
    'isPrivate',
  );
  @override
  late final GeneratedColumn<bool> isPrivate = GeneratedColumn<bool>(
    'is_private',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_private" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paidByMeta = const VerificationMeta('paidBy');
  @override
  late final GeneratedColumn<String> paidBy = GeneratedColumn<String>(
    'paid_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _financedThroughMeta = const VerificationMeta(
    'financedThrough',
  );
  @override
  late final GeneratedColumn<String> financedThrough = GeneratedColumn<String>(
    'financed_through',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalInstallmentsMeta = const VerificationMeta(
    'totalInstallments',
  );
  @override
  late final GeneratedColumn<int> totalInstallments = GeneratedColumn<int>(
    'total_installments',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paidInstallmentsMeta = const VerificationMeta(
    'paidInstallments',
  );
  @override
  late final GeneratedColumn<int> paidInstallments = GeneratedColumn<int>(
    'paid_installments',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    homeId,
    name,
    amount,
    currency,
    billingCycle,
    nextBillingDate,
    category,
    isActive,
    isPrivate,
    createdBy,
    createdAt,
    endDate,
    paidBy,
    financedThrough,
    totalInstallments,
    paidInstallments,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_subscriptions';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSubscription> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('home_id')) {
      context.handle(
        _homeIdMeta,
        homeId.isAcceptableOrUnknown(data['home_id']!, _homeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_homeIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('billing_cycle')) {
      context.handle(
        _billingCycleMeta,
        billingCycle.isAcceptableOrUnknown(
          data['billing_cycle']!,
          _billingCycleMeta,
        ),
      );
    }
    if (data.containsKey('next_billing_date')) {
      context.handle(
        _nextBillingDateMeta,
        nextBillingDate.isAcceptableOrUnknown(
          data['next_billing_date']!,
          _nextBillingDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextBillingDateMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('is_private')) {
      context.handle(
        _isPrivateMeta,
        isPrivate.isAcceptableOrUnknown(data['is_private']!, _isPrivateMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('paid_by')) {
      context.handle(
        _paidByMeta,
        paidBy.isAcceptableOrUnknown(data['paid_by']!, _paidByMeta),
      );
    }
    if (data.containsKey('financed_through')) {
      context.handle(
        _financedThroughMeta,
        financedThrough.isAcceptableOrUnknown(
          data['financed_through']!,
          _financedThroughMeta,
        ),
      );
    }
    if (data.containsKey('total_installments')) {
      context.handle(
        _totalInstallmentsMeta,
        totalInstallments.isAcceptableOrUnknown(
          data['total_installments']!,
          _totalInstallmentsMeta,
        ),
      );
    }
    if (data.containsKey('paid_installments')) {
      context.handle(
        _paidInstallmentsMeta,
        paidInstallments.isAcceptableOrUnknown(
          data['paid_installments']!,
          _paidInstallmentsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSubscription map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSubscription(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      homeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}home_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      billingCycle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}billing_cycle'],
      )!,
      nextBillingDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_billing_date'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      isPrivate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_private'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      ),
      paidBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}paid_by'],
      ),
      financedThrough: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}financed_through'],
      ),
      totalInstallments: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_installments'],
      ),
      paidInstallments: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paid_installments'],
      ),
    );
  }

  @override
  $LocalSubscriptionsTable createAlias(String alias) {
    return $LocalSubscriptionsTable(attachedDatabase, alias);
  }
}

class LocalSubscription extends DataClass
    implements Insertable<LocalSubscription> {
  final String id;
  final String homeId;
  final String name;
  final double amount;
  final String currency;
  final String billingCycle;
  final DateTime nextBillingDate;
  final String? category;
  final bool isActive;
  final bool isPrivate;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? endDate;
  final String? paidBy;
  final String? financedThrough;
  final int? totalInstallments;
  final int? paidInstallments;
  const LocalSubscription({
    required this.id,
    required this.homeId,
    required this.name,
    required this.amount,
    required this.currency,
    required this.billingCycle,
    required this.nextBillingDate,
    this.category,
    required this.isActive,
    required this.isPrivate,
    this.createdBy,
    required this.createdAt,
    this.endDate,
    this.paidBy,
    this.financedThrough,
    this.totalInstallments,
    this.paidInstallments,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['home_id'] = Variable<String>(homeId);
    map['name'] = Variable<String>(name);
    map['amount'] = Variable<double>(amount);
    map['currency'] = Variable<String>(currency);
    map['billing_cycle'] = Variable<String>(billingCycle);
    map['next_billing_date'] = Variable<DateTime>(nextBillingDate);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['is_private'] = Variable<bool>(isPrivate);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    if (!nullToAbsent || paidBy != null) {
      map['paid_by'] = Variable<String>(paidBy);
    }
    if (!nullToAbsent || financedThrough != null) {
      map['financed_through'] = Variable<String>(financedThrough);
    }
    if (!nullToAbsent || totalInstallments != null) {
      map['total_installments'] = Variable<int>(totalInstallments);
    }
    if (!nullToAbsent || paidInstallments != null) {
      map['paid_installments'] = Variable<int>(paidInstallments);
    }
    return map;
  }

  LocalSubscriptionsCompanion toCompanion(bool nullToAbsent) {
    return LocalSubscriptionsCompanion(
      id: Value(id),
      homeId: Value(homeId),
      name: Value(name),
      amount: Value(amount),
      currency: Value(currency),
      billingCycle: Value(billingCycle),
      nextBillingDate: Value(nextBillingDate),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      isActive: Value(isActive),
      isPrivate: Value(isPrivate),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      createdAt: Value(createdAt),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      paidBy: paidBy == null && nullToAbsent
          ? const Value.absent()
          : Value(paidBy),
      financedThrough: financedThrough == null && nullToAbsent
          ? const Value.absent()
          : Value(financedThrough),
      totalInstallments: totalInstallments == null && nullToAbsent
          ? const Value.absent()
          : Value(totalInstallments),
      paidInstallments: paidInstallments == null && nullToAbsent
          ? const Value.absent()
          : Value(paidInstallments),
    );
  }

  factory LocalSubscription.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSubscription(
      id: serializer.fromJson<String>(json['id']),
      homeId: serializer.fromJson<String>(json['homeId']),
      name: serializer.fromJson<String>(json['name']),
      amount: serializer.fromJson<double>(json['amount']),
      currency: serializer.fromJson<String>(json['currency']),
      billingCycle: serializer.fromJson<String>(json['billingCycle']),
      nextBillingDate: serializer.fromJson<DateTime>(json['nextBillingDate']),
      category: serializer.fromJson<String?>(json['category']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      isPrivate: serializer.fromJson<bool>(json['isPrivate']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      paidBy: serializer.fromJson<String?>(json['paidBy']),
      financedThrough: serializer.fromJson<String?>(json['financedThrough']),
      totalInstallments: serializer.fromJson<int?>(json['totalInstallments']),
      paidInstallments: serializer.fromJson<int?>(json['paidInstallments']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'homeId': serializer.toJson<String>(homeId),
      'name': serializer.toJson<String>(name),
      'amount': serializer.toJson<double>(amount),
      'currency': serializer.toJson<String>(currency),
      'billingCycle': serializer.toJson<String>(billingCycle),
      'nextBillingDate': serializer.toJson<DateTime>(nextBillingDate),
      'category': serializer.toJson<String?>(category),
      'isActive': serializer.toJson<bool>(isActive),
      'isPrivate': serializer.toJson<bool>(isPrivate),
      'createdBy': serializer.toJson<String?>(createdBy),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'paidBy': serializer.toJson<String?>(paidBy),
      'financedThrough': serializer.toJson<String?>(financedThrough),
      'totalInstallments': serializer.toJson<int?>(totalInstallments),
      'paidInstallments': serializer.toJson<int?>(paidInstallments),
    };
  }

  LocalSubscription copyWith({
    String? id,
    String? homeId,
    String? name,
    double? amount,
    String? currency,
    String? billingCycle,
    DateTime? nextBillingDate,
    Value<String?> category = const Value.absent(),
    bool? isActive,
    bool? isPrivate,
    Value<String?> createdBy = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> endDate = const Value.absent(),
    Value<String?> paidBy = const Value.absent(),
    Value<String?> financedThrough = const Value.absent(),
    Value<int?> totalInstallments = const Value.absent(),
    Value<int?> paidInstallments = const Value.absent(),
  }) => LocalSubscription(
    id: id ?? this.id,
    homeId: homeId ?? this.homeId,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    billingCycle: billingCycle ?? this.billingCycle,
    nextBillingDate: nextBillingDate ?? this.nextBillingDate,
    category: category.present ? category.value : this.category,
    isActive: isActive ?? this.isActive,
    isPrivate: isPrivate ?? this.isPrivate,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    endDate: endDate.present ? endDate.value : this.endDate,
    paidBy: paidBy.present ? paidBy.value : this.paidBy,
    financedThrough: financedThrough.present
        ? financedThrough.value
        : this.financedThrough,
    totalInstallments: totalInstallments.present
        ? totalInstallments.value
        : this.totalInstallments,
    paidInstallments: paidInstallments.present
        ? paidInstallments.value
        : this.paidInstallments,
  );
  LocalSubscription copyWithCompanion(LocalSubscriptionsCompanion data) {
    return LocalSubscription(
      id: data.id.present ? data.id.value : this.id,
      homeId: data.homeId.present ? data.homeId.value : this.homeId,
      name: data.name.present ? data.name.value : this.name,
      amount: data.amount.present ? data.amount.value : this.amount,
      currency: data.currency.present ? data.currency.value : this.currency,
      billingCycle: data.billingCycle.present
          ? data.billingCycle.value
          : this.billingCycle,
      nextBillingDate: data.nextBillingDate.present
          ? data.nextBillingDate.value
          : this.nextBillingDate,
      category: data.category.present ? data.category.value : this.category,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      isPrivate: data.isPrivate.present ? data.isPrivate.value : this.isPrivate,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      paidBy: data.paidBy.present ? data.paidBy.value : this.paidBy,
      financedThrough: data.financedThrough.present
          ? data.financedThrough.value
          : this.financedThrough,
      totalInstallments: data.totalInstallments.present
          ? data.totalInstallments.value
          : this.totalInstallments,
      paidInstallments: data.paidInstallments.present
          ? data.paidInstallments.value
          : this.paidInstallments,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSubscription(')
          ..write('id: $id, ')
          ..write('homeId: $homeId, ')
          ..write('name: $name, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('billingCycle: $billingCycle, ')
          ..write('nextBillingDate: $nextBillingDate, ')
          ..write('category: $category, ')
          ..write('isActive: $isActive, ')
          ..write('isPrivate: $isPrivate, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('endDate: $endDate, ')
          ..write('paidBy: $paidBy, ')
          ..write('financedThrough: $financedThrough, ')
          ..write('totalInstallments: $totalInstallments, ')
          ..write('paidInstallments: $paidInstallments')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    homeId,
    name,
    amount,
    currency,
    billingCycle,
    nextBillingDate,
    category,
    isActive,
    isPrivate,
    createdBy,
    createdAt,
    endDate,
    paidBy,
    financedThrough,
    totalInstallments,
    paidInstallments,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSubscription &&
          other.id == this.id &&
          other.homeId == this.homeId &&
          other.name == this.name &&
          other.amount == this.amount &&
          other.currency == this.currency &&
          other.billingCycle == this.billingCycle &&
          other.nextBillingDate == this.nextBillingDate &&
          other.category == this.category &&
          other.isActive == this.isActive &&
          other.isPrivate == this.isPrivate &&
          other.createdBy == this.createdBy &&
          other.createdAt == this.createdAt &&
          other.endDate == this.endDate &&
          other.paidBy == this.paidBy &&
          other.financedThrough == this.financedThrough &&
          other.totalInstallments == this.totalInstallments &&
          other.paidInstallments == this.paidInstallments);
}

class LocalSubscriptionsCompanion extends UpdateCompanion<LocalSubscription> {
  final Value<String> id;
  final Value<String> homeId;
  final Value<String> name;
  final Value<double> amount;
  final Value<String> currency;
  final Value<String> billingCycle;
  final Value<DateTime> nextBillingDate;
  final Value<String?> category;
  final Value<bool> isActive;
  final Value<bool> isPrivate;
  final Value<String?> createdBy;
  final Value<DateTime> createdAt;
  final Value<DateTime?> endDate;
  final Value<String?> paidBy;
  final Value<String?> financedThrough;
  final Value<int?> totalInstallments;
  final Value<int?> paidInstallments;
  final Value<int> rowid;
  const LocalSubscriptionsCompanion({
    this.id = const Value.absent(),
    this.homeId = const Value.absent(),
    this.name = const Value.absent(),
    this.amount = const Value.absent(),
    this.currency = const Value.absent(),
    this.billingCycle = const Value.absent(),
    this.nextBillingDate = const Value.absent(),
    this.category = const Value.absent(),
    this.isActive = const Value.absent(),
    this.isPrivate = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.endDate = const Value.absent(),
    this.paidBy = const Value.absent(),
    this.financedThrough = const Value.absent(),
    this.totalInstallments = const Value.absent(),
    this.paidInstallments = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSubscriptionsCompanion.insert({
    required String id,
    required String homeId,
    required String name,
    required double amount,
    this.currency = const Value.absent(),
    this.billingCycle = const Value.absent(),
    required DateTime nextBillingDate,
    this.category = const Value.absent(),
    this.isActive = const Value.absent(),
    this.isPrivate = const Value.absent(),
    this.createdBy = const Value.absent(),
    required DateTime createdAt,
    this.endDate = const Value.absent(),
    this.paidBy = const Value.absent(),
    this.financedThrough = const Value.absent(),
    this.totalInstallments = const Value.absent(),
    this.paidInstallments = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       homeId = Value(homeId),
       name = Value(name),
       amount = Value(amount),
       nextBillingDate = Value(nextBillingDate),
       createdAt = Value(createdAt);
  static Insertable<LocalSubscription> custom({
    Expression<String>? id,
    Expression<String>? homeId,
    Expression<String>? name,
    Expression<double>? amount,
    Expression<String>? currency,
    Expression<String>? billingCycle,
    Expression<DateTime>? nextBillingDate,
    Expression<String>? category,
    Expression<bool>? isActive,
    Expression<bool>? isPrivate,
    Expression<String>? createdBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? endDate,
    Expression<String>? paidBy,
    Expression<String>? financedThrough,
    Expression<int>? totalInstallments,
    Expression<int>? paidInstallments,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (homeId != null) 'home_id': homeId,
      if (name != null) 'name': name,
      if (amount != null) 'amount': amount,
      if (currency != null) 'currency': currency,
      if (billingCycle != null) 'billing_cycle': billingCycle,
      if (nextBillingDate != null) 'next_billing_date': nextBillingDate,
      if (category != null) 'category': category,
      if (isActive != null) 'is_active': isActive,
      if (isPrivate != null) 'is_private': isPrivate,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt,
      if (endDate != null) 'end_date': endDate,
      if (paidBy != null) 'paid_by': paidBy,
      if (financedThrough != null) 'financed_through': financedThrough,
      if (totalInstallments != null) 'total_installments': totalInstallments,
      if (paidInstallments != null) 'paid_installments': paidInstallments,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSubscriptionsCompanion copyWith({
    Value<String>? id,
    Value<String>? homeId,
    Value<String>? name,
    Value<double>? amount,
    Value<String>? currency,
    Value<String>? billingCycle,
    Value<DateTime>? nextBillingDate,
    Value<String?>? category,
    Value<bool>? isActive,
    Value<bool>? isPrivate,
    Value<String?>? createdBy,
    Value<DateTime>? createdAt,
    Value<DateTime?>? endDate,
    Value<String?>? paidBy,
    Value<String?>? financedThrough,
    Value<int?>? totalInstallments,
    Value<int?>? paidInstallments,
    Value<int>? rowid,
  }) {
    return LocalSubscriptionsCompanion(
      id: id ?? this.id,
      homeId: homeId ?? this.homeId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      billingCycle: billingCycle ?? this.billingCycle,
      nextBillingDate: nextBillingDate ?? this.nextBillingDate,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      isPrivate: isPrivate ?? this.isPrivate,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      endDate: endDate ?? this.endDate,
      paidBy: paidBy ?? this.paidBy,
      financedThrough: financedThrough ?? this.financedThrough,
      totalInstallments: totalInstallments ?? this.totalInstallments,
      paidInstallments: paidInstallments ?? this.paidInstallments,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (homeId.present) {
      map['home_id'] = Variable<String>(homeId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (billingCycle.present) {
      map['billing_cycle'] = Variable<String>(billingCycle.value);
    }
    if (nextBillingDate.present) {
      map['next_billing_date'] = Variable<DateTime>(nextBillingDate.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (isPrivate.present) {
      map['is_private'] = Variable<bool>(isPrivate.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (paidBy.present) {
      map['paid_by'] = Variable<String>(paidBy.value);
    }
    if (financedThrough.present) {
      map['financed_through'] = Variable<String>(financedThrough.value);
    }
    if (totalInstallments.present) {
      map['total_installments'] = Variable<int>(totalInstallments.value);
    }
    if (paidInstallments.present) {
      map['paid_installments'] = Variable<int>(paidInstallments.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSubscriptionsCompanion(')
          ..write('id: $id, ')
          ..write('homeId: $homeId, ')
          ..write('name: $name, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('billingCycle: $billingCycle, ')
          ..write('nextBillingDate: $nextBillingDate, ')
          ..write('category: $category, ')
          ..write('isActive: $isActive, ')
          ..write('isPrivate: $isPrivate, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('endDate: $endDate, ')
          ..write('paidBy: $paidBy, ')
          ..write('financedThrough: $financedThrough, ')
          ..write('totalInstallments: $totalInstallments, ')
          ..write('paidInstallments: $paidInstallments, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalExpensesTable extends LocalExpenses
    with TableInfo<$LocalExpensesTable, LocalExpense> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalExpensesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _homeIdMeta = const VerificationMeta('homeId');
  @override
  late final GeneratedColumn<String> homeId = GeneratedColumn<String>(
    'home_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('USD'),
  );
  static const VerificationMeta _paidByMeta = const VerificationMeta('paidBy');
  @override
  late final GeneratedColumn<String> paidBy = GeneratedColumn<String>(
    'paid_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _splitRatioMeta = const VerificationMeta(
    'splitRatio',
  );
  @override
  late final GeneratedColumn<double> splitRatio = GeneratedColumn<double>(
    'split_ratio',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.5),
  );
  static const VerificationMeta _expenseDateMeta = const VerificationMeta(
    'expenseDate',
  );
  @override
  late final GeneratedColumn<DateTime> expenseDate = GeneratedColumn<DateTime>(
    'expense_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paymentMethodMeta = const VerificationMeta(
    'paymentMethod',
  );
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
    'payment_method',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isTransferMeta = const VerificationMeta(
    'isTransfer',
  );
  @override
  late final GeneratedColumn<bool> isTransfer = GeneratedColumn<bool>(
    'is_transfer',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_transfer" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    homeId,
    title,
    amount,
    currency,
    paidBy,
    splitRatio,
    expenseDate,
    category,
    paymentMethod,
    isTransfer,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_expenses';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalExpense> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('home_id')) {
      context.handle(
        _homeIdMeta,
        homeId.isAcceptableOrUnknown(data['home_id']!, _homeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_homeIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('paid_by')) {
      context.handle(
        _paidByMeta,
        paidBy.isAcceptableOrUnknown(data['paid_by']!, _paidByMeta),
      );
    } else if (isInserting) {
      context.missing(_paidByMeta);
    }
    if (data.containsKey('split_ratio')) {
      context.handle(
        _splitRatioMeta,
        splitRatio.isAcceptableOrUnknown(data['split_ratio']!, _splitRatioMeta),
      );
    }
    if (data.containsKey('expense_date')) {
      context.handle(
        _expenseDateMeta,
        expenseDate.isAcceptableOrUnknown(
          data['expense_date']!,
          _expenseDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_expenseDateMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('payment_method')) {
      context.handle(
        _paymentMethodMeta,
        paymentMethod.isAcceptableOrUnknown(
          data['payment_method']!,
          _paymentMethodMeta,
        ),
      );
    }
    if (data.containsKey('is_transfer')) {
      context.handle(
        _isTransferMeta,
        isTransfer.isAcceptableOrUnknown(data['is_transfer']!, _isTransferMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalExpense map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalExpense(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      homeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}home_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      paidBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}paid_by'],
      )!,
      splitRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}split_ratio'],
      )!,
      expenseDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expense_date'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      paymentMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method'],
      ),
      isTransfer: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_transfer'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalExpensesTable createAlias(String alias) {
    return $LocalExpensesTable(attachedDatabase, alias);
  }
}

class LocalExpense extends DataClass implements Insertable<LocalExpense> {
  final String id;
  final String homeId;
  final String title;
  final double amount;
  final String currency;
  final String paidBy;
  final double splitRatio;
  final DateTime expenseDate;
  final String? category;
  final String? paymentMethod;
  final bool isTransfer;
  final DateTime createdAt;
  const LocalExpense({
    required this.id,
    required this.homeId,
    required this.title,
    required this.amount,
    required this.currency,
    required this.paidBy,
    required this.splitRatio,
    required this.expenseDate,
    this.category,
    this.paymentMethod,
    required this.isTransfer,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['home_id'] = Variable<String>(homeId);
    map['title'] = Variable<String>(title);
    map['amount'] = Variable<double>(amount);
    map['currency'] = Variable<String>(currency);
    map['paid_by'] = Variable<String>(paidBy);
    map['split_ratio'] = Variable<double>(splitRatio);
    map['expense_date'] = Variable<DateTime>(expenseDate);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || paymentMethod != null) {
      map['payment_method'] = Variable<String>(paymentMethod);
    }
    map['is_transfer'] = Variable<bool>(isTransfer);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalExpensesCompanion toCompanion(bool nullToAbsent) {
    return LocalExpensesCompanion(
      id: Value(id),
      homeId: Value(homeId),
      title: Value(title),
      amount: Value(amount),
      currency: Value(currency),
      paidBy: Value(paidBy),
      splitRatio: Value(splitRatio),
      expenseDate: Value(expenseDate),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      paymentMethod: paymentMethod == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentMethod),
      isTransfer: Value(isTransfer),
      createdAt: Value(createdAt),
    );
  }

  factory LocalExpense.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalExpense(
      id: serializer.fromJson<String>(json['id']),
      homeId: serializer.fromJson<String>(json['homeId']),
      title: serializer.fromJson<String>(json['title']),
      amount: serializer.fromJson<double>(json['amount']),
      currency: serializer.fromJson<String>(json['currency']),
      paidBy: serializer.fromJson<String>(json['paidBy']),
      splitRatio: serializer.fromJson<double>(json['splitRatio']),
      expenseDate: serializer.fromJson<DateTime>(json['expenseDate']),
      category: serializer.fromJson<String?>(json['category']),
      paymentMethod: serializer.fromJson<String?>(json['paymentMethod']),
      isTransfer: serializer.fromJson<bool>(json['isTransfer']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'homeId': serializer.toJson<String>(homeId),
      'title': serializer.toJson<String>(title),
      'amount': serializer.toJson<double>(amount),
      'currency': serializer.toJson<String>(currency),
      'paidBy': serializer.toJson<String>(paidBy),
      'splitRatio': serializer.toJson<double>(splitRatio),
      'expenseDate': serializer.toJson<DateTime>(expenseDate),
      'category': serializer.toJson<String?>(category),
      'paymentMethod': serializer.toJson<String?>(paymentMethod),
      'isTransfer': serializer.toJson<bool>(isTransfer),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalExpense copyWith({
    String? id,
    String? homeId,
    String? title,
    double? amount,
    String? currency,
    String? paidBy,
    double? splitRatio,
    DateTime? expenseDate,
    Value<String?> category = const Value.absent(),
    Value<String?> paymentMethod = const Value.absent(),
    bool? isTransfer,
    DateTime? createdAt,
  }) => LocalExpense(
    id: id ?? this.id,
    homeId: homeId ?? this.homeId,
    title: title ?? this.title,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    paidBy: paidBy ?? this.paidBy,
    splitRatio: splitRatio ?? this.splitRatio,
    expenseDate: expenseDate ?? this.expenseDate,
    category: category.present ? category.value : this.category,
    paymentMethod: paymentMethod.present
        ? paymentMethod.value
        : this.paymentMethod,
    isTransfer: isTransfer ?? this.isTransfer,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalExpense copyWithCompanion(LocalExpensesCompanion data) {
    return LocalExpense(
      id: data.id.present ? data.id.value : this.id,
      homeId: data.homeId.present ? data.homeId.value : this.homeId,
      title: data.title.present ? data.title.value : this.title,
      amount: data.amount.present ? data.amount.value : this.amount,
      currency: data.currency.present ? data.currency.value : this.currency,
      paidBy: data.paidBy.present ? data.paidBy.value : this.paidBy,
      splitRatio: data.splitRatio.present
          ? data.splitRatio.value
          : this.splitRatio,
      expenseDate: data.expenseDate.present
          ? data.expenseDate.value
          : this.expenseDate,
      category: data.category.present ? data.category.value : this.category,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      isTransfer: data.isTransfer.present
          ? data.isTransfer.value
          : this.isTransfer,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalExpense(')
          ..write('id: $id, ')
          ..write('homeId: $homeId, ')
          ..write('title: $title, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('paidBy: $paidBy, ')
          ..write('splitRatio: $splitRatio, ')
          ..write('expenseDate: $expenseDate, ')
          ..write('category: $category, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('isTransfer: $isTransfer, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    homeId,
    title,
    amount,
    currency,
    paidBy,
    splitRatio,
    expenseDate,
    category,
    paymentMethod,
    isTransfer,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalExpense &&
          other.id == this.id &&
          other.homeId == this.homeId &&
          other.title == this.title &&
          other.amount == this.amount &&
          other.currency == this.currency &&
          other.paidBy == this.paidBy &&
          other.splitRatio == this.splitRatio &&
          other.expenseDate == this.expenseDate &&
          other.category == this.category &&
          other.paymentMethod == this.paymentMethod &&
          other.isTransfer == this.isTransfer &&
          other.createdAt == this.createdAt);
}

class LocalExpensesCompanion extends UpdateCompanion<LocalExpense> {
  final Value<String> id;
  final Value<String> homeId;
  final Value<String> title;
  final Value<double> amount;
  final Value<String> currency;
  final Value<String> paidBy;
  final Value<double> splitRatio;
  final Value<DateTime> expenseDate;
  final Value<String?> category;
  final Value<String?> paymentMethod;
  final Value<bool> isTransfer;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalExpensesCompanion({
    this.id = const Value.absent(),
    this.homeId = const Value.absent(),
    this.title = const Value.absent(),
    this.amount = const Value.absent(),
    this.currency = const Value.absent(),
    this.paidBy = const Value.absent(),
    this.splitRatio = const Value.absent(),
    this.expenseDate = const Value.absent(),
    this.category = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.isTransfer = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalExpensesCompanion.insert({
    required String id,
    required String homeId,
    required String title,
    required double amount,
    this.currency = const Value.absent(),
    required String paidBy,
    this.splitRatio = const Value.absent(),
    required DateTime expenseDate,
    this.category = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.isTransfer = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       homeId = Value(homeId),
       title = Value(title),
       amount = Value(amount),
       paidBy = Value(paidBy),
       expenseDate = Value(expenseDate),
       createdAt = Value(createdAt);
  static Insertable<LocalExpense> custom({
    Expression<String>? id,
    Expression<String>? homeId,
    Expression<String>? title,
    Expression<double>? amount,
    Expression<String>? currency,
    Expression<String>? paidBy,
    Expression<double>? splitRatio,
    Expression<DateTime>? expenseDate,
    Expression<String>? category,
    Expression<String>? paymentMethod,
    Expression<bool>? isTransfer,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (homeId != null) 'home_id': homeId,
      if (title != null) 'title': title,
      if (amount != null) 'amount': amount,
      if (currency != null) 'currency': currency,
      if (paidBy != null) 'paid_by': paidBy,
      if (splitRatio != null) 'split_ratio': splitRatio,
      if (expenseDate != null) 'expense_date': expenseDate,
      if (category != null) 'category': category,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (isTransfer != null) 'is_transfer': isTransfer,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalExpensesCompanion copyWith({
    Value<String>? id,
    Value<String>? homeId,
    Value<String>? title,
    Value<double>? amount,
    Value<String>? currency,
    Value<String>? paidBy,
    Value<double>? splitRatio,
    Value<DateTime>? expenseDate,
    Value<String?>? category,
    Value<String?>? paymentMethod,
    Value<bool>? isTransfer,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalExpensesCompanion(
      id: id ?? this.id,
      homeId: homeId ?? this.homeId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      paidBy: paidBy ?? this.paidBy,
      splitRatio: splitRatio ?? this.splitRatio,
      expenseDate: expenseDate ?? this.expenseDate,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isTransfer: isTransfer ?? this.isTransfer,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (homeId.present) {
      map['home_id'] = Variable<String>(homeId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (paidBy.present) {
      map['paid_by'] = Variable<String>(paidBy.value);
    }
    if (splitRatio.present) {
      map['split_ratio'] = Variable<double>(splitRatio.value);
    }
    if (expenseDate.present) {
      map['expense_date'] = Variable<DateTime>(expenseDate.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (isTransfer.present) {
      map['is_transfer'] = Variable<bool>(isTransfer.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalExpensesCompanion(')
          ..write('id: $id, ')
          ..write('homeId: $homeId, ')
          ..write('title: $title, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('paidBy: $paidBy, ')
          ..write('splitRatio: $splitRatio, ')
          ..write('expenseDate: $expenseDate, ')
          ..write('category: $category, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('isTransfer: $isTransfer, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalHabitsTable extends LocalHabits
    with TableInfo<$LocalHabitsTable, LocalHabit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalHabitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _homeIdMeta = const VerificationMeta('homeId');
  @override
  late final GeneratedColumn<String> homeId = GeneratedColumn<String>(
    'home_id',
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
  static const VerificationMeta _cadenceMeta = const VerificationMeta(
    'cadence',
  );
  @override
  late final GeneratedColumn<String> cadence = GeneratedColumn<String>(
    'cadence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('daily'),
  );
  static const VerificationMeta _targetDaysPerWeekMeta = const VerificationMeta(
    'targetDaysPerWeek',
  );
  @override
  late final GeneratedColumn<int> targetDaysPerWeek = GeneratedColumn<int>(
    'target_days_per_week',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(7),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    homeId,
    name,
    cadence,
    targetDaysPerWeek,
    isArchived,
    createdAt,
    createdBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_habits';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalHabit> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('home_id')) {
      context.handle(
        _homeIdMeta,
        homeId.isAcceptableOrUnknown(data['home_id']!, _homeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_homeIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('cadence')) {
      context.handle(
        _cadenceMeta,
        cadence.isAcceptableOrUnknown(data['cadence']!, _cadenceMeta),
      );
    }
    if (data.containsKey('target_days_per_week')) {
      context.handle(
        _targetDaysPerWeekMeta,
        targetDaysPerWeek.isAcceptableOrUnknown(
          data['target_days_per_week']!,
          _targetDaysPerWeekMeta,
        ),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalHabit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalHabit(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      homeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}home_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      cadence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cadence'],
      )!,
      targetDaysPerWeek: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_days_per_week'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
    );
  }

  @override
  $LocalHabitsTable createAlias(String alias) {
    return $LocalHabitsTable(attachedDatabase, alias);
  }
}

class LocalHabit extends DataClass implements Insertable<LocalHabit> {
  final String id;
  final String homeId;
  final String name;
  final String cadence;
  final int targetDaysPerWeek;
  final bool isArchived;
  final DateTime createdAt;
  final String createdBy;
  const LocalHabit({
    required this.id,
    required this.homeId,
    required this.name,
    required this.cadence,
    required this.targetDaysPerWeek,
    required this.isArchived,
    required this.createdAt,
    required this.createdBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['home_id'] = Variable<String>(homeId);
    map['name'] = Variable<String>(name);
    map['cadence'] = Variable<String>(cadence);
    map['target_days_per_week'] = Variable<int>(targetDaysPerWeek);
    map['is_archived'] = Variable<bool>(isArchived);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['created_by'] = Variable<String>(createdBy);
    return map;
  }

  LocalHabitsCompanion toCompanion(bool nullToAbsent) {
    return LocalHabitsCompanion(
      id: Value(id),
      homeId: Value(homeId),
      name: Value(name),
      cadence: Value(cadence),
      targetDaysPerWeek: Value(targetDaysPerWeek),
      isArchived: Value(isArchived),
      createdAt: Value(createdAt),
      createdBy: Value(createdBy),
    );
  }

  factory LocalHabit.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalHabit(
      id: serializer.fromJson<String>(json['id']),
      homeId: serializer.fromJson<String>(json['homeId']),
      name: serializer.fromJson<String>(json['name']),
      cadence: serializer.fromJson<String>(json['cadence']),
      targetDaysPerWeek: serializer.fromJson<int>(json['targetDaysPerWeek']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'homeId': serializer.toJson<String>(homeId),
      'name': serializer.toJson<String>(name),
      'cadence': serializer.toJson<String>(cadence),
      'targetDaysPerWeek': serializer.toJson<int>(targetDaysPerWeek),
      'isArchived': serializer.toJson<bool>(isArchived),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'createdBy': serializer.toJson<String>(createdBy),
    };
  }

  LocalHabit copyWith({
    String? id,
    String? homeId,
    String? name,
    String? cadence,
    int? targetDaysPerWeek,
    bool? isArchived,
    DateTime? createdAt,
    String? createdBy,
  }) => LocalHabit(
    id: id ?? this.id,
    homeId: homeId ?? this.homeId,
    name: name ?? this.name,
    cadence: cadence ?? this.cadence,
    targetDaysPerWeek: targetDaysPerWeek ?? this.targetDaysPerWeek,
    isArchived: isArchived ?? this.isArchived,
    createdAt: createdAt ?? this.createdAt,
    createdBy: createdBy ?? this.createdBy,
  );
  LocalHabit copyWithCompanion(LocalHabitsCompanion data) {
    return LocalHabit(
      id: data.id.present ? data.id.value : this.id,
      homeId: data.homeId.present ? data.homeId.value : this.homeId,
      name: data.name.present ? data.name.value : this.name,
      cadence: data.cadence.present ? data.cadence.value : this.cadence,
      targetDaysPerWeek: data.targetDaysPerWeek.present
          ? data.targetDaysPerWeek.value
          : this.targetDaysPerWeek,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalHabit(')
          ..write('id: $id, ')
          ..write('homeId: $homeId, ')
          ..write('name: $name, ')
          ..write('cadence: $cadence, ')
          ..write('targetDaysPerWeek: $targetDaysPerWeek, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdBy: $createdBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    homeId,
    name,
    cadence,
    targetDaysPerWeek,
    isArchived,
    createdAt,
    createdBy,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalHabit &&
          other.id == this.id &&
          other.homeId == this.homeId &&
          other.name == this.name &&
          other.cadence == this.cadence &&
          other.targetDaysPerWeek == this.targetDaysPerWeek &&
          other.isArchived == this.isArchived &&
          other.createdAt == this.createdAt &&
          other.createdBy == this.createdBy);
}

class LocalHabitsCompanion extends UpdateCompanion<LocalHabit> {
  final Value<String> id;
  final Value<String> homeId;
  final Value<String> name;
  final Value<String> cadence;
  final Value<int> targetDaysPerWeek;
  final Value<bool> isArchived;
  final Value<DateTime> createdAt;
  final Value<String> createdBy;
  final Value<int> rowid;
  const LocalHabitsCompanion({
    this.id = const Value.absent(),
    this.homeId = const Value.absent(),
    this.name = const Value.absent(),
    this.cadence = const Value.absent(),
    this.targetDaysPerWeek = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalHabitsCompanion.insert({
    required String id,
    required String homeId,
    required String name,
    this.cadence = const Value.absent(),
    this.targetDaysPerWeek = const Value.absent(),
    this.isArchived = const Value.absent(),
    required DateTime createdAt,
    required String createdBy,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       homeId = Value(homeId),
       name = Value(name),
       createdAt = Value(createdAt),
       createdBy = Value(createdBy);
  static Insertable<LocalHabit> custom({
    Expression<String>? id,
    Expression<String>? homeId,
    Expression<String>? name,
    Expression<String>? cadence,
    Expression<int>? targetDaysPerWeek,
    Expression<bool>? isArchived,
    Expression<DateTime>? createdAt,
    Expression<String>? createdBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (homeId != null) 'home_id': homeId,
      if (name != null) 'name': name,
      if (cadence != null) 'cadence': cadence,
      if (targetDaysPerWeek != null) 'target_days_per_week': targetDaysPerWeek,
      if (isArchived != null) 'is_archived': isArchived,
      if (createdAt != null) 'created_at': createdAt,
      if (createdBy != null) 'created_by': createdBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalHabitsCompanion copyWith({
    Value<String>? id,
    Value<String>? homeId,
    Value<String>? name,
    Value<String>? cadence,
    Value<int>? targetDaysPerWeek,
    Value<bool>? isArchived,
    Value<DateTime>? createdAt,
    Value<String>? createdBy,
    Value<int>? rowid,
  }) {
    return LocalHabitsCompanion(
      id: id ?? this.id,
      homeId: homeId ?? this.homeId,
      name: name ?? this.name,
      cadence: cadence ?? this.cadence,
      targetDaysPerWeek: targetDaysPerWeek ?? this.targetDaysPerWeek,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (homeId.present) {
      map['home_id'] = Variable<String>(homeId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (cadence.present) {
      map['cadence'] = Variable<String>(cadence.value);
    }
    if (targetDaysPerWeek.present) {
      map['target_days_per_week'] = Variable<int>(targetDaysPerWeek.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalHabitsCompanion(')
          ..write('id: $id, ')
          ..write('homeId: $homeId, ')
          ..write('name: $name, ')
          ..write('cadence: $cadence, ')
          ..write('targetDaysPerWeek: $targetDaysPerWeek, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalHabitCheckinsTable extends LocalHabitCheckins
    with TableInfo<$LocalHabitCheckinsTable, LocalHabitCheckin> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalHabitCheckinsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _homeIdMeta = const VerificationMeta('homeId');
  @override
  late final GeneratedColumn<String> homeId = GeneratedColumn<String>(
    'home_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _habitIdMeta = const VerificationMeta(
    'habitId',
  );
  @override
  late final GeneratedColumn<String> habitId = GeneratedColumn<String>(
    'habit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkinDateMeta = const VerificationMeta(
    'checkinDate',
  );
  @override
  late final GeneratedColumn<String> checkinDate = GeneratedColumn<String>(
    'checkin_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memberIdMeta = const VerificationMeta(
    'memberId',
  );
  @override
  late final GeneratedColumn<String> memberId = GeneratedColumn<String>(
    'member_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    homeId,
    habitId,
    checkinDate,
    memberId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_habit_checkins';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalHabitCheckin> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('home_id')) {
      context.handle(
        _homeIdMeta,
        homeId.isAcceptableOrUnknown(data['home_id']!, _homeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_homeIdMeta);
    }
    if (data.containsKey('habit_id')) {
      context.handle(
        _habitIdMeta,
        habitId.isAcceptableOrUnknown(data['habit_id']!, _habitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_habitIdMeta);
    }
    if (data.containsKey('checkin_date')) {
      context.handle(
        _checkinDateMeta,
        checkinDate.isAcceptableOrUnknown(
          data['checkin_date']!,
          _checkinDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_checkinDateMeta);
    }
    if (data.containsKey('member_id')) {
      context.handle(
        _memberIdMeta,
        memberId.isAcceptableOrUnknown(data['member_id']!, _memberIdMeta),
      );
    } else if (isInserting) {
      context.missing(_memberIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalHabitCheckin map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalHabitCheckin(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      homeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}home_id'],
      )!,
      habitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}habit_id'],
      )!,
      checkinDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checkin_date'],
      )!,
      memberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalHabitCheckinsTable createAlias(String alias) {
    return $LocalHabitCheckinsTable(attachedDatabase, alias);
  }
}

class LocalHabitCheckin extends DataClass
    implements Insertable<LocalHabitCheckin> {
  final String id;
  final String homeId;
  final String habitId;
  final String checkinDate;
  final String memberId;
  final DateTime createdAt;
  const LocalHabitCheckin({
    required this.id,
    required this.homeId,
    required this.habitId,
    required this.checkinDate,
    required this.memberId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['home_id'] = Variable<String>(homeId);
    map['habit_id'] = Variable<String>(habitId);
    map['checkin_date'] = Variable<String>(checkinDate);
    map['member_id'] = Variable<String>(memberId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalHabitCheckinsCompanion toCompanion(bool nullToAbsent) {
    return LocalHabitCheckinsCompanion(
      id: Value(id),
      homeId: Value(homeId),
      habitId: Value(habitId),
      checkinDate: Value(checkinDate),
      memberId: Value(memberId),
      createdAt: Value(createdAt),
    );
  }

  factory LocalHabitCheckin.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalHabitCheckin(
      id: serializer.fromJson<String>(json['id']),
      homeId: serializer.fromJson<String>(json['homeId']),
      habitId: serializer.fromJson<String>(json['habitId']),
      checkinDate: serializer.fromJson<String>(json['checkinDate']),
      memberId: serializer.fromJson<String>(json['memberId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'homeId': serializer.toJson<String>(homeId),
      'habitId': serializer.toJson<String>(habitId),
      'checkinDate': serializer.toJson<String>(checkinDate),
      'memberId': serializer.toJson<String>(memberId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalHabitCheckin copyWith({
    String? id,
    String? homeId,
    String? habitId,
    String? checkinDate,
    String? memberId,
    DateTime? createdAt,
  }) => LocalHabitCheckin(
    id: id ?? this.id,
    homeId: homeId ?? this.homeId,
    habitId: habitId ?? this.habitId,
    checkinDate: checkinDate ?? this.checkinDate,
    memberId: memberId ?? this.memberId,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalHabitCheckin copyWithCompanion(LocalHabitCheckinsCompanion data) {
    return LocalHabitCheckin(
      id: data.id.present ? data.id.value : this.id,
      homeId: data.homeId.present ? data.homeId.value : this.homeId,
      habitId: data.habitId.present ? data.habitId.value : this.habitId,
      checkinDate: data.checkinDate.present
          ? data.checkinDate.value
          : this.checkinDate,
      memberId: data.memberId.present ? data.memberId.value : this.memberId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalHabitCheckin(')
          ..write('id: $id, ')
          ..write('homeId: $homeId, ')
          ..write('habitId: $habitId, ')
          ..write('checkinDate: $checkinDate, ')
          ..write('memberId: $memberId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, homeId, habitId, checkinDate, memberId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalHabitCheckin &&
          other.id == this.id &&
          other.homeId == this.homeId &&
          other.habitId == this.habitId &&
          other.checkinDate == this.checkinDate &&
          other.memberId == this.memberId &&
          other.createdAt == this.createdAt);
}

class LocalHabitCheckinsCompanion extends UpdateCompanion<LocalHabitCheckin> {
  final Value<String> id;
  final Value<String> homeId;
  final Value<String> habitId;
  final Value<String> checkinDate;
  final Value<String> memberId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalHabitCheckinsCompanion({
    this.id = const Value.absent(),
    this.homeId = const Value.absent(),
    this.habitId = const Value.absent(),
    this.checkinDate = const Value.absent(),
    this.memberId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalHabitCheckinsCompanion.insert({
    required String id,
    required String homeId,
    required String habitId,
    required String checkinDate,
    required String memberId,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       homeId = Value(homeId),
       habitId = Value(habitId),
       checkinDate = Value(checkinDate),
       memberId = Value(memberId),
       createdAt = Value(createdAt);
  static Insertable<LocalHabitCheckin> custom({
    Expression<String>? id,
    Expression<String>? homeId,
    Expression<String>? habitId,
    Expression<String>? checkinDate,
    Expression<String>? memberId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (homeId != null) 'home_id': homeId,
      if (habitId != null) 'habit_id': habitId,
      if (checkinDate != null) 'checkin_date': checkinDate,
      if (memberId != null) 'member_id': memberId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalHabitCheckinsCompanion copyWith({
    Value<String>? id,
    Value<String>? homeId,
    Value<String>? habitId,
    Value<String>? checkinDate,
    Value<String>? memberId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalHabitCheckinsCompanion(
      id: id ?? this.id,
      homeId: homeId ?? this.homeId,
      habitId: habitId ?? this.habitId,
      checkinDate: checkinDate ?? this.checkinDate,
      memberId: memberId ?? this.memberId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (homeId.present) {
      map['home_id'] = Variable<String>(homeId.value);
    }
    if (habitId.present) {
      map['habit_id'] = Variable<String>(habitId.value);
    }
    if (checkinDate.present) {
      map['checkin_date'] = Variable<String>(checkinDate.value);
    }
    if (memberId.present) {
      map['member_id'] = Variable<String>(memberId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalHabitCheckinsCompanion(')
          ..write('id: $id, ')
          ..write('homeId: $homeId, ')
          ..write('habitId: $habitId, ')
          ..write('checkinDate: $checkinDate, ')
          ..write('memberId: $memberId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalCalendarEventsTable extends LocalCalendarEvents
    with TableInfo<$LocalCalendarEventsTable, LocalCalendarEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalCalendarEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _homeIdMeta = const VerificationMeta('homeId');
  @override
  late final GeneratedColumn<String> homeId = GeneratedColumn<String>(
    'home_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
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
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
    'start_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<DateTime> endTime = GeneratedColumn<DateTime>(
    'end_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isAllDayMeta = const VerificationMeta(
    'isAllDay',
  );
  @override
  late final GeneratedColumn<bool> isAllDay = GeneratedColumn<bool>(
    'is_all_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_all_day" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recurrenceMeta = const VerificationMeta(
    'recurrence',
  );
  @override
  late final GeneratedColumn<String> recurrence = GeneratedColumn<String>(
    'recurrence',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    homeId,
    title,
    description,
    startTime,
    endTime,
    isAllDay,
    location,
    createdAt,
    createdBy,
    recurrence,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_calendar_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalCalendarEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('home_id')) {
      context.handle(
        _homeIdMeta,
        homeId.isAcceptableOrUnknown(data['home_id']!, _homeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_homeIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
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
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_endTimeMeta);
    }
    if (data.containsKey('is_all_day')) {
      context.handle(
        _isAllDayMeta,
        isAllDay.isAcceptableOrUnknown(data['is_all_day']!, _isAllDayMeta),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('recurrence')) {
      context.handle(
        _recurrenceMeta,
        recurrence.isAcceptableOrUnknown(data['recurrence']!, _recurrenceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalCalendarEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalCalendarEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      homeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}home_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_time'],
      )!,
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_time'],
      )!,
      isAllDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_all_day'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      recurrence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence'],
      ),
    );
  }

  @override
  $LocalCalendarEventsTable createAlias(String alias) {
    return $LocalCalendarEventsTable(attachedDatabase, alias);
  }
}

class LocalCalendarEvent extends DataClass
    implements Insertable<LocalCalendarEvent> {
  final String id;
  final String homeId;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final String? location;
  final DateTime createdAt;
  final String createdBy;
  final String? recurrence;
  const LocalCalendarEvent({
    required this.id,
    required this.homeId,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    required this.isAllDay,
    this.location,
    required this.createdAt,
    required this.createdBy,
    this.recurrence,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['home_id'] = Variable<String>(homeId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['start_time'] = Variable<DateTime>(startTime);
    map['end_time'] = Variable<DateTime>(endTime);
    map['is_all_day'] = Variable<bool>(isAllDay);
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['created_by'] = Variable<String>(createdBy);
    if (!nullToAbsent || recurrence != null) {
      map['recurrence'] = Variable<String>(recurrence);
    }
    return map;
  }

  LocalCalendarEventsCompanion toCompanion(bool nullToAbsent) {
    return LocalCalendarEventsCompanion(
      id: Value(id),
      homeId: Value(homeId),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      startTime: Value(startTime),
      endTime: Value(endTime),
      isAllDay: Value(isAllDay),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      createdAt: Value(createdAt),
      createdBy: Value(createdBy),
      recurrence: recurrence == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrence),
    );
  }

  factory LocalCalendarEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalCalendarEvent(
      id: serializer.fromJson<String>(json['id']),
      homeId: serializer.fromJson<String>(json['homeId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      startTime: serializer.fromJson<DateTime>(json['startTime']),
      endTime: serializer.fromJson<DateTime>(json['endTime']),
      isAllDay: serializer.fromJson<bool>(json['isAllDay']),
      location: serializer.fromJson<String?>(json['location']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      recurrence: serializer.fromJson<String?>(json['recurrence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'homeId': serializer.toJson<String>(homeId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'startTime': serializer.toJson<DateTime>(startTime),
      'endTime': serializer.toJson<DateTime>(endTime),
      'isAllDay': serializer.toJson<bool>(isAllDay),
      'location': serializer.toJson<String?>(location),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'createdBy': serializer.toJson<String>(createdBy),
      'recurrence': serializer.toJson<String?>(recurrence),
    };
  }

  LocalCalendarEvent copyWith({
    String? id,
    String? homeId,
    String? title,
    Value<String?> description = const Value.absent(),
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    Value<String?> location = const Value.absent(),
    DateTime? createdAt,
    String? createdBy,
    Value<String?> recurrence = const Value.absent(),
  }) => LocalCalendarEvent(
    id: id ?? this.id,
    homeId: homeId ?? this.homeId,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    isAllDay: isAllDay ?? this.isAllDay,
    location: location.present ? location.value : this.location,
    createdAt: createdAt ?? this.createdAt,
    createdBy: createdBy ?? this.createdBy,
    recurrence: recurrence.present ? recurrence.value : this.recurrence,
  );
  LocalCalendarEvent copyWithCompanion(LocalCalendarEventsCompanion data) {
    return LocalCalendarEvent(
      id: data.id.present ? data.id.value : this.id,
      homeId: data.homeId.present ? data.homeId.value : this.homeId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      isAllDay: data.isAllDay.present ? data.isAllDay.value : this.isAllDay,
      location: data.location.present ? data.location.value : this.location,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      recurrence: data.recurrence.present
          ? data.recurrence.value
          : this.recurrence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalCalendarEvent(')
          ..write('id: $id, ')
          ..write('homeId: $homeId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('isAllDay: $isAllDay, ')
          ..write('location: $location, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('recurrence: $recurrence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    homeId,
    title,
    description,
    startTime,
    endTime,
    isAllDay,
    location,
    createdAt,
    createdBy,
    recurrence,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalCalendarEvent &&
          other.id == this.id &&
          other.homeId == this.homeId &&
          other.title == this.title &&
          other.description == this.description &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.isAllDay == this.isAllDay &&
          other.location == this.location &&
          other.createdAt == this.createdAt &&
          other.createdBy == this.createdBy &&
          other.recurrence == this.recurrence);
}

class LocalCalendarEventsCompanion extends UpdateCompanion<LocalCalendarEvent> {
  final Value<String> id;
  final Value<String> homeId;
  final Value<String> title;
  final Value<String?> description;
  final Value<DateTime> startTime;
  final Value<DateTime> endTime;
  final Value<bool> isAllDay;
  final Value<String?> location;
  final Value<DateTime> createdAt;
  final Value<String> createdBy;
  final Value<String?> recurrence;
  final Value<int> rowid;
  const LocalCalendarEventsCompanion({
    this.id = const Value.absent(),
    this.homeId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.isAllDay = const Value.absent(),
    this.location = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalCalendarEventsCompanion.insert({
    required String id,
    required String homeId,
    required String title,
    this.description = const Value.absent(),
    required DateTime startTime,
    required DateTime endTime,
    this.isAllDay = const Value.absent(),
    this.location = const Value.absent(),
    required DateTime createdAt,
    required String createdBy,
    this.recurrence = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       homeId = Value(homeId),
       title = Value(title),
       startTime = Value(startTime),
       endTime = Value(endTime),
       createdAt = Value(createdAt),
       createdBy = Value(createdBy);
  static Insertable<LocalCalendarEvent> custom({
    Expression<String>? id,
    Expression<String>? homeId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<DateTime>? startTime,
    Expression<DateTime>? endTime,
    Expression<bool>? isAllDay,
    Expression<String>? location,
    Expression<DateTime>? createdAt,
    Expression<String>? createdBy,
    Expression<String>? recurrence,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (homeId != null) 'home_id': homeId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (isAllDay != null) 'is_all_day': isAllDay,
      if (location != null) 'location': location,
      if (createdAt != null) 'created_at': createdAt,
      if (createdBy != null) 'created_by': createdBy,
      if (recurrence != null) 'recurrence': recurrence,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalCalendarEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? homeId,
    Value<String>? title,
    Value<String?>? description,
    Value<DateTime>? startTime,
    Value<DateTime>? endTime,
    Value<bool>? isAllDay,
    Value<String?>? location,
    Value<DateTime>? createdAt,
    Value<String>? createdBy,
    Value<String?>? recurrence,
    Value<int>? rowid,
  }) {
    return LocalCalendarEventsCompanion(
      id: id ?? this.id,
      homeId: homeId ?? this.homeId,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      recurrence: recurrence ?? this.recurrence,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (homeId.present) {
      map['home_id'] = Variable<String>(homeId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<DateTime>(endTime.value);
    }
    if (isAllDay.present) {
      map['is_all_day'] = Variable<bool>(isAllDay.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (recurrence.present) {
      map['recurrence'] = Variable<String>(recurrence.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalCalendarEventsCompanion(')
          ..write('id: $id, ')
          ..write('homeId: $homeId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('isAllDay: $isAllDay, ')
          ..write('location: $location, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('recurrence: $recurrence, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalOutboxEventsTable extends LocalOutboxEvents
    with TableInfo<$LocalOutboxEventsTable, LocalOutboxEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalOutboxEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _homeIdMeta = const VerificationMeta('homeId');
  @override
  late final GeneratedColumn<String> homeId = GeneratedColumn<String>(
    'home_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actorIdMeta = const VerificationMeta(
    'actorId',
  );
  @override
  late final GeneratedColumn<String> actorId = GeneratedColumn<String>(
    'actor_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encryptedPayloadMeta = const VerificationMeta(
    'encryptedPayload',
  );
  @override
  late final GeneratedColumn<String> encryptedPayload = GeneratedColumn<String>(
    'encrypted_payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('savedLocally'),
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    homeId,
    actorId,
    eventType,
    payloadJson,
    encryptedPayload,
    createdAt,
    syncStatus,
    retryCount,
    lastAttemptAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_outbox_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalOutboxEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('home_id')) {
      context.handle(
        _homeIdMeta,
        homeId.isAcceptableOrUnknown(data['home_id']!, _homeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_homeIdMeta);
    }
    if (data.containsKey('actor_id')) {
      context.handle(
        _actorIdMeta,
        actorId.isAcceptableOrUnknown(data['actor_id']!, _actorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_actorIdMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('encrypted_payload')) {
      context.handle(
        _encryptedPayloadMeta,
        encryptedPayload.isAcceptableOrUnknown(
          data['encrypted_payload']!,
          _encryptedPayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedPayloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalOutboxEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalOutboxEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      homeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}home_id'],
      )!,
      actorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_id'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      encryptedPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
    );
  }

  @override
  $LocalOutboxEventsTable createAlias(String alias) {
    return $LocalOutboxEventsTable(attachedDatabase, alias);
  }
}

class LocalOutboxEvent extends DataClass
    implements Insertable<LocalOutboxEvent> {
  final String id;
  final String homeId;
  final String actorId;
  final String eventType;
  final String payloadJson;
  final String encryptedPayload;
  final DateTime createdAt;
  final String syncStatus;
  final int retryCount;
  final DateTime? lastAttemptAt;
  const LocalOutboxEvent({
    required this.id,
    required this.homeId,
    required this.actorId,
    required this.eventType,
    required this.payloadJson,
    required this.encryptedPayload,
    required this.createdAt,
    required this.syncStatus,
    required this.retryCount,
    this.lastAttemptAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['home_id'] = Variable<String>(homeId);
    map['actor_id'] = Variable<String>(actorId);
    map['event_type'] = Variable<String>(eventType);
    map['payload_json'] = Variable<String>(payloadJson);
    map['encrypted_payload'] = Variable<String>(encryptedPayload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['sync_status'] = Variable<String>(syncStatus);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    return map;
  }

  LocalOutboxEventsCompanion toCompanion(bool nullToAbsent) {
    return LocalOutboxEventsCompanion(
      id: Value(id),
      homeId: Value(homeId),
      actorId: Value(actorId),
      eventType: Value(eventType),
      payloadJson: Value(payloadJson),
      encryptedPayload: Value(encryptedPayload),
      createdAt: Value(createdAt),
      syncStatus: Value(syncStatus),
      retryCount: Value(retryCount),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
    );
  }

  factory LocalOutboxEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalOutboxEvent(
      id: serializer.fromJson<String>(json['id']),
      homeId: serializer.fromJson<String>(json['homeId']),
      actorId: serializer.fromJson<String>(json['actorId']),
      eventType: serializer.fromJson<String>(json['eventType']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      encryptedPayload: serializer.fromJson<String>(json['encryptedPayload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'homeId': serializer.toJson<String>(homeId),
      'actorId': serializer.toJson<String>(actorId),
      'eventType': serializer.toJson<String>(eventType),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'encryptedPayload': serializer.toJson<String>(encryptedPayload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
    };
  }

  LocalOutboxEvent copyWith({
    String? id,
    String? homeId,
    String? actorId,
    String? eventType,
    String? payloadJson,
    String? encryptedPayload,
    DateTime? createdAt,
    String? syncStatus,
    int? retryCount,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
  }) => LocalOutboxEvent(
    id: id ?? this.id,
    homeId: homeId ?? this.homeId,
    actorId: actorId ?? this.actorId,
    eventType: eventType ?? this.eventType,
    payloadJson: payloadJson ?? this.payloadJson,
    encryptedPayload: encryptedPayload ?? this.encryptedPayload,
    createdAt: createdAt ?? this.createdAt,
    syncStatus: syncStatus ?? this.syncStatus,
    retryCount: retryCount ?? this.retryCount,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
  );
  LocalOutboxEvent copyWithCompanion(LocalOutboxEventsCompanion data) {
    return LocalOutboxEvent(
      id: data.id.present ? data.id.value : this.id,
      homeId: data.homeId.present ? data.homeId.value : this.homeId,
      actorId: data.actorId.present ? data.actorId.value : this.actorId,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      encryptedPayload: data.encryptedPayload.present
          ? data.encryptedPayload.value
          : this.encryptedPayload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalOutboxEvent(')
          ..write('id: $id, ')
          ..write('homeId: $homeId, ')
          ..write('actorId: $actorId, ')
          ..write('eventType: $eventType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('encryptedPayload: $encryptedPayload, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastAttemptAt: $lastAttemptAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    homeId,
    actorId,
    eventType,
    payloadJson,
    encryptedPayload,
    createdAt,
    syncStatus,
    retryCount,
    lastAttemptAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalOutboxEvent &&
          other.id == this.id &&
          other.homeId == this.homeId &&
          other.actorId == this.actorId &&
          other.eventType == this.eventType &&
          other.payloadJson == this.payloadJson &&
          other.encryptedPayload == this.encryptedPayload &&
          other.createdAt == this.createdAt &&
          other.syncStatus == this.syncStatus &&
          other.retryCount == this.retryCount &&
          other.lastAttemptAt == this.lastAttemptAt);
}

class LocalOutboxEventsCompanion extends UpdateCompanion<LocalOutboxEvent> {
  final Value<String> id;
  final Value<String> homeId;
  final Value<String> actorId;
  final Value<String> eventType;
  final Value<String> payloadJson;
  final Value<String> encryptedPayload;
  final Value<DateTime> createdAt;
  final Value<String> syncStatus;
  final Value<int> retryCount;
  final Value<DateTime?> lastAttemptAt;
  final Value<int> rowid;
  const LocalOutboxEventsCompanion({
    this.id = const Value.absent(),
    this.homeId = const Value.absent(),
    this.actorId = const Value.absent(),
    this.eventType = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.encryptedPayload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalOutboxEventsCompanion.insert({
    required String id,
    required String homeId,
    required String actorId,
    required String eventType,
    required String payloadJson,
    required String encryptedPayload,
    required DateTime createdAt,
    this.syncStatus = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       homeId = Value(homeId),
       actorId = Value(actorId),
       eventType = Value(eventType),
       payloadJson = Value(payloadJson),
       encryptedPayload = Value(encryptedPayload),
       createdAt = Value(createdAt);
  static Insertable<LocalOutboxEvent> custom({
    Expression<String>? id,
    Expression<String>? homeId,
    Expression<String>? actorId,
    Expression<String>? eventType,
    Expression<String>? payloadJson,
    Expression<String>? encryptedPayload,
    Expression<DateTime>? createdAt,
    Expression<String>? syncStatus,
    Expression<int>? retryCount,
    Expression<DateTime>? lastAttemptAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (homeId != null) 'home_id': homeId,
      if (actorId != null) 'actor_id': actorId,
      if (eventType != null) 'event_type': eventType,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (encryptedPayload != null) 'encrypted_payload': encryptedPayload,
      if (createdAt != null) 'created_at': createdAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalOutboxEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? homeId,
    Value<String>? actorId,
    Value<String>? eventType,
    Value<String>? payloadJson,
    Value<String>? encryptedPayload,
    Value<DateTime>? createdAt,
    Value<String>? syncStatus,
    Value<int>? retryCount,
    Value<DateTime?>? lastAttemptAt,
    Value<int>? rowid,
  }) {
    return LocalOutboxEventsCompanion(
      id: id ?? this.id,
      homeId: homeId ?? this.homeId,
      actorId: actorId ?? this.actorId,
      eventType: eventType ?? this.eventType,
      payloadJson: payloadJson ?? this.payloadJson,
      encryptedPayload: encryptedPayload ?? this.encryptedPayload,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      retryCount: retryCount ?? this.retryCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (homeId.present) {
      map['home_id'] = Variable<String>(homeId.value);
    }
    if (actorId.present) {
      map['actor_id'] = Variable<String>(actorId.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (encryptedPayload.present) {
      map['encrypted_payload'] = Variable<String>(encryptedPayload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalOutboxEventsCompanion(')
          ..write('id: $id, ')
          ..write('homeId: $homeId, ')
          ..write('actorId: $actorId, ')
          ..write('eventType: $eventType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('encryptedPayload: $encryptedPayload, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalActivityEventsTable extends LocalActivityEvents
    with TableInfo<$LocalActivityEventsTable, LocalActivityEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalActivityEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _homeIdMeta = const VerificationMeta('homeId');
  @override
  late final GeneratedColumn<String> homeId = GeneratedColumn<String>(
    'home_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actorIdMeta = const VerificationMeta(
    'actorId',
  );
  @override
  late final GeneratedColumn<String> actorId = GeneratedColumn<String>(
    'actor_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('savedLocally'),
  );
  static const VerificationMeta _isPrivateMeta = const VerificationMeta(
    'isPrivate',
  );
  @override
  late final GeneratedColumn<bool> isPrivate = GeneratedColumn<bool>(
    'is_private',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_private" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    homeId,
    actorId,
    eventType,
    payloadJson,
    createdAt,
    syncStatus,
    isPrivate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_activity_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalActivityEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('home_id')) {
      context.handle(
        _homeIdMeta,
        homeId.isAcceptableOrUnknown(data['home_id']!, _homeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_homeIdMeta);
    }
    if (data.containsKey('actor_id')) {
      context.handle(
        _actorIdMeta,
        actorId.isAcceptableOrUnknown(data['actor_id']!, _actorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_actorIdMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('is_private')) {
      context.handle(
        _isPrivateMeta,
        isPrivate.isAcceptableOrUnknown(data['is_private']!, _isPrivateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalActivityEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalActivityEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      homeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}home_id'],
      )!,
      actorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_id'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      isPrivate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_private'],
      )!,
    );
  }

  @override
  $LocalActivityEventsTable createAlias(String alias) {
    return $LocalActivityEventsTable(attachedDatabase, alias);
  }
}

class LocalActivityEvent extends DataClass
    implements Insertable<LocalActivityEvent> {
  final String id;
  final String homeId;
  final String actorId;
  final String eventType;
  final String payloadJson;
  final DateTime createdAt;
  final String syncStatus;
  final bool isPrivate;
  const LocalActivityEvent({
    required this.id,
    required this.homeId,
    required this.actorId,
    required this.eventType,
    required this.payloadJson,
    required this.createdAt,
    required this.syncStatus,
    required this.isPrivate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['home_id'] = Variable<String>(homeId);
    map['actor_id'] = Variable<String>(actorId);
    map['event_type'] = Variable<String>(eventType);
    map['payload_json'] = Variable<String>(payloadJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['sync_status'] = Variable<String>(syncStatus);
    map['is_private'] = Variable<bool>(isPrivate);
    return map;
  }

  LocalActivityEventsCompanion toCompanion(bool nullToAbsent) {
    return LocalActivityEventsCompanion(
      id: Value(id),
      homeId: Value(homeId),
      actorId: Value(actorId),
      eventType: Value(eventType),
      payloadJson: Value(payloadJson),
      createdAt: Value(createdAt),
      syncStatus: Value(syncStatus),
      isPrivate: Value(isPrivate),
    );
  }

  factory LocalActivityEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalActivityEvent(
      id: serializer.fromJson<String>(json['id']),
      homeId: serializer.fromJson<String>(json['homeId']),
      actorId: serializer.fromJson<String>(json['actorId']),
      eventType: serializer.fromJson<String>(json['eventType']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      isPrivate: serializer.fromJson<bool>(json['isPrivate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'homeId': serializer.toJson<String>(homeId),
      'actorId': serializer.toJson<String>(actorId),
      'eventType': serializer.toJson<String>(eventType),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'isPrivate': serializer.toJson<bool>(isPrivate),
    };
  }

  LocalActivityEvent copyWith({
    String? id,
    String? homeId,
    String? actorId,
    String? eventType,
    String? payloadJson,
    DateTime? createdAt,
    String? syncStatus,
    bool? isPrivate,
  }) => LocalActivityEvent(
    id: id ?? this.id,
    homeId: homeId ?? this.homeId,
    actorId: actorId ?? this.actorId,
    eventType: eventType ?? this.eventType,
    payloadJson: payloadJson ?? this.payloadJson,
    createdAt: createdAt ?? this.createdAt,
    syncStatus: syncStatus ?? this.syncStatus,
    isPrivate: isPrivate ?? this.isPrivate,
  );
  LocalActivityEvent copyWithCompanion(LocalActivityEventsCompanion data) {
    return LocalActivityEvent(
      id: data.id.present ? data.id.value : this.id,
      homeId: data.homeId.present ? data.homeId.value : this.homeId,
      actorId: data.actorId.present ? data.actorId.value : this.actorId,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      isPrivate: data.isPrivate.present ? data.isPrivate.value : this.isPrivate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalActivityEvent(')
          ..write('id: $id, ')
          ..write('homeId: $homeId, ')
          ..write('actorId: $actorId, ')
          ..write('eventType: $eventType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('isPrivate: $isPrivate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    homeId,
    actorId,
    eventType,
    payloadJson,
    createdAt,
    syncStatus,
    isPrivate,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalActivityEvent &&
          other.id == this.id &&
          other.homeId == this.homeId &&
          other.actorId == this.actorId &&
          other.eventType == this.eventType &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt &&
          other.syncStatus == this.syncStatus &&
          other.isPrivate == this.isPrivate);
}

class LocalActivityEventsCompanion extends UpdateCompanion<LocalActivityEvent> {
  final Value<String> id;
  final Value<String> homeId;
  final Value<String> actorId;
  final Value<String> eventType;
  final Value<String> payloadJson;
  final Value<DateTime> createdAt;
  final Value<String> syncStatus;
  final Value<bool> isPrivate;
  final Value<int> rowid;
  const LocalActivityEventsCompanion({
    this.id = const Value.absent(),
    this.homeId = const Value.absent(),
    this.actorId = const Value.absent(),
    this.eventType = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.isPrivate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalActivityEventsCompanion.insert({
    required String id,
    required String homeId,
    required String actorId,
    required String eventType,
    required String payloadJson,
    required DateTime createdAt,
    this.syncStatus = const Value.absent(),
    this.isPrivate = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       homeId = Value(homeId),
       actorId = Value(actorId),
       eventType = Value(eventType),
       payloadJson = Value(payloadJson),
       createdAt = Value(createdAt);
  static Insertable<LocalActivityEvent> custom({
    Expression<String>? id,
    Expression<String>? homeId,
    Expression<String>? actorId,
    Expression<String>? eventType,
    Expression<String>? payloadJson,
    Expression<DateTime>? createdAt,
    Expression<String>? syncStatus,
    Expression<bool>? isPrivate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (homeId != null) 'home_id': homeId,
      if (actorId != null) 'actor_id': actorId,
      if (eventType != null) 'event_type': eventType,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (isPrivate != null) 'is_private': isPrivate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalActivityEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? homeId,
    Value<String>? actorId,
    Value<String>? eventType,
    Value<String>? payloadJson,
    Value<DateTime>? createdAt,
    Value<String>? syncStatus,
    Value<bool>? isPrivate,
    Value<int>? rowid,
  }) {
    return LocalActivityEventsCompanion(
      id: id ?? this.id,
      homeId: homeId ?? this.homeId,
      actorId: actorId ?? this.actorId,
      eventType: eventType ?? this.eventType,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isPrivate: isPrivate ?? this.isPrivate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (homeId.present) {
      map['home_id'] = Variable<String>(homeId.value);
    }
    if (actorId.present) {
      map['actor_id'] = Variable<String>(actorId.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (isPrivate.present) {
      map['is_private'] = Variable<bool>(isPrivate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalActivityEventsCompanion(')
          ..write('id: $id, ')
          ..write('homeId: $homeId, ')
          ..write('actorId: $actorId, ')
          ..write('eventType: $eventType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('isPrivate: $isPrivate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalNotificationPreferencesTable extends LocalNotificationPreferences
    with
        TableInfo<
          $LocalNotificationPreferencesTable,
          LocalNotificationPreference
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalNotificationPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('default'),
  );
  static const VerificationMeta _muteSubscriptionsMeta = const VerificationMeta(
    'muteSubscriptions',
  );
  @override
  late final GeneratedColumn<bool> muteSubscriptions = GeneratedColumn<bool>(
    'mute_subscriptions',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("mute_subscriptions" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _muteListsMeta = const VerificationMeta(
    'muteLists',
  );
  @override
  late final GeneratedColumn<bool> muteLists = GeneratedColumn<bool>(
    'mute_lists',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("mute_lists" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _muteExpensesMeta = const VerificationMeta(
    'muteExpenses',
  );
  @override
  late final GeneratedColumn<bool> muteExpenses = GeneratedColumn<bool>(
    'mute_expenses',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("mute_expenses" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _muteHabitsMeta = const VerificationMeta(
    'muteHabits',
  );
  @override
  late final GeneratedColumn<bool> muteHabits = GeneratedColumn<bool>(
    'mute_habits',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("mute_habits" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _muteCalendarMeta = const VerificationMeta(
    'muteCalendar',
  );
  @override
  late final GeneratedColumn<bool> muteCalendar = GeneratedColumn<bool>(
    'mute_calendar',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("mute_calendar" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    muteSubscriptions,
    muteLists,
    muteExpenses,
    muteHabits,
    muteCalendar,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_notification_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalNotificationPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('mute_subscriptions')) {
      context.handle(
        _muteSubscriptionsMeta,
        muteSubscriptions.isAcceptableOrUnknown(
          data['mute_subscriptions']!,
          _muteSubscriptionsMeta,
        ),
      );
    }
    if (data.containsKey('mute_lists')) {
      context.handle(
        _muteListsMeta,
        muteLists.isAcceptableOrUnknown(data['mute_lists']!, _muteListsMeta),
      );
    }
    if (data.containsKey('mute_expenses')) {
      context.handle(
        _muteExpensesMeta,
        muteExpenses.isAcceptableOrUnknown(
          data['mute_expenses']!,
          _muteExpensesMeta,
        ),
      );
    }
    if (data.containsKey('mute_habits')) {
      context.handle(
        _muteHabitsMeta,
        muteHabits.isAcceptableOrUnknown(data['mute_habits']!, _muteHabitsMeta),
      );
    }
    if (data.containsKey('mute_calendar')) {
      context.handle(
        _muteCalendarMeta,
        muteCalendar.isAcceptableOrUnknown(
          data['mute_calendar']!,
          _muteCalendarMeta,
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
  LocalNotificationPreference map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalNotificationPreference(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      muteSubscriptions: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}mute_subscriptions'],
      )!,
      muteLists: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}mute_lists'],
      )!,
      muteExpenses: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}mute_expenses'],
      )!,
      muteHabits: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}mute_habits'],
      )!,
      muteCalendar: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}mute_calendar'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalNotificationPreferencesTable createAlias(String alias) {
    return $LocalNotificationPreferencesTable(attachedDatabase, alias);
  }
}

class LocalNotificationPreference extends DataClass
    implements Insertable<LocalNotificationPreference> {
  final String id;
  final bool muteSubscriptions;
  final bool muteLists;
  final bool muteExpenses;
  final bool muteHabits;
  final bool muteCalendar;
  final DateTime updatedAt;
  const LocalNotificationPreference({
    required this.id,
    required this.muteSubscriptions,
    required this.muteLists,
    required this.muteExpenses,
    required this.muteHabits,
    required this.muteCalendar,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['mute_subscriptions'] = Variable<bool>(muteSubscriptions);
    map['mute_lists'] = Variable<bool>(muteLists);
    map['mute_expenses'] = Variable<bool>(muteExpenses);
    map['mute_habits'] = Variable<bool>(muteHabits);
    map['mute_calendar'] = Variable<bool>(muteCalendar);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalNotificationPreferencesCompanion toCompanion(bool nullToAbsent) {
    return LocalNotificationPreferencesCompanion(
      id: Value(id),
      muteSubscriptions: Value(muteSubscriptions),
      muteLists: Value(muteLists),
      muteExpenses: Value(muteExpenses),
      muteHabits: Value(muteHabits),
      muteCalendar: Value(muteCalendar),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalNotificationPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalNotificationPreference(
      id: serializer.fromJson<String>(json['id']),
      muteSubscriptions: serializer.fromJson<bool>(json['muteSubscriptions']),
      muteLists: serializer.fromJson<bool>(json['muteLists']),
      muteExpenses: serializer.fromJson<bool>(json['muteExpenses']),
      muteHabits: serializer.fromJson<bool>(json['muteHabits']),
      muteCalendar: serializer.fromJson<bool>(json['muteCalendar']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'muteSubscriptions': serializer.toJson<bool>(muteSubscriptions),
      'muteLists': serializer.toJson<bool>(muteLists),
      'muteExpenses': serializer.toJson<bool>(muteExpenses),
      'muteHabits': serializer.toJson<bool>(muteHabits),
      'muteCalendar': serializer.toJson<bool>(muteCalendar),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalNotificationPreference copyWith({
    String? id,
    bool? muteSubscriptions,
    bool? muteLists,
    bool? muteExpenses,
    bool? muteHabits,
    bool? muteCalendar,
    DateTime? updatedAt,
  }) => LocalNotificationPreference(
    id: id ?? this.id,
    muteSubscriptions: muteSubscriptions ?? this.muteSubscriptions,
    muteLists: muteLists ?? this.muteLists,
    muteExpenses: muteExpenses ?? this.muteExpenses,
    muteHabits: muteHabits ?? this.muteHabits,
    muteCalendar: muteCalendar ?? this.muteCalendar,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalNotificationPreference copyWithCompanion(
    LocalNotificationPreferencesCompanion data,
  ) {
    return LocalNotificationPreference(
      id: data.id.present ? data.id.value : this.id,
      muteSubscriptions: data.muteSubscriptions.present
          ? data.muteSubscriptions.value
          : this.muteSubscriptions,
      muteLists: data.muteLists.present ? data.muteLists.value : this.muteLists,
      muteExpenses: data.muteExpenses.present
          ? data.muteExpenses.value
          : this.muteExpenses,
      muteHabits: data.muteHabits.present
          ? data.muteHabits.value
          : this.muteHabits,
      muteCalendar: data.muteCalendar.present
          ? data.muteCalendar.value
          : this.muteCalendar,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalNotificationPreference(')
          ..write('id: $id, ')
          ..write('muteSubscriptions: $muteSubscriptions, ')
          ..write('muteLists: $muteLists, ')
          ..write('muteExpenses: $muteExpenses, ')
          ..write('muteHabits: $muteHabits, ')
          ..write('muteCalendar: $muteCalendar, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    muteSubscriptions,
    muteLists,
    muteExpenses,
    muteHabits,
    muteCalendar,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalNotificationPreference &&
          other.id == this.id &&
          other.muteSubscriptions == this.muteSubscriptions &&
          other.muteLists == this.muteLists &&
          other.muteExpenses == this.muteExpenses &&
          other.muteHabits == this.muteHabits &&
          other.muteCalendar == this.muteCalendar &&
          other.updatedAt == this.updatedAt);
}

class LocalNotificationPreferencesCompanion
    extends UpdateCompanion<LocalNotificationPreference> {
  final Value<String> id;
  final Value<bool> muteSubscriptions;
  final Value<bool> muteLists;
  final Value<bool> muteExpenses;
  final Value<bool> muteHabits;
  final Value<bool> muteCalendar;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalNotificationPreferencesCompanion({
    this.id = const Value.absent(),
    this.muteSubscriptions = const Value.absent(),
    this.muteLists = const Value.absent(),
    this.muteExpenses = const Value.absent(),
    this.muteHabits = const Value.absent(),
    this.muteCalendar = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalNotificationPreferencesCompanion.insert({
    this.id = const Value.absent(),
    this.muteSubscriptions = const Value.absent(),
    this.muteLists = const Value.absent(),
    this.muteExpenses = const Value.absent(),
    this.muteHabits = const Value.absent(),
    this.muteCalendar = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : updatedAt = Value(updatedAt);
  static Insertable<LocalNotificationPreference> custom({
    Expression<String>? id,
    Expression<bool>? muteSubscriptions,
    Expression<bool>? muteLists,
    Expression<bool>? muteExpenses,
    Expression<bool>? muteHabits,
    Expression<bool>? muteCalendar,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (muteSubscriptions != null) 'mute_subscriptions': muteSubscriptions,
      if (muteLists != null) 'mute_lists': muteLists,
      if (muteExpenses != null) 'mute_expenses': muteExpenses,
      if (muteHabits != null) 'mute_habits': muteHabits,
      if (muteCalendar != null) 'mute_calendar': muteCalendar,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalNotificationPreferencesCompanion copyWith({
    Value<String>? id,
    Value<bool>? muteSubscriptions,
    Value<bool>? muteLists,
    Value<bool>? muteExpenses,
    Value<bool>? muteHabits,
    Value<bool>? muteCalendar,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalNotificationPreferencesCompanion(
      id: id ?? this.id,
      muteSubscriptions: muteSubscriptions ?? this.muteSubscriptions,
      muteLists: muteLists ?? this.muteLists,
      muteExpenses: muteExpenses ?? this.muteExpenses,
      muteHabits: muteHabits ?? this.muteHabits,
      muteCalendar: muteCalendar ?? this.muteCalendar,
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
    if (muteSubscriptions.present) {
      map['mute_subscriptions'] = Variable<bool>(muteSubscriptions.value);
    }
    if (muteLists.present) {
      map['mute_lists'] = Variable<bool>(muteLists.value);
    }
    if (muteExpenses.present) {
      map['mute_expenses'] = Variable<bool>(muteExpenses.value);
    }
    if (muteHabits.present) {
      map['mute_habits'] = Variable<bool>(muteHabits.value);
    }
    if (muteCalendar.present) {
      map['mute_calendar'] = Variable<bool>(muteCalendar.value);
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
    return (StringBuffer('LocalNotificationPreferencesCompanion(')
          ..write('id: $id, ')
          ..write('muteSubscriptions: $muteSubscriptions, ')
          ..write('muteLists: $muteLists, ')
          ..write('muteExpenses: $muteExpenses, ')
          ..write('muteHabits: $muteHabits, ')
          ..write('muteCalendar: $muteCalendar, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalRoadmapItemsTable extends LocalRoadmapItems
    with TableInfo<$LocalRoadmapItemsTable, LocalRoadmapItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalRoadmapItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _homeIdMeta = const VerificationMeta('homeId');
  @override
  late final GeneratedColumn<String> homeId = GeneratedColumn<String>(
    'home_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
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
  static const VerificationMeta _isCompletedMeta = const VerificationMeta(
    'isCompleted',
  );
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    homeId,
    title,
    description,
    isCompleted,
    createdAt,
    createdBy,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_roadmap_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalRoadmapItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('home_id')) {
      context.handle(
        _homeIdMeta,
        homeId.isAcceptableOrUnknown(data['home_id']!, _homeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_homeIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
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
    if (data.containsKey('is_completed')) {
      context.handle(
        _isCompletedMeta,
        isCompleted.isAcceptableOrUnknown(
          data['is_completed']!,
          _isCompletedMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalRoadmapItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalRoadmapItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      homeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}home_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      isCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_completed'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $LocalRoadmapItemsTable createAlias(String alias) {
    return $LocalRoadmapItemsTable(attachedDatabase, alias);
  }
}

class LocalRoadmapItem extends DataClass
    implements Insertable<LocalRoadmapItem> {
  final String id;
  final String homeId;
  final String title;
  final String? description;
  final bool isCompleted;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? completedAt;
  const LocalRoadmapItem({
    required this.id,
    required this.homeId,
    required this.title,
    this.description,
    required this.isCompleted,
    required this.createdAt,
    required this.createdBy,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['home_id'] = Variable<String>(homeId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_completed'] = Variable<bool>(isCompleted);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['created_by'] = Variable<String>(createdBy);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  LocalRoadmapItemsCompanion toCompanion(bool nullToAbsent) {
    return LocalRoadmapItemsCompanion(
      id: Value(id),
      homeId: Value(homeId),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isCompleted: Value(isCompleted),
      createdAt: Value(createdAt),
      createdBy: Value(createdBy),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory LocalRoadmapItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalRoadmapItem(
      id: serializer.fromJson<String>(json['id']),
      homeId: serializer.fromJson<String>(json['homeId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'homeId': serializer.toJson<String>(homeId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'createdBy': serializer.toJson<String>(createdBy),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  LocalRoadmapItem copyWith({
    String? id,
    String? homeId,
    String? title,
    Value<String?> description = const Value.absent(),
    bool? isCompleted,
    DateTime? createdAt,
    String? createdBy,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => LocalRoadmapItem(
    id: id ?? this.id,
    homeId: homeId ?? this.homeId,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    isCompleted: isCompleted ?? this.isCompleted,
    createdAt: createdAt ?? this.createdAt,
    createdBy: createdBy ?? this.createdBy,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  LocalRoadmapItem copyWithCompanion(LocalRoadmapItemsCompanion data) {
    return LocalRoadmapItem(
      id: data.id.present ? data.id.value : this.id,
      homeId: data.homeId.present ? data.homeId.value : this.homeId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      isCompleted: data.isCompleted.present
          ? data.isCompleted.value
          : this.isCompleted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalRoadmapItem(')
          ..write('id: $id, ')
          ..write('homeId: $homeId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    homeId,
    title,
    description,
    isCompleted,
    createdAt,
    createdBy,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalRoadmapItem &&
          other.id == this.id &&
          other.homeId == this.homeId &&
          other.title == this.title &&
          other.description == this.description &&
          other.isCompleted == this.isCompleted &&
          other.createdAt == this.createdAt &&
          other.createdBy == this.createdBy &&
          other.completedAt == this.completedAt);
}

class LocalRoadmapItemsCompanion extends UpdateCompanion<LocalRoadmapItem> {
  final Value<String> id;
  final Value<String> homeId;
  final Value<String> title;
  final Value<String?> description;
  final Value<bool> isCompleted;
  final Value<DateTime> createdAt;
  final Value<String> createdBy;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const LocalRoadmapItemsCompanion({
    this.id = const Value.absent(),
    this.homeId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalRoadmapItemsCompanion.insert({
    required String id,
    required String homeId,
    required String title,
    this.description = const Value.absent(),
    this.isCompleted = const Value.absent(),
    required DateTime createdAt,
    required String createdBy,
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       homeId = Value(homeId),
       title = Value(title),
       createdAt = Value(createdAt),
       createdBy = Value(createdBy);
  static Insertable<LocalRoadmapItem> custom({
    Expression<String>? id,
    Expression<String>? homeId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<bool>? isCompleted,
    Expression<DateTime>? createdAt,
    Expression<String>? createdBy,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (homeId != null) 'home_id': homeId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (createdAt != null) 'created_at': createdAt,
      if (createdBy != null) 'created_by': createdBy,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalRoadmapItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? homeId,
    Value<String>? title,
    Value<String?>? description,
    Value<bool>? isCompleted,
    Value<DateTime>? createdAt,
    Value<String>? createdBy,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return LocalRoadmapItemsCompanion(
      id: id ?? this.id,
      homeId: homeId ?? this.homeId,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (homeId.present) {
      map['home_id'] = Variable<String>(homeId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalRoadmapItemsCompanion(')
          ..write('id: $id, ')
          ..write('homeId: $homeId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalRoutinesTable extends LocalRoutines
    with TableInfo<$LocalRoutinesTable, LocalRoutine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalRoutinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _homeIdMeta = const VerificationMeta('homeId');
  @override
  late final GeneratedColumn<String> homeId = GeneratedColumn<String>(
    'home_id',
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
  static const VerificationMeta _daysJsonMeta = const VerificationMeta(
    'daysJson',
  );
  @override
  late final GeneratedColumn<String> daysJson = GeneratedColumn<String>(
    'days_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, homeId, name, daysJson, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_routines';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalRoutine> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('home_id')) {
      context.handle(
        _homeIdMeta,
        homeId.isAcceptableOrUnknown(data['home_id']!, _homeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_homeIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('days_json')) {
      context.handle(
        _daysJsonMeta,
        daysJson.isAcceptableOrUnknown(data['days_json']!, _daysJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_daysJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalRoutine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalRoutine(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      homeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}home_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      daysJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}days_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalRoutinesTable createAlias(String alias) {
    return $LocalRoutinesTable(attachedDatabase, alias);
  }
}

class LocalRoutine extends DataClass implements Insertable<LocalRoutine> {
  final String id;
  final String homeId;
  final String name;
  final String daysJson;
  final DateTime createdAt;
  const LocalRoutine({
    required this.id,
    required this.homeId,
    required this.name,
    required this.daysJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['home_id'] = Variable<String>(homeId);
    map['name'] = Variable<String>(name);
    map['days_json'] = Variable<String>(daysJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalRoutinesCompanion toCompanion(bool nullToAbsent) {
    return LocalRoutinesCompanion(
      id: Value(id),
      homeId: Value(homeId),
      name: Value(name),
      daysJson: Value(daysJson),
      createdAt: Value(createdAt),
    );
  }

  factory LocalRoutine.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalRoutine(
      id: serializer.fromJson<String>(json['id']),
      homeId: serializer.fromJson<String>(json['homeId']),
      name: serializer.fromJson<String>(json['name']),
      daysJson: serializer.fromJson<String>(json['daysJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'homeId': serializer.toJson<String>(homeId),
      'name': serializer.toJson<String>(name),
      'daysJson': serializer.toJson<String>(daysJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalRoutine copyWith({
    String? id,
    String? homeId,
    String? name,
    String? daysJson,
    DateTime? createdAt,
  }) => LocalRoutine(
    id: id ?? this.id,
    homeId: homeId ?? this.homeId,
    name: name ?? this.name,
    daysJson: daysJson ?? this.daysJson,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalRoutine copyWithCompanion(LocalRoutinesCompanion data) {
    return LocalRoutine(
      id: data.id.present ? data.id.value : this.id,
      homeId: data.homeId.present ? data.homeId.value : this.homeId,
      name: data.name.present ? data.name.value : this.name,
      daysJson: data.daysJson.present ? data.daysJson.value : this.daysJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalRoutine(')
          ..write('id: $id, ')
          ..write('homeId: $homeId, ')
          ..write('name: $name, ')
          ..write('daysJson: $daysJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, homeId, name, daysJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalRoutine &&
          other.id == this.id &&
          other.homeId == this.homeId &&
          other.name == this.name &&
          other.daysJson == this.daysJson &&
          other.createdAt == this.createdAt);
}

class LocalRoutinesCompanion extends UpdateCompanion<LocalRoutine> {
  final Value<String> id;
  final Value<String> homeId;
  final Value<String> name;
  final Value<String> daysJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalRoutinesCompanion({
    this.id = const Value.absent(),
    this.homeId = const Value.absent(),
    this.name = const Value.absent(),
    this.daysJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalRoutinesCompanion.insert({
    required String id,
    required String homeId,
    required String name,
    required String daysJson,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       homeId = Value(homeId),
       name = Value(name),
       daysJson = Value(daysJson),
       createdAt = Value(createdAt);
  static Insertable<LocalRoutine> custom({
    Expression<String>? id,
    Expression<String>? homeId,
    Expression<String>? name,
    Expression<String>? daysJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (homeId != null) 'home_id': homeId,
      if (name != null) 'name': name,
      if (daysJson != null) 'days_json': daysJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalRoutinesCompanion copyWith({
    Value<String>? id,
    Value<String>? homeId,
    Value<String>? name,
    Value<String>? daysJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalRoutinesCompanion(
      id: id ?? this.id,
      homeId: homeId ?? this.homeId,
      name: name ?? this.name,
      daysJson: daysJson ?? this.daysJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (homeId.present) {
      map['home_id'] = Variable<String>(homeId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (daysJson.present) {
      map['days_json'] = Variable<String>(daysJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalRoutinesCompanion(')
          ..write('id: $id, ')
          ..write('homeId: $homeId, ')
          ..write('name: $name, ')
          ..write('daysJson: $daysJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalRoutineEventsTable extends LocalRoutineEvents
    with TableInfo<$LocalRoutineEventsTable, LocalRoutineEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalRoutineEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _routineIdMeta = const VerificationMeta(
    'routineId',
  );
  @override
  late final GeneratedColumn<String> routineId = GeneratedColumn<String>(
    'routine_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _homeIdMeta = const VerificationMeta('homeId');
  @override
  late final GeneratedColumn<String> homeId = GeneratedColumn<String>(
    'home_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMinutesMeta = const VerificationMeta(
    'startMinutes',
  );
  @override
  late final GeneratedColumn<int> startMinutes = GeneratedColumn<int>(
    'start_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMinutesMeta = const VerificationMeta(
    'endMinutes',
  );
  @override
  late final GeneratedColumn<int> endMinutes = GeneratedColumn<int>(
    'end_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    routineId,
    homeId,
    title,
    startMinutes,
    endMinutes,
    category,
    notes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_routine_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalRoutineEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('routine_id')) {
      context.handle(
        _routineIdMeta,
        routineId.isAcceptableOrUnknown(data['routine_id']!, _routineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_routineIdMeta);
    }
    if (data.containsKey('home_id')) {
      context.handle(
        _homeIdMeta,
        homeId.isAcceptableOrUnknown(data['home_id']!, _homeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_homeIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('start_minutes')) {
      context.handle(
        _startMinutesMeta,
        startMinutes.isAcceptableOrUnknown(
          data['start_minutes']!,
          _startMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startMinutesMeta);
    }
    if (data.containsKey('end_minutes')) {
      context.handle(
        _endMinutesMeta,
        endMinutes.isAcceptableOrUnknown(data['end_minutes']!, _endMinutesMeta),
      );
    } else if (isInserting) {
      context.missing(_endMinutesMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalRoutineEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalRoutineEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      routineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}routine_id'],
      )!,
      homeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}home_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      startMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_minutes'],
      )!,
      endMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_minutes'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalRoutineEventsTable createAlias(String alias) {
    return $LocalRoutineEventsTable(attachedDatabase, alias);
  }
}

class LocalRoutineEvent extends DataClass
    implements Insertable<LocalRoutineEvent> {
  final String id;
  final String routineId;
  final String homeId;
  final String title;
  final int startMinutes;
  final int endMinutes;
  final String? category;
  final String? notes;
  final DateTime createdAt;
  const LocalRoutineEvent({
    required this.id,
    required this.routineId,
    required this.homeId,
    required this.title,
    required this.startMinutes,
    required this.endMinutes,
    this.category,
    this.notes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['routine_id'] = Variable<String>(routineId);
    map['home_id'] = Variable<String>(homeId);
    map['title'] = Variable<String>(title);
    map['start_minutes'] = Variable<int>(startMinutes);
    map['end_minutes'] = Variable<int>(endMinutes);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalRoutineEventsCompanion toCompanion(bool nullToAbsent) {
    return LocalRoutineEventsCompanion(
      id: Value(id),
      routineId: Value(routineId),
      homeId: Value(homeId),
      title: Value(title),
      startMinutes: Value(startMinutes),
      endMinutes: Value(endMinutes),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory LocalRoutineEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalRoutineEvent(
      id: serializer.fromJson<String>(json['id']),
      routineId: serializer.fromJson<String>(json['routineId']),
      homeId: serializer.fromJson<String>(json['homeId']),
      title: serializer.fromJson<String>(json['title']),
      startMinutes: serializer.fromJson<int>(json['startMinutes']),
      endMinutes: serializer.fromJson<int>(json['endMinutes']),
      category: serializer.fromJson<String?>(json['category']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'routineId': serializer.toJson<String>(routineId),
      'homeId': serializer.toJson<String>(homeId),
      'title': serializer.toJson<String>(title),
      'startMinutes': serializer.toJson<int>(startMinutes),
      'endMinutes': serializer.toJson<int>(endMinutes),
      'category': serializer.toJson<String?>(category),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalRoutineEvent copyWith({
    String? id,
    String? routineId,
    String? homeId,
    String? title,
    int? startMinutes,
    int? endMinutes,
    Value<String?> category = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
  }) => LocalRoutineEvent(
    id: id ?? this.id,
    routineId: routineId ?? this.routineId,
    homeId: homeId ?? this.homeId,
    title: title ?? this.title,
    startMinutes: startMinutes ?? this.startMinutes,
    endMinutes: endMinutes ?? this.endMinutes,
    category: category.present ? category.value : this.category,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalRoutineEvent copyWithCompanion(LocalRoutineEventsCompanion data) {
    return LocalRoutineEvent(
      id: data.id.present ? data.id.value : this.id,
      routineId: data.routineId.present ? data.routineId.value : this.routineId,
      homeId: data.homeId.present ? data.homeId.value : this.homeId,
      title: data.title.present ? data.title.value : this.title,
      startMinutes: data.startMinutes.present
          ? data.startMinutes.value
          : this.startMinutes,
      endMinutes: data.endMinutes.present
          ? data.endMinutes.value
          : this.endMinutes,
      category: data.category.present ? data.category.value : this.category,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalRoutineEvent(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('homeId: $homeId, ')
          ..write('title: $title, ')
          ..write('startMinutes: $startMinutes, ')
          ..write('endMinutes: $endMinutes, ')
          ..write('category: $category, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    routineId,
    homeId,
    title,
    startMinutes,
    endMinutes,
    category,
    notes,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalRoutineEvent &&
          other.id == this.id &&
          other.routineId == this.routineId &&
          other.homeId == this.homeId &&
          other.title == this.title &&
          other.startMinutes == this.startMinutes &&
          other.endMinutes == this.endMinutes &&
          other.category == this.category &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class LocalRoutineEventsCompanion extends UpdateCompanion<LocalRoutineEvent> {
  final Value<String> id;
  final Value<String> routineId;
  final Value<String> homeId;
  final Value<String> title;
  final Value<int> startMinutes;
  final Value<int> endMinutes;
  final Value<String?> category;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalRoutineEventsCompanion({
    this.id = const Value.absent(),
    this.routineId = const Value.absent(),
    this.homeId = const Value.absent(),
    this.title = const Value.absent(),
    this.startMinutes = const Value.absent(),
    this.endMinutes = const Value.absent(),
    this.category = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalRoutineEventsCompanion.insert({
    required String id,
    required String routineId,
    required String homeId,
    required String title,
    required int startMinutes,
    required int endMinutes,
    this.category = const Value.absent(),
    this.notes = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       routineId = Value(routineId),
       homeId = Value(homeId),
       title = Value(title),
       startMinutes = Value(startMinutes),
       endMinutes = Value(endMinutes),
       createdAt = Value(createdAt);
  static Insertable<LocalRoutineEvent> custom({
    Expression<String>? id,
    Expression<String>? routineId,
    Expression<String>? homeId,
    Expression<String>? title,
    Expression<int>? startMinutes,
    Expression<int>? endMinutes,
    Expression<String>? category,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (routineId != null) 'routine_id': routineId,
      if (homeId != null) 'home_id': homeId,
      if (title != null) 'title': title,
      if (startMinutes != null) 'start_minutes': startMinutes,
      if (endMinutes != null) 'end_minutes': endMinutes,
      if (category != null) 'category': category,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalRoutineEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? routineId,
    Value<String>? homeId,
    Value<String>? title,
    Value<int>? startMinutes,
    Value<int>? endMinutes,
    Value<String?>? category,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalRoutineEventsCompanion(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      homeId: homeId ?? this.homeId,
      title: title ?? this.title,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (routineId.present) {
      map['routine_id'] = Variable<String>(routineId.value);
    }
    if (homeId.present) {
      map['home_id'] = Variable<String>(homeId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (startMinutes.present) {
      map['start_minutes'] = Variable<int>(startMinutes.value);
    }
    if (endMinutes.present) {
      map['end_minutes'] = Variable<int>(endMinutes.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalRoutineEventsCompanion(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('homeId: $homeId, ')
          ..write('title: $title, ')
          ..write('startMinutes: $startMinutes, ')
          ..write('endMinutes: $endMinutes, ')
          ..write('category: $category, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalHomesTable localHomes = $LocalHomesTable(this);
  late final $LocalListsTable localLists = $LocalListsTable(this);
  late final $LocalListItemsTable localListItems = $LocalListItemsTable(this);
  late final $LocalSubscriptionsTable localSubscriptions =
      $LocalSubscriptionsTable(this);
  late final $LocalExpensesTable localExpenses = $LocalExpensesTable(this);
  late final $LocalHabitsTable localHabits = $LocalHabitsTable(this);
  late final $LocalHabitCheckinsTable localHabitCheckins =
      $LocalHabitCheckinsTable(this);
  late final $LocalCalendarEventsTable localCalendarEvents =
      $LocalCalendarEventsTable(this);
  late final $LocalOutboxEventsTable localOutboxEvents =
      $LocalOutboxEventsTable(this);
  late final $LocalActivityEventsTable localActivityEvents =
      $LocalActivityEventsTable(this);
  late final $LocalNotificationPreferencesTable localNotificationPreferences =
      $LocalNotificationPreferencesTable(this);
  late final $LocalRoadmapItemsTable localRoadmapItems =
      $LocalRoadmapItemsTable(this);
  late final $LocalRoutinesTable localRoutines = $LocalRoutinesTable(this);
  late final $LocalRoutineEventsTable localRoutineEvents =
      $LocalRoutineEventsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localHomes,
    localLists,
    localListItems,
    localSubscriptions,
    localExpenses,
    localHabits,
    localHabitCheckins,
    localCalendarEvents,
    localOutboxEvents,
    localActivityEvents,
    localNotificationPreferences,
    localRoadmapItems,
    localRoutines,
    localRoutineEvents,
  ];
}

typedef $$LocalHomesTableCreateCompanionBuilder =
    LocalHomesCompanion Function({
      required String id,
      required String name,
      Value<String?> description,
      Value<String?> icon,
      Value<String> currency,
      required DateTime createdAt,
      required String createdBy,
      Value<int> rowid,
    });
typedef $$LocalHomesTableUpdateCompanionBuilder =
    LocalHomesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> description,
      Value<String?> icon,
      Value<String> currency,
      Value<DateTime> createdAt,
      Value<String> createdBy,
      Value<int> rowid,
    });

class $$LocalHomesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalHomesTable> {
  $$LocalHomesTableFilterComposer({
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

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalHomesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalHomesTable> {
  $$LocalHomesTableOrderingComposer({
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

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalHomesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalHomesTable> {
  $$LocalHomesTableAnnotationComposer({
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

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);
}

class $$LocalHomesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalHomesTable,
          LocalHome,
          $$LocalHomesTableFilterComposer,
          $$LocalHomesTableOrderingComposer,
          $$LocalHomesTableAnnotationComposer,
          $$LocalHomesTableCreateCompanionBuilder,
          $$LocalHomesTableUpdateCompanionBuilder,
          (
            LocalHome,
            BaseReferences<_$AppDatabase, $LocalHomesTable, LocalHome>,
          ),
          LocalHome,
          PrefetchHooks Function()
        > {
  $$LocalHomesTableTableManager(_$AppDatabase db, $LocalHomesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalHomesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalHomesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalHomesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalHomesCompanion(
                id: id,
                name: name,
                description: description,
                icon: icon,
                currency: currency,
                createdAt: createdAt,
                createdBy: createdBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> description = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String> currency = const Value.absent(),
                required DateTime createdAt,
                required String createdBy,
                Value<int> rowid = const Value.absent(),
              }) => LocalHomesCompanion.insert(
                id: id,
                name: name,
                description: description,
                icon: icon,
                currency: currency,
                createdAt: createdAt,
                createdBy: createdBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalHomesTable, LocalHome>(table),
                  BaseReferences<_$AppDatabase, $LocalHomesTable, LocalHome>(
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

typedef $$LocalHomesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalHomesTable,
      LocalHome,
      $$LocalHomesTableFilterComposer,
      $$LocalHomesTableOrderingComposer,
      $$LocalHomesTableAnnotationComposer,
      $$LocalHomesTableCreateCompanionBuilder,
      $$LocalHomesTableUpdateCompanionBuilder,
      (LocalHome, BaseReferences<_$AppDatabase, $LocalHomesTable, LocalHome>),
      LocalHome,
      PrefetchHooks Function()
    >;
typedef $$LocalListsTableCreateCompanionBuilder =
    LocalListsCompanion Function({
      required String id,
      required String homeId,
      required String name,
      Value<bool> isArchived,
      required DateTime createdAt,
      required String createdBy,
      Value<int> rowid,
    });
typedef $$LocalListsTableUpdateCompanionBuilder =
    LocalListsCompanion Function({
      Value<String> id,
      Value<String> homeId,
      Value<String> name,
      Value<bool> isArchived,
      Value<DateTime> createdAt,
      Value<String> createdBy,
      Value<int> rowid,
    });

class $$LocalListsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalListsTable> {
  $$LocalListsTableFilterComposer({
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

  ColumnFilters<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalListsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalListsTable> {
  $$LocalListsTableOrderingComposer({
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

  ColumnOrderings<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalListsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalListsTable> {
  $$LocalListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get homeId =>
      $composableBuilder(column: $table.homeId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);
}

class $$LocalListsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalListsTable,
          LocalList,
          $$LocalListsTableFilterComposer,
          $$LocalListsTableOrderingComposer,
          $$LocalListsTableAnnotationComposer,
          $$LocalListsTableCreateCompanionBuilder,
          $$LocalListsTableUpdateCompanionBuilder,
          (
            LocalList,
            BaseReferences<_$AppDatabase, $LocalListsTable, LocalList>,
          ),
          LocalList,
          PrefetchHooks Function()
        > {
  $$LocalListsTableTableManager(_$AppDatabase db, $LocalListsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> homeId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalListsCompanion(
                id: id,
                homeId: homeId,
                name: name,
                isArchived: isArchived,
                createdAt: createdAt,
                createdBy: createdBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String homeId,
                required String name,
                Value<bool> isArchived = const Value.absent(),
                required DateTime createdAt,
                required String createdBy,
                Value<int> rowid = const Value.absent(),
              }) => LocalListsCompanion.insert(
                id: id,
                homeId: homeId,
                name: name,
                isArchived: isArchived,
                createdAt: createdAt,
                createdBy: createdBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalListsTable, LocalList>(table),
                  BaseReferences<_$AppDatabase, $LocalListsTable, LocalList>(
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

typedef $$LocalListsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalListsTable,
      LocalList,
      $$LocalListsTableFilterComposer,
      $$LocalListsTableOrderingComposer,
      $$LocalListsTableAnnotationComposer,
      $$LocalListsTableCreateCompanionBuilder,
      $$LocalListsTableUpdateCompanionBuilder,
      (LocalList, BaseReferences<_$AppDatabase, $LocalListsTable, LocalList>),
      LocalList,
      PrefetchHooks Function()
    >;
typedef $$LocalListItemsTableCreateCompanionBuilder =
    LocalListItemsCompanion Function({
      required String id,
      required String homeId,
      required String listId,
      required String title,
      Value<String?> notes,
      Value<bool> isCompleted,
      Value<DateTime?> completedAt,
      Value<String?> completedBy,
      required DateTime createdAt,
      required String createdBy,
      Value<int> rowid,
    });
typedef $$LocalListItemsTableUpdateCompanionBuilder =
    LocalListItemsCompanion Function({
      Value<String> id,
      Value<String> homeId,
      Value<String> listId,
      Value<String> title,
      Value<String?> notes,
      Value<bool> isCompleted,
      Value<DateTime?> completedAt,
      Value<String?> completedBy,
      Value<DateTime> createdAt,
      Value<String> createdBy,
      Value<int> rowid,
    });

class $$LocalListItemsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalListItemsTable> {
  $$LocalListItemsTableFilterComposer({
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

  ColumnFilters<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedBy => $composableBuilder(
    column: $table.completedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalListItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalListItemsTable> {
  $$LocalListItemsTableOrderingComposer({
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

  ColumnOrderings<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedBy => $composableBuilder(
    column: $table.completedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalListItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalListItemsTable> {
  $$LocalListItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get homeId =>
      $composableBuilder(column: $table.homeId, builder: (column) => column);

  GeneratedColumn<String> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get completedBy => $composableBuilder(
    column: $table.completedBy,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);
}

class $$LocalListItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalListItemsTable,
          LocalListItem,
          $$LocalListItemsTableFilterComposer,
          $$LocalListItemsTableOrderingComposer,
          $$LocalListItemsTableAnnotationComposer,
          $$LocalListItemsTableCreateCompanionBuilder,
          $$LocalListItemsTableUpdateCompanionBuilder,
          (
            LocalListItem,
            BaseReferences<_$AppDatabase, $LocalListItemsTable, LocalListItem>,
          ),
          LocalListItem,
          PrefetchHooks Function()
        > {
  $$LocalListItemsTableTableManager(
    _$AppDatabase db,
    $LocalListItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalListItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalListItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalListItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> homeId = const Value.absent(),
                Value<String> listId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> completedBy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalListItemsCompanion(
                id: id,
                homeId: homeId,
                listId: listId,
                title: title,
                notes: notes,
                isCompleted: isCompleted,
                completedAt: completedAt,
                completedBy: completedBy,
                createdAt: createdAt,
                createdBy: createdBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String homeId,
                required String listId,
                required String title,
                Value<String?> notes = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> completedBy = const Value.absent(),
                required DateTime createdAt,
                required String createdBy,
                Value<int> rowid = const Value.absent(),
              }) => LocalListItemsCompanion.insert(
                id: id,
                homeId: homeId,
                listId: listId,
                title: title,
                notes: notes,
                isCompleted: isCompleted,
                completedAt: completedAt,
                completedBy: completedBy,
                createdAt: createdAt,
                createdBy: createdBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalListItemsTable, LocalListItem>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalListItemsTable,
                    LocalListItem
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalListItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalListItemsTable,
      LocalListItem,
      $$LocalListItemsTableFilterComposer,
      $$LocalListItemsTableOrderingComposer,
      $$LocalListItemsTableAnnotationComposer,
      $$LocalListItemsTableCreateCompanionBuilder,
      $$LocalListItemsTableUpdateCompanionBuilder,
      (
        LocalListItem,
        BaseReferences<_$AppDatabase, $LocalListItemsTable, LocalListItem>,
      ),
      LocalListItem,
      PrefetchHooks Function()
    >;
typedef $$LocalSubscriptionsTableCreateCompanionBuilder =
    LocalSubscriptionsCompanion Function({
      required String id,
      required String homeId,
      required String name,
      required double amount,
      Value<String> currency,
      Value<String> billingCycle,
      required DateTime nextBillingDate,
      Value<String?> category,
      Value<bool> isActive,
      Value<bool> isPrivate,
      Value<String?> createdBy,
      required DateTime createdAt,
      Value<DateTime?> endDate,
      Value<String?> paidBy,
      Value<String?> financedThrough,
      Value<int?> totalInstallments,
      Value<int?> paidInstallments,
      Value<int> rowid,
    });
typedef $$LocalSubscriptionsTableUpdateCompanionBuilder =
    LocalSubscriptionsCompanion Function({
      Value<String> id,
      Value<String> homeId,
      Value<String> name,
      Value<double> amount,
      Value<String> currency,
      Value<String> billingCycle,
      Value<DateTime> nextBillingDate,
      Value<String?> category,
      Value<bool> isActive,
      Value<bool> isPrivate,
      Value<String?> createdBy,
      Value<DateTime> createdAt,
      Value<DateTime?> endDate,
      Value<String?> paidBy,
      Value<String?> financedThrough,
      Value<int?> totalInstallments,
      Value<int?> paidInstallments,
      Value<int> rowid,
    });

class $$LocalSubscriptionsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSubscriptionsTable> {
  $$LocalSubscriptionsTableFilterComposer({
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

  ColumnFilters<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get billingCycle => $composableBuilder(
    column: $table.billingCycle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextBillingDate => $composableBuilder(
    column: $table.nextBillingDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPrivate => $composableBuilder(
    column: $table.isPrivate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paidBy => $composableBuilder(
    column: $table.paidBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get financedThrough => $composableBuilder(
    column: $table.financedThrough,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalInstallments => $composableBuilder(
    column: $table.totalInstallments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paidInstallments => $composableBuilder(
    column: $table.paidInstallments,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalSubscriptionsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSubscriptionsTable> {
  $$LocalSubscriptionsTableOrderingComposer({
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

  ColumnOrderings<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get billingCycle => $composableBuilder(
    column: $table.billingCycle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextBillingDate => $composableBuilder(
    column: $table.nextBillingDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPrivate => $composableBuilder(
    column: $table.isPrivate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paidBy => $composableBuilder(
    column: $table.paidBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get financedThrough => $composableBuilder(
    column: $table.financedThrough,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalInstallments => $composableBuilder(
    column: $table.totalInstallments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paidInstallments => $composableBuilder(
    column: $table.paidInstallments,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSubscriptionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSubscriptionsTable> {
  $$LocalSubscriptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get homeId =>
      $composableBuilder(column: $table.homeId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get billingCycle => $composableBuilder(
    column: $table.billingCycle,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextBillingDate => $composableBuilder(
    column: $table.nextBillingDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<bool> get isPrivate =>
      $composableBuilder(column: $table.isPrivate, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<String> get paidBy =>
      $composableBuilder(column: $table.paidBy, builder: (column) => column);

  GeneratedColumn<String> get financedThrough => $composableBuilder(
    column: $table.financedThrough,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalInstallments => $composableBuilder(
    column: $table.totalInstallments,
    builder: (column) => column,
  );

  GeneratedColumn<int> get paidInstallments => $composableBuilder(
    column: $table.paidInstallments,
    builder: (column) => column,
  );
}

class $$LocalSubscriptionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSubscriptionsTable,
          LocalSubscription,
          $$LocalSubscriptionsTableFilterComposer,
          $$LocalSubscriptionsTableOrderingComposer,
          $$LocalSubscriptionsTableAnnotationComposer,
          $$LocalSubscriptionsTableCreateCompanionBuilder,
          $$LocalSubscriptionsTableUpdateCompanionBuilder,
          (
            LocalSubscription,
            BaseReferences<
              _$AppDatabase,
              $LocalSubscriptionsTable,
              LocalSubscription
            >,
          ),
          LocalSubscription,
          PrefetchHooks Function()
        > {
  $$LocalSubscriptionsTableTableManager(
    _$AppDatabase db,
    $LocalSubscriptionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSubscriptionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSubscriptionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSubscriptionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> homeId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> billingCycle = const Value.absent(),
                Value<DateTime> nextBillingDate = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<bool> isPrivate = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                Value<String?> paidBy = const Value.absent(),
                Value<String?> financedThrough = const Value.absent(),
                Value<int?> totalInstallments = const Value.absent(),
                Value<int?> paidInstallments = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSubscriptionsCompanion(
                id: id,
                homeId: homeId,
                name: name,
                amount: amount,
                currency: currency,
                billingCycle: billingCycle,
                nextBillingDate: nextBillingDate,
                category: category,
                isActive: isActive,
                isPrivate: isPrivate,
                createdBy: createdBy,
                createdAt: createdAt,
                endDate: endDate,
                paidBy: paidBy,
                financedThrough: financedThrough,
                totalInstallments: totalInstallments,
                paidInstallments: paidInstallments,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String homeId,
                required String name,
                required double amount,
                Value<String> currency = const Value.absent(),
                Value<String> billingCycle = const Value.absent(),
                required DateTime nextBillingDate,
                Value<String?> category = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<bool> isPrivate = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> endDate = const Value.absent(),
                Value<String?> paidBy = const Value.absent(),
                Value<String?> financedThrough = const Value.absent(),
                Value<int?> totalInstallments = const Value.absent(),
                Value<int?> paidInstallments = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSubscriptionsCompanion.insert(
                id: id,
                homeId: homeId,
                name: name,
                amount: amount,
                currency: currency,
                billingCycle: billingCycle,
                nextBillingDate: nextBillingDate,
                category: category,
                isActive: isActive,
                isPrivate: isPrivate,
                createdBy: createdBy,
                createdAt: createdAt,
                endDate: endDate,
                paidBy: paidBy,
                financedThrough: financedThrough,
                totalInstallments: totalInstallments,
                paidInstallments: paidInstallments,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalSubscriptionsTable, LocalSubscription>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalSubscriptionsTable,
                    LocalSubscription
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSubscriptionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSubscriptionsTable,
      LocalSubscription,
      $$LocalSubscriptionsTableFilterComposer,
      $$LocalSubscriptionsTableOrderingComposer,
      $$LocalSubscriptionsTableAnnotationComposer,
      $$LocalSubscriptionsTableCreateCompanionBuilder,
      $$LocalSubscriptionsTableUpdateCompanionBuilder,
      (
        LocalSubscription,
        BaseReferences<
          _$AppDatabase,
          $LocalSubscriptionsTable,
          LocalSubscription
        >,
      ),
      LocalSubscription,
      PrefetchHooks Function()
    >;
typedef $$LocalExpensesTableCreateCompanionBuilder =
    LocalExpensesCompanion Function({
      required String id,
      required String homeId,
      required String title,
      required double amount,
      Value<String> currency,
      required String paidBy,
      Value<double> splitRatio,
      required DateTime expenseDate,
      Value<String?> category,
      Value<String?> paymentMethod,
      Value<bool> isTransfer,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$LocalExpensesTableUpdateCompanionBuilder =
    LocalExpensesCompanion Function({
      Value<String> id,
      Value<String> homeId,
      Value<String> title,
      Value<double> amount,
      Value<String> currency,
      Value<String> paidBy,
      Value<double> splitRatio,
      Value<DateTime> expenseDate,
      Value<String?> category,
      Value<String?> paymentMethod,
      Value<bool> isTransfer,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$LocalExpensesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalExpensesTable> {
  $$LocalExpensesTableFilterComposer({
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

  ColumnFilters<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paidBy => $composableBuilder(
    column: $table.paidBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get splitRatio => $composableBuilder(
    column: $table.splitRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expenseDate => $composableBuilder(
    column: $table.expenseDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isTransfer => $composableBuilder(
    column: $table.isTransfer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalExpensesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalExpensesTable> {
  $$LocalExpensesTableOrderingComposer({
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

  ColumnOrderings<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paidBy => $composableBuilder(
    column: $table.paidBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get splitRatio => $composableBuilder(
    column: $table.splitRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expenseDate => $composableBuilder(
    column: $table.expenseDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isTransfer => $composableBuilder(
    column: $table.isTransfer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalExpensesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalExpensesTable> {
  $$LocalExpensesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get homeId =>
      $composableBuilder(column: $table.homeId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get paidBy =>
      $composableBuilder(column: $table.paidBy, builder: (column) => column);

  GeneratedColumn<double> get splitRatio => $composableBuilder(
    column: $table.splitRatio,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get expenseDate => $composableBuilder(
    column: $table.expenseDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isTransfer => $composableBuilder(
    column: $table.isTransfer,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalExpensesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalExpensesTable,
          LocalExpense,
          $$LocalExpensesTableFilterComposer,
          $$LocalExpensesTableOrderingComposer,
          $$LocalExpensesTableAnnotationComposer,
          $$LocalExpensesTableCreateCompanionBuilder,
          $$LocalExpensesTableUpdateCompanionBuilder,
          (
            LocalExpense,
            BaseReferences<_$AppDatabase, $LocalExpensesTable, LocalExpense>,
          ),
          LocalExpense,
          PrefetchHooks Function()
        > {
  $$LocalExpensesTableTableManager(_$AppDatabase db, $LocalExpensesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalExpensesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalExpensesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalExpensesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> homeId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> paidBy = const Value.absent(),
                Value<double> splitRatio = const Value.absent(),
                Value<DateTime> expenseDate = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> paymentMethod = const Value.absent(),
                Value<bool> isTransfer = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalExpensesCompanion(
                id: id,
                homeId: homeId,
                title: title,
                amount: amount,
                currency: currency,
                paidBy: paidBy,
                splitRatio: splitRatio,
                expenseDate: expenseDate,
                category: category,
                paymentMethod: paymentMethod,
                isTransfer: isTransfer,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String homeId,
                required String title,
                required double amount,
                Value<String> currency = const Value.absent(),
                required String paidBy,
                Value<double> splitRatio = const Value.absent(),
                required DateTime expenseDate,
                Value<String?> category = const Value.absent(),
                Value<String?> paymentMethod = const Value.absent(),
                Value<bool> isTransfer = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalExpensesCompanion.insert(
                id: id,
                homeId: homeId,
                title: title,
                amount: amount,
                currency: currency,
                paidBy: paidBy,
                splitRatio: splitRatio,
                expenseDate: expenseDate,
                category: category,
                paymentMethod: paymentMethod,
                isTransfer: isTransfer,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalExpensesTable, LocalExpense>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalExpensesTable,
                    LocalExpense
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalExpensesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalExpensesTable,
      LocalExpense,
      $$LocalExpensesTableFilterComposer,
      $$LocalExpensesTableOrderingComposer,
      $$LocalExpensesTableAnnotationComposer,
      $$LocalExpensesTableCreateCompanionBuilder,
      $$LocalExpensesTableUpdateCompanionBuilder,
      (
        LocalExpense,
        BaseReferences<_$AppDatabase, $LocalExpensesTable, LocalExpense>,
      ),
      LocalExpense,
      PrefetchHooks Function()
    >;
typedef $$LocalHabitsTableCreateCompanionBuilder =
    LocalHabitsCompanion Function({
      required String id,
      required String homeId,
      required String name,
      Value<String> cadence,
      Value<int> targetDaysPerWeek,
      Value<bool> isArchived,
      required DateTime createdAt,
      required String createdBy,
      Value<int> rowid,
    });
typedef $$LocalHabitsTableUpdateCompanionBuilder =
    LocalHabitsCompanion Function({
      Value<String> id,
      Value<String> homeId,
      Value<String> name,
      Value<String> cadence,
      Value<int> targetDaysPerWeek,
      Value<bool> isArchived,
      Value<DateTime> createdAt,
      Value<String> createdBy,
      Value<int> rowid,
    });

class $$LocalHabitsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalHabitsTable> {
  $$LocalHabitsTableFilterComposer({
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

  ColumnFilters<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cadence => $composableBuilder(
    column: $table.cadence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetDaysPerWeek => $composableBuilder(
    column: $table.targetDaysPerWeek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalHabitsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalHabitsTable> {
  $$LocalHabitsTableOrderingComposer({
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

  ColumnOrderings<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cadence => $composableBuilder(
    column: $table.cadence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetDaysPerWeek => $composableBuilder(
    column: $table.targetDaysPerWeek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalHabitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalHabitsTable> {
  $$LocalHabitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get homeId =>
      $composableBuilder(column: $table.homeId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get cadence =>
      $composableBuilder(column: $table.cadence, builder: (column) => column);

  GeneratedColumn<int> get targetDaysPerWeek => $composableBuilder(
    column: $table.targetDaysPerWeek,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);
}

class $$LocalHabitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalHabitsTable,
          LocalHabit,
          $$LocalHabitsTableFilterComposer,
          $$LocalHabitsTableOrderingComposer,
          $$LocalHabitsTableAnnotationComposer,
          $$LocalHabitsTableCreateCompanionBuilder,
          $$LocalHabitsTableUpdateCompanionBuilder,
          (
            LocalHabit,
            BaseReferences<_$AppDatabase, $LocalHabitsTable, LocalHabit>,
          ),
          LocalHabit,
          PrefetchHooks Function()
        > {
  $$LocalHabitsTableTableManager(_$AppDatabase db, $LocalHabitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalHabitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalHabitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalHabitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> homeId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> cadence = const Value.absent(),
                Value<int> targetDaysPerWeek = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalHabitsCompanion(
                id: id,
                homeId: homeId,
                name: name,
                cadence: cadence,
                targetDaysPerWeek: targetDaysPerWeek,
                isArchived: isArchived,
                createdAt: createdAt,
                createdBy: createdBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String homeId,
                required String name,
                Value<String> cadence = const Value.absent(),
                Value<int> targetDaysPerWeek = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                required DateTime createdAt,
                required String createdBy,
                Value<int> rowid = const Value.absent(),
              }) => LocalHabitsCompanion.insert(
                id: id,
                homeId: homeId,
                name: name,
                cadence: cadence,
                targetDaysPerWeek: targetDaysPerWeek,
                isArchived: isArchived,
                createdAt: createdAt,
                createdBy: createdBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalHabitsTable, LocalHabit>(table),
                  BaseReferences<_$AppDatabase, $LocalHabitsTable, LocalHabit>(
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

typedef $$LocalHabitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalHabitsTable,
      LocalHabit,
      $$LocalHabitsTableFilterComposer,
      $$LocalHabitsTableOrderingComposer,
      $$LocalHabitsTableAnnotationComposer,
      $$LocalHabitsTableCreateCompanionBuilder,
      $$LocalHabitsTableUpdateCompanionBuilder,
      (
        LocalHabit,
        BaseReferences<_$AppDatabase, $LocalHabitsTable, LocalHabit>,
      ),
      LocalHabit,
      PrefetchHooks Function()
    >;
typedef $$LocalHabitCheckinsTableCreateCompanionBuilder =
    LocalHabitCheckinsCompanion Function({
      required String id,
      required String homeId,
      required String habitId,
      required String checkinDate,
      required String memberId,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$LocalHabitCheckinsTableUpdateCompanionBuilder =
    LocalHabitCheckinsCompanion Function({
      Value<String> id,
      Value<String> homeId,
      Value<String> habitId,
      Value<String> checkinDate,
      Value<String> memberId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$LocalHabitCheckinsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalHabitCheckinsTable> {
  $$LocalHabitCheckinsTableFilterComposer({
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

  ColumnFilters<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checkinDate => $composableBuilder(
    column: $table.checkinDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memberId => $composableBuilder(
    column: $table.memberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalHabitCheckinsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalHabitCheckinsTable> {
  $$LocalHabitCheckinsTableOrderingComposer({
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

  ColumnOrderings<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checkinDate => $composableBuilder(
    column: $table.checkinDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memberId => $composableBuilder(
    column: $table.memberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalHabitCheckinsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalHabitCheckinsTable> {
  $$LocalHabitCheckinsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get homeId =>
      $composableBuilder(column: $table.homeId, builder: (column) => column);

  GeneratedColumn<String> get habitId =>
      $composableBuilder(column: $table.habitId, builder: (column) => column);

  GeneratedColumn<String> get checkinDate => $composableBuilder(
    column: $table.checkinDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get memberId =>
      $composableBuilder(column: $table.memberId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalHabitCheckinsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalHabitCheckinsTable,
          LocalHabitCheckin,
          $$LocalHabitCheckinsTableFilterComposer,
          $$LocalHabitCheckinsTableOrderingComposer,
          $$LocalHabitCheckinsTableAnnotationComposer,
          $$LocalHabitCheckinsTableCreateCompanionBuilder,
          $$LocalHabitCheckinsTableUpdateCompanionBuilder,
          (
            LocalHabitCheckin,
            BaseReferences<
              _$AppDatabase,
              $LocalHabitCheckinsTable,
              LocalHabitCheckin
            >,
          ),
          LocalHabitCheckin,
          PrefetchHooks Function()
        > {
  $$LocalHabitCheckinsTableTableManager(
    _$AppDatabase db,
    $LocalHabitCheckinsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalHabitCheckinsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalHabitCheckinsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalHabitCheckinsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> homeId = const Value.absent(),
                Value<String> habitId = const Value.absent(),
                Value<String> checkinDate = const Value.absent(),
                Value<String> memberId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalHabitCheckinsCompanion(
                id: id,
                homeId: homeId,
                habitId: habitId,
                checkinDate: checkinDate,
                memberId: memberId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String homeId,
                required String habitId,
                required String checkinDate,
                required String memberId,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalHabitCheckinsCompanion.insert(
                id: id,
                homeId: homeId,
                habitId: habitId,
                checkinDate: checkinDate,
                memberId: memberId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalHabitCheckinsTable, LocalHabitCheckin>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalHabitCheckinsTable,
                    LocalHabitCheckin
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalHabitCheckinsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalHabitCheckinsTable,
      LocalHabitCheckin,
      $$LocalHabitCheckinsTableFilterComposer,
      $$LocalHabitCheckinsTableOrderingComposer,
      $$LocalHabitCheckinsTableAnnotationComposer,
      $$LocalHabitCheckinsTableCreateCompanionBuilder,
      $$LocalHabitCheckinsTableUpdateCompanionBuilder,
      (
        LocalHabitCheckin,
        BaseReferences<
          _$AppDatabase,
          $LocalHabitCheckinsTable,
          LocalHabitCheckin
        >,
      ),
      LocalHabitCheckin,
      PrefetchHooks Function()
    >;
typedef $$LocalCalendarEventsTableCreateCompanionBuilder =
    LocalCalendarEventsCompanion Function({
      required String id,
      required String homeId,
      required String title,
      Value<String?> description,
      required DateTime startTime,
      required DateTime endTime,
      Value<bool> isAllDay,
      Value<String?> location,
      required DateTime createdAt,
      required String createdBy,
      Value<String?> recurrence,
      Value<int> rowid,
    });
typedef $$LocalCalendarEventsTableUpdateCompanionBuilder =
    LocalCalendarEventsCompanion Function({
      Value<String> id,
      Value<String> homeId,
      Value<String> title,
      Value<String?> description,
      Value<DateTime> startTime,
      Value<DateTime> endTime,
      Value<bool> isAllDay,
      Value<String?> location,
      Value<DateTime> createdAt,
      Value<String> createdBy,
      Value<String?> recurrence,
      Value<int> rowid,
    });

class $$LocalCalendarEventsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalCalendarEventsTable> {
  $$LocalCalendarEventsTableFilterComposer({
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

  ColumnFilters<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAllDay => $composableBuilder(
    column: $table.isAllDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalCalendarEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalCalendarEventsTable> {
  $$LocalCalendarEventsTableOrderingComposer({
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

  ColumnOrderings<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAllDay => $composableBuilder(
    column: $table.isAllDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalCalendarEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalCalendarEventsTable> {
  $$LocalCalendarEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get homeId =>
      $composableBuilder(column: $table.homeId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<DateTime> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<bool> get isAllDay =>
      $composableBuilder(column: $table.isAllDay, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => column,
  );
}

class $$LocalCalendarEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalCalendarEventsTable,
          LocalCalendarEvent,
          $$LocalCalendarEventsTableFilterComposer,
          $$LocalCalendarEventsTableOrderingComposer,
          $$LocalCalendarEventsTableAnnotationComposer,
          $$LocalCalendarEventsTableCreateCompanionBuilder,
          $$LocalCalendarEventsTableUpdateCompanionBuilder,
          (
            LocalCalendarEvent,
            BaseReferences<
              _$AppDatabase,
              $LocalCalendarEventsTable,
              LocalCalendarEvent
            >,
          ),
          LocalCalendarEvent,
          PrefetchHooks Function()
        > {
  $$LocalCalendarEventsTableTableManager(
    _$AppDatabase db,
    $LocalCalendarEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalCalendarEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalCalendarEventsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalCalendarEventsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> homeId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<DateTime> startTime = const Value.absent(),
                Value<DateTime> endTime = const Value.absent(),
                Value<bool> isAllDay = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<String?> recurrence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalCalendarEventsCompanion(
                id: id,
                homeId: homeId,
                title: title,
                description: description,
                startTime: startTime,
                endTime: endTime,
                isAllDay: isAllDay,
                location: location,
                createdAt: createdAt,
                createdBy: createdBy,
                recurrence: recurrence,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String homeId,
                required String title,
                Value<String?> description = const Value.absent(),
                required DateTime startTime,
                required DateTime endTime,
                Value<bool> isAllDay = const Value.absent(),
                Value<String?> location = const Value.absent(),
                required DateTime createdAt,
                required String createdBy,
                Value<String?> recurrence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalCalendarEventsCompanion.insert(
                id: id,
                homeId: homeId,
                title: title,
                description: description,
                startTime: startTime,
                endTime: endTime,
                isAllDay: isAllDay,
                location: location,
                createdAt: createdAt,
                createdBy: createdBy,
                recurrence: recurrence,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalCalendarEventsTable, LocalCalendarEvent>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalCalendarEventsTable,
                    LocalCalendarEvent
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalCalendarEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalCalendarEventsTable,
      LocalCalendarEvent,
      $$LocalCalendarEventsTableFilterComposer,
      $$LocalCalendarEventsTableOrderingComposer,
      $$LocalCalendarEventsTableAnnotationComposer,
      $$LocalCalendarEventsTableCreateCompanionBuilder,
      $$LocalCalendarEventsTableUpdateCompanionBuilder,
      (
        LocalCalendarEvent,
        BaseReferences<
          _$AppDatabase,
          $LocalCalendarEventsTable,
          LocalCalendarEvent
        >,
      ),
      LocalCalendarEvent,
      PrefetchHooks Function()
    >;
typedef $$LocalOutboxEventsTableCreateCompanionBuilder =
    LocalOutboxEventsCompanion Function({
      required String id,
      required String homeId,
      required String actorId,
      required String eventType,
      required String payloadJson,
      required String encryptedPayload,
      required DateTime createdAt,
      Value<String> syncStatus,
      Value<int> retryCount,
      Value<DateTime?> lastAttemptAt,
      Value<int> rowid,
    });
typedef $$LocalOutboxEventsTableUpdateCompanionBuilder =
    LocalOutboxEventsCompanion Function({
      Value<String> id,
      Value<String> homeId,
      Value<String> actorId,
      Value<String> eventType,
      Value<String> payloadJson,
      Value<String> encryptedPayload,
      Value<DateTime> createdAt,
      Value<String> syncStatus,
      Value<int> retryCount,
      Value<DateTime?> lastAttemptAt,
      Value<int> rowid,
    });

class $$LocalOutboxEventsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalOutboxEventsTable> {
  $$LocalOutboxEventsTableFilterComposer({
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

  ColumnFilters<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalOutboxEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalOutboxEventsTable> {
  $$LocalOutboxEventsTableOrderingComposer({
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

  ColumnOrderings<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalOutboxEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalOutboxEventsTable> {
  $$LocalOutboxEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get homeId =>
      $composableBuilder(column: $table.homeId, builder: (column) => column);

  GeneratedColumn<String> get actorId =>
      $composableBuilder(column: $table.actorId, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );
}

class $$LocalOutboxEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalOutboxEventsTable,
          LocalOutboxEvent,
          $$LocalOutboxEventsTableFilterComposer,
          $$LocalOutboxEventsTableOrderingComposer,
          $$LocalOutboxEventsTableAnnotationComposer,
          $$LocalOutboxEventsTableCreateCompanionBuilder,
          $$LocalOutboxEventsTableUpdateCompanionBuilder,
          (
            LocalOutboxEvent,
            BaseReferences<
              _$AppDatabase,
              $LocalOutboxEventsTable,
              LocalOutboxEvent
            >,
          ),
          LocalOutboxEvent,
          PrefetchHooks Function()
        > {
  $$LocalOutboxEventsTableTableManager(
    _$AppDatabase db,
    $LocalOutboxEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalOutboxEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalOutboxEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalOutboxEventsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> homeId = const Value.absent(),
                Value<String> actorId = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> encryptedPayload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalOutboxEventsCompanion(
                id: id,
                homeId: homeId,
                actorId: actorId,
                eventType: eventType,
                payloadJson: payloadJson,
                encryptedPayload: encryptedPayload,
                createdAt: createdAt,
                syncStatus: syncStatus,
                retryCount: retryCount,
                lastAttemptAt: lastAttemptAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String homeId,
                required String actorId,
                required String eventType,
                required String payloadJson,
                required String encryptedPayload,
                required DateTime createdAt,
                Value<String> syncStatus = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalOutboxEventsCompanion.insert(
                id: id,
                homeId: homeId,
                actorId: actorId,
                eventType: eventType,
                payloadJson: payloadJson,
                encryptedPayload: encryptedPayload,
                createdAt: createdAt,
                syncStatus: syncStatus,
                retryCount: retryCount,
                lastAttemptAt: lastAttemptAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalOutboxEventsTable, LocalOutboxEvent>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalOutboxEventsTable,
                    LocalOutboxEvent
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalOutboxEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalOutboxEventsTable,
      LocalOutboxEvent,
      $$LocalOutboxEventsTableFilterComposer,
      $$LocalOutboxEventsTableOrderingComposer,
      $$LocalOutboxEventsTableAnnotationComposer,
      $$LocalOutboxEventsTableCreateCompanionBuilder,
      $$LocalOutboxEventsTableUpdateCompanionBuilder,
      (
        LocalOutboxEvent,
        BaseReferences<
          _$AppDatabase,
          $LocalOutboxEventsTable,
          LocalOutboxEvent
        >,
      ),
      LocalOutboxEvent,
      PrefetchHooks Function()
    >;
typedef $$LocalActivityEventsTableCreateCompanionBuilder =
    LocalActivityEventsCompanion Function({
      required String id,
      required String homeId,
      required String actorId,
      required String eventType,
      required String payloadJson,
      required DateTime createdAt,
      Value<String> syncStatus,
      Value<bool> isPrivate,
      Value<int> rowid,
    });
typedef $$LocalActivityEventsTableUpdateCompanionBuilder =
    LocalActivityEventsCompanion Function({
      Value<String> id,
      Value<String> homeId,
      Value<String> actorId,
      Value<String> eventType,
      Value<String> payloadJson,
      Value<DateTime> createdAt,
      Value<String> syncStatus,
      Value<bool> isPrivate,
      Value<int> rowid,
    });

class $$LocalActivityEventsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalActivityEventsTable> {
  $$LocalActivityEventsTableFilterComposer({
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

  ColumnFilters<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPrivate => $composableBuilder(
    column: $table.isPrivate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalActivityEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalActivityEventsTable> {
  $$LocalActivityEventsTableOrderingComposer({
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

  ColumnOrderings<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPrivate => $composableBuilder(
    column: $table.isPrivate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalActivityEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalActivityEventsTable> {
  $$LocalActivityEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get homeId =>
      $composableBuilder(column: $table.homeId, builder: (column) => column);

  GeneratedColumn<String> get actorId =>
      $composableBuilder(column: $table.actorId, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPrivate =>
      $composableBuilder(column: $table.isPrivate, builder: (column) => column);
}

class $$LocalActivityEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalActivityEventsTable,
          LocalActivityEvent,
          $$LocalActivityEventsTableFilterComposer,
          $$LocalActivityEventsTableOrderingComposer,
          $$LocalActivityEventsTableAnnotationComposer,
          $$LocalActivityEventsTableCreateCompanionBuilder,
          $$LocalActivityEventsTableUpdateCompanionBuilder,
          (
            LocalActivityEvent,
            BaseReferences<
              _$AppDatabase,
              $LocalActivityEventsTable,
              LocalActivityEvent
            >,
          ),
          LocalActivityEvent,
          PrefetchHooks Function()
        > {
  $$LocalActivityEventsTableTableManager(
    _$AppDatabase db,
    $LocalActivityEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalActivityEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalActivityEventsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalActivityEventsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> homeId = const Value.absent(),
                Value<String> actorId = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<bool> isPrivate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalActivityEventsCompanion(
                id: id,
                homeId: homeId,
                actorId: actorId,
                eventType: eventType,
                payloadJson: payloadJson,
                createdAt: createdAt,
                syncStatus: syncStatus,
                isPrivate: isPrivate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String homeId,
                required String actorId,
                required String eventType,
                required String payloadJson,
                required DateTime createdAt,
                Value<String> syncStatus = const Value.absent(),
                Value<bool> isPrivate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalActivityEventsCompanion.insert(
                id: id,
                homeId: homeId,
                actorId: actorId,
                eventType: eventType,
                payloadJson: payloadJson,
                createdAt: createdAt,
                syncStatus: syncStatus,
                isPrivate: isPrivate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalActivityEventsTable, LocalActivityEvent>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalActivityEventsTable,
                    LocalActivityEvent
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalActivityEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalActivityEventsTable,
      LocalActivityEvent,
      $$LocalActivityEventsTableFilterComposer,
      $$LocalActivityEventsTableOrderingComposer,
      $$LocalActivityEventsTableAnnotationComposer,
      $$LocalActivityEventsTableCreateCompanionBuilder,
      $$LocalActivityEventsTableUpdateCompanionBuilder,
      (
        LocalActivityEvent,
        BaseReferences<
          _$AppDatabase,
          $LocalActivityEventsTable,
          LocalActivityEvent
        >,
      ),
      LocalActivityEvent,
      PrefetchHooks Function()
    >;
typedef $$LocalNotificationPreferencesTableCreateCompanionBuilder =
    LocalNotificationPreferencesCompanion Function({
      Value<String> id,
      Value<bool> muteSubscriptions,
      Value<bool> muteLists,
      Value<bool> muteExpenses,
      Value<bool> muteHabits,
      Value<bool> muteCalendar,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LocalNotificationPreferencesTableUpdateCompanionBuilder =
    LocalNotificationPreferencesCompanion Function({
      Value<String> id,
      Value<bool> muteSubscriptions,
      Value<bool> muteLists,
      Value<bool> muteExpenses,
      Value<bool> muteHabits,
      Value<bool> muteCalendar,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LocalNotificationPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalNotificationPreferencesTable> {
  $$LocalNotificationPreferencesTableFilterComposer({
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

  ColumnFilters<bool> get muteSubscriptions => $composableBuilder(
    column: $table.muteSubscriptions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get muteLists => $composableBuilder(
    column: $table.muteLists,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get muteExpenses => $composableBuilder(
    column: $table.muteExpenses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get muteHabits => $composableBuilder(
    column: $table.muteHabits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get muteCalendar => $composableBuilder(
    column: $table.muteCalendar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalNotificationPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalNotificationPreferencesTable> {
  $$LocalNotificationPreferencesTableOrderingComposer({
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

  ColumnOrderings<bool> get muteSubscriptions => $composableBuilder(
    column: $table.muteSubscriptions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get muteLists => $composableBuilder(
    column: $table.muteLists,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get muteExpenses => $composableBuilder(
    column: $table.muteExpenses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get muteHabits => $composableBuilder(
    column: $table.muteHabits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get muteCalendar => $composableBuilder(
    column: $table.muteCalendar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalNotificationPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalNotificationPreferencesTable> {
  $$LocalNotificationPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get muteSubscriptions => $composableBuilder(
    column: $table.muteSubscriptions,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get muteLists =>
      $composableBuilder(column: $table.muteLists, builder: (column) => column);

  GeneratedColumn<bool> get muteExpenses => $composableBuilder(
    column: $table.muteExpenses,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get muteHabits => $composableBuilder(
    column: $table.muteHabits,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get muteCalendar => $composableBuilder(
    column: $table.muteCalendar,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalNotificationPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalNotificationPreferencesTable,
          LocalNotificationPreference,
          $$LocalNotificationPreferencesTableFilterComposer,
          $$LocalNotificationPreferencesTableOrderingComposer,
          $$LocalNotificationPreferencesTableAnnotationComposer,
          $$LocalNotificationPreferencesTableCreateCompanionBuilder,
          $$LocalNotificationPreferencesTableUpdateCompanionBuilder,
          (
            LocalNotificationPreference,
            BaseReferences<
              _$AppDatabase,
              $LocalNotificationPreferencesTable,
              LocalNotificationPreference
            >,
          ),
          LocalNotificationPreference,
          PrefetchHooks Function()
        > {
  $$LocalNotificationPreferencesTableTableManager(
    _$AppDatabase db,
    $LocalNotificationPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalNotificationPreferencesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalNotificationPreferencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalNotificationPreferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<bool> muteSubscriptions = const Value.absent(),
                Value<bool> muteLists = const Value.absent(),
                Value<bool> muteExpenses = const Value.absent(),
                Value<bool> muteHabits = const Value.absent(),
                Value<bool> muteCalendar = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalNotificationPreferencesCompanion(
                id: id,
                muteSubscriptions: muteSubscriptions,
                muteLists: muteLists,
                muteExpenses: muteExpenses,
                muteHabits: muteHabits,
                muteCalendar: muteCalendar,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<bool> muteSubscriptions = const Value.absent(),
                Value<bool> muteLists = const Value.absent(),
                Value<bool> muteExpenses = const Value.absent(),
                Value<bool> muteHabits = const Value.absent(),
                Value<bool> muteCalendar = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalNotificationPreferencesCompanion.insert(
                id: id,
                muteSubscriptions: muteSubscriptions,
                muteLists: muteLists,
                muteExpenses: muteExpenses,
                muteHabits: muteHabits,
                muteCalendar: muteCalendar,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LocalNotificationPreferencesTable,
                    LocalNotificationPreference
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalNotificationPreferencesTable,
                    LocalNotificationPreference
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalNotificationPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalNotificationPreferencesTable,
      LocalNotificationPreference,
      $$LocalNotificationPreferencesTableFilterComposer,
      $$LocalNotificationPreferencesTableOrderingComposer,
      $$LocalNotificationPreferencesTableAnnotationComposer,
      $$LocalNotificationPreferencesTableCreateCompanionBuilder,
      $$LocalNotificationPreferencesTableUpdateCompanionBuilder,
      (
        LocalNotificationPreference,
        BaseReferences<
          _$AppDatabase,
          $LocalNotificationPreferencesTable,
          LocalNotificationPreference
        >,
      ),
      LocalNotificationPreference,
      PrefetchHooks Function()
    >;
typedef $$LocalRoadmapItemsTableCreateCompanionBuilder =
    LocalRoadmapItemsCompanion Function({
      required String id,
      required String homeId,
      required String title,
      Value<String?> description,
      Value<bool> isCompleted,
      required DateTime createdAt,
      required String createdBy,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$LocalRoadmapItemsTableUpdateCompanionBuilder =
    LocalRoadmapItemsCompanion Function({
      Value<String> id,
      Value<String> homeId,
      Value<String> title,
      Value<String?> description,
      Value<bool> isCompleted,
      Value<DateTime> createdAt,
      Value<String> createdBy,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });

class $$LocalRoadmapItemsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalRoadmapItemsTable> {
  $$LocalRoadmapItemsTableFilterComposer({
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

  ColumnFilters<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalRoadmapItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalRoadmapItemsTable> {
  $$LocalRoadmapItemsTableOrderingComposer({
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

  ColumnOrderings<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalRoadmapItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalRoadmapItemsTable> {
  $$LocalRoadmapItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get homeId =>
      $composableBuilder(column: $table.homeId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$LocalRoadmapItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalRoadmapItemsTable,
          LocalRoadmapItem,
          $$LocalRoadmapItemsTableFilterComposer,
          $$LocalRoadmapItemsTableOrderingComposer,
          $$LocalRoadmapItemsTableAnnotationComposer,
          $$LocalRoadmapItemsTableCreateCompanionBuilder,
          $$LocalRoadmapItemsTableUpdateCompanionBuilder,
          (
            LocalRoadmapItem,
            BaseReferences<
              _$AppDatabase,
              $LocalRoadmapItemsTable,
              LocalRoadmapItem
            >,
          ),
          LocalRoadmapItem,
          PrefetchHooks Function()
        > {
  $$LocalRoadmapItemsTableTableManager(
    _$AppDatabase db,
    $LocalRoadmapItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalRoadmapItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalRoadmapItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalRoadmapItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> homeId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalRoadmapItemsCompanion(
                id: id,
                homeId: homeId,
                title: title,
                description: description,
                isCompleted: isCompleted,
                createdAt: createdAt,
                createdBy: createdBy,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String homeId,
                required String title,
                Value<String?> description = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                required DateTime createdAt,
                required String createdBy,
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalRoadmapItemsCompanion.insert(
                id: id,
                homeId: homeId,
                title: title,
                description: description,
                isCompleted: isCompleted,
                createdAt: createdAt,
                createdBy: createdBy,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalRoadmapItemsTable, LocalRoadmapItem>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalRoadmapItemsTable,
                    LocalRoadmapItem
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalRoadmapItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalRoadmapItemsTable,
      LocalRoadmapItem,
      $$LocalRoadmapItemsTableFilterComposer,
      $$LocalRoadmapItemsTableOrderingComposer,
      $$LocalRoadmapItemsTableAnnotationComposer,
      $$LocalRoadmapItemsTableCreateCompanionBuilder,
      $$LocalRoadmapItemsTableUpdateCompanionBuilder,
      (
        LocalRoadmapItem,
        BaseReferences<
          _$AppDatabase,
          $LocalRoadmapItemsTable,
          LocalRoadmapItem
        >,
      ),
      LocalRoadmapItem,
      PrefetchHooks Function()
    >;
typedef $$LocalRoutinesTableCreateCompanionBuilder =
    LocalRoutinesCompanion Function({
      required String id,
      required String homeId,
      required String name,
      required String daysJson,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$LocalRoutinesTableUpdateCompanionBuilder =
    LocalRoutinesCompanion Function({
      Value<String> id,
      Value<String> homeId,
      Value<String> name,
      Value<String> daysJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$LocalRoutinesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalRoutinesTable> {
  $$LocalRoutinesTableFilterComposer({
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

  ColumnFilters<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get daysJson => $composableBuilder(
    column: $table.daysJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalRoutinesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalRoutinesTable> {
  $$LocalRoutinesTableOrderingComposer({
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

  ColumnOrderings<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get daysJson => $composableBuilder(
    column: $table.daysJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalRoutinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalRoutinesTable> {
  $$LocalRoutinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get homeId =>
      $composableBuilder(column: $table.homeId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get daysJson =>
      $composableBuilder(column: $table.daysJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalRoutinesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalRoutinesTable,
          LocalRoutine,
          $$LocalRoutinesTableFilterComposer,
          $$LocalRoutinesTableOrderingComposer,
          $$LocalRoutinesTableAnnotationComposer,
          $$LocalRoutinesTableCreateCompanionBuilder,
          $$LocalRoutinesTableUpdateCompanionBuilder,
          (
            LocalRoutine,
            BaseReferences<_$AppDatabase, $LocalRoutinesTable, LocalRoutine>,
          ),
          LocalRoutine,
          PrefetchHooks Function()
        > {
  $$LocalRoutinesTableTableManager(_$AppDatabase db, $LocalRoutinesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalRoutinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalRoutinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalRoutinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> homeId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> daysJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalRoutinesCompanion(
                id: id,
                homeId: homeId,
                name: name,
                daysJson: daysJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String homeId,
                required String name,
                required String daysJson,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalRoutinesCompanion.insert(
                id: id,
                homeId: homeId,
                name: name,
                daysJson: daysJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalRoutinesTable, LocalRoutine>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalRoutinesTable,
                    LocalRoutine
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalRoutinesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalRoutinesTable,
      LocalRoutine,
      $$LocalRoutinesTableFilterComposer,
      $$LocalRoutinesTableOrderingComposer,
      $$LocalRoutinesTableAnnotationComposer,
      $$LocalRoutinesTableCreateCompanionBuilder,
      $$LocalRoutinesTableUpdateCompanionBuilder,
      (
        LocalRoutine,
        BaseReferences<_$AppDatabase, $LocalRoutinesTable, LocalRoutine>,
      ),
      LocalRoutine,
      PrefetchHooks Function()
    >;
typedef $$LocalRoutineEventsTableCreateCompanionBuilder =
    LocalRoutineEventsCompanion Function({
      required String id,
      required String routineId,
      required String homeId,
      required String title,
      required int startMinutes,
      required int endMinutes,
      Value<String?> category,
      Value<String?> notes,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$LocalRoutineEventsTableUpdateCompanionBuilder =
    LocalRoutineEventsCompanion Function({
      Value<String> id,
      Value<String> routineId,
      Value<String> homeId,
      Value<String> title,
      Value<int> startMinutes,
      Value<int> endMinutes,
      Value<String?> category,
      Value<String?> notes,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$LocalRoutineEventsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalRoutineEventsTable> {
  $$LocalRoutineEventsTableFilterComposer({
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

  ColumnFilters<String> get routineId => $composableBuilder(
    column: $table.routineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMinutes => $composableBuilder(
    column: $table.startMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMinutes => $composableBuilder(
    column: $table.endMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalRoutineEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalRoutineEventsTable> {
  $$LocalRoutineEventsTableOrderingComposer({
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

  ColumnOrderings<String> get routineId => $composableBuilder(
    column: $table.routineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMinutes => $composableBuilder(
    column: $table.startMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMinutes => $composableBuilder(
    column: $table.endMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalRoutineEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalRoutineEventsTable> {
  $$LocalRoutineEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get routineId =>
      $composableBuilder(column: $table.routineId, builder: (column) => column);

  GeneratedColumn<String> get homeId =>
      $composableBuilder(column: $table.homeId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get startMinutes => $composableBuilder(
    column: $table.startMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMinutes => $composableBuilder(
    column: $table.endMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalRoutineEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalRoutineEventsTable,
          LocalRoutineEvent,
          $$LocalRoutineEventsTableFilterComposer,
          $$LocalRoutineEventsTableOrderingComposer,
          $$LocalRoutineEventsTableAnnotationComposer,
          $$LocalRoutineEventsTableCreateCompanionBuilder,
          $$LocalRoutineEventsTableUpdateCompanionBuilder,
          (
            LocalRoutineEvent,
            BaseReferences<
              _$AppDatabase,
              $LocalRoutineEventsTable,
              LocalRoutineEvent
            >,
          ),
          LocalRoutineEvent,
          PrefetchHooks Function()
        > {
  $$LocalRoutineEventsTableTableManager(
    _$AppDatabase db,
    $LocalRoutineEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalRoutineEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalRoutineEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalRoutineEventsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> routineId = const Value.absent(),
                Value<String> homeId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> startMinutes = const Value.absent(),
                Value<int> endMinutes = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalRoutineEventsCompanion(
                id: id,
                routineId: routineId,
                homeId: homeId,
                title: title,
                startMinutes: startMinutes,
                endMinutes: endMinutes,
                category: category,
                notes: notes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String routineId,
                required String homeId,
                required String title,
                required int startMinutes,
                required int endMinutes,
                Value<String?> category = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalRoutineEventsCompanion.insert(
                id: id,
                routineId: routineId,
                homeId: homeId,
                title: title,
                startMinutes: startMinutes,
                endMinutes: endMinutes,
                category: category,
                notes: notes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalRoutineEventsTable, LocalRoutineEvent>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalRoutineEventsTable,
                    LocalRoutineEvent
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalRoutineEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalRoutineEventsTable,
      LocalRoutineEvent,
      $$LocalRoutineEventsTableFilterComposer,
      $$LocalRoutineEventsTableOrderingComposer,
      $$LocalRoutineEventsTableAnnotationComposer,
      $$LocalRoutineEventsTableCreateCompanionBuilder,
      $$LocalRoutineEventsTableUpdateCompanionBuilder,
      (
        LocalRoutineEvent,
        BaseReferences<
          _$AppDatabase,
          $LocalRoutineEventsTable,
          LocalRoutineEvent
        >,
      ),
      LocalRoutineEvent,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalHomesTableTableManager get localHomes =>
      $$LocalHomesTableTableManager(_db, _db.localHomes);
  $$LocalListsTableTableManager get localLists =>
      $$LocalListsTableTableManager(_db, _db.localLists);
  $$LocalListItemsTableTableManager get localListItems =>
      $$LocalListItemsTableTableManager(_db, _db.localListItems);
  $$LocalSubscriptionsTableTableManager get localSubscriptions =>
      $$LocalSubscriptionsTableTableManager(_db, _db.localSubscriptions);
  $$LocalExpensesTableTableManager get localExpenses =>
      $$LocalExpensesTableTableManager(_db, _db.localExpenses);
  $$LocalHabitsTableTableManager get localHabits =>
      $$LocalHabitsTableTableManager(_db, _db.localHabits);
  $$LocalHabitCheckinsTableTableManager get localHabitCheckins =>
      $$LocalHabitCheckinsTableTableManager(_db, _db.localHabitCheckins);
  $$LocalCalendarEventsTableTableManager get localCalendarEvents =>
      $$LocalCalendarEventsTableTableManager(_db, _db.localCalendarEvents);
  $$LocalOutboxEventsTableTableManager get localOutboxEvents =>
      $$LocalOutboxEventsTableTableManager(_db, _db.localOutboxEvents);
  $$LocalActivityEventsTableTableManager get localActivityEvents =>
      $$LocalActivityEventsTableTableManager(_db, _db.localActivityEvents);
  $$LocalNotificationPreferencesTableTableManager
  get localNotificationPreferences =>
      $$LocalNotificationPreferencesTableTableManager(
        _db,
        _db.localNotificationPreferences,
      );
  $$LocalRoadmapItemsTableTableManager get localRoadmapItems =>
      $$LocalRoadmapItemsTableTableManager(_db, _db.localRoadmapItems);
  $$LocalRoutinesTableTableManager get localRoutines =>
      $$LocalRoutinesTableTableManager(_db, _db.localRoutines);
  $$LocalRoutineEventsTableTableManager get localRoutineEvents =>
      $$LocalRoutineEventsTableTableManager(_db, _db.localRoutineEvents);
}
