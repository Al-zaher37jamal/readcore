// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DeviceProfileTableTable extends DeviceProfileTable
    with TableInfo<$DeviceProfileTableTable, DeviceProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeviceProfileTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, displayName, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'device_profile';
  @override
  VerificationContext validateIntegrity(Insertable<DeviceProfile> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeviceProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceProfile(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $DeviceProfileTableTable createAlias(String alias) {
    return $DeviceProfileTableTable(attachedDatabase, alias);
  }
}

class DeviceProfile extends DataClass implements Insertable<DeviceProfile> {
  final String id;
  final String displayName;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DeviceProfile(
      {required this.id,
      required this.displayName,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DeviceProfileTableCompanion toCompanion(bool nullToAbsent) {
    return DeviceProfileTableCompanion(
      id: Value(id),
      displayName: Value(displayName),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DeviceProfile.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceProfile(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String>(displayName),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DeviceProfile copyWith(
          {String? id,
          String? displayName,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      DeviceProfile(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  DeviceProfile copyWithCompanion(DeviceProfileTableCompanion data) {
    return DeviceProfile(
      id: data.id.present ? data.id.value : this.id,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceProfile(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, displayName, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceProfile &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DeviceProfileTableCompanion extends UpdateCompanion<DeviceProfile> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DeviceProfileTableCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeviceProfileTableCompanion.insert({
    required String id,
    required String displayName,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        displayName = Value(displayName),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<DeviceProfile> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeviceProfileTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? displayName,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return DeviceProfileTableCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
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
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
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
    return (StringBuffer('DeviceProfileTableCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BooksTableTable extends BooksTable
    with TableInfo<$BooksTableTable, Book> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
      'author', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fileSizeMeta =
      const VerificationMeta('fileSize');
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
      'file_size', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _pageCountMeta =
      const VerificationMeta('pageCount');
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
      'page_count', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sha256HashMeta =
      const VerificationMeta('sha256Hash');
  @override
  late final GeneratedColumn<String> sha256Hash = GeneratedColumn<String>(
      'sha256_hash', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _coverPathMeta =
      const VerificationMeta('coverPath');
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
      'cover_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        author,
        filePath,
        fileSize,
        pageCount,
        sha256Hash,
        coverPath,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(Insertable<Book> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(_authorMeta,
          author.isAcceptableOrUnknown(data['author']!, _authorMeta));
    } else if (isInserting) {
      context.missing(_authorMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('file_size')) {
      context.handle(_fileSizeMeta,
          fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta));
    } else if (isInserting) {
      context.missing(_fileSizeMeta);
    }
    if (data.containsKey('page_count')) {
      context.handle(_pageCountMeta,
          pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta));
    } else if (isInserting) {
      context.missing(_pageCountMeta);
    }
    if (data.containsKey('sha256_hash')) {
      context.handle(
          _sha256HashMeta,
          sha256Hash.isAcceptableOrUnknown(
              data['sha256_hash']!, _sha256HashMeta));
    } else if (isInserting) {
      context.missing(_sha256HashMeta);
    }
    if (data.containsKey('cover_path')) {
      context.handle(_coverPathMeta,
          coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {sha256Hash},
      ];
  @override
  Book map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Book(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      author: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      fileSize: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}file_size'])!,
      pageCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}page_count'])!,
      sha256Hash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sha256_hash'])!,
      coverPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_path']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $BooksTableTable createAlias(String alias) {
    return $BooksTableTable(attachedDatabase, alias);
  }
}

class Book extends DataClass implements Insertable<Book> {
  final String id;
  final String title;
  final String author;

  /// Stores relative or absolute file path on local filesystem.
  /// Never store PDF binary data in SQLite!
  final String filePath;
  final int fileSize;
  final int pageCount;
  final String sha256Hash;
  final String? coverPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Book(
      {required this.id,
      required this.title,
      required this.author,
      required this.filePath,
      required this.fileSize,
      required this.pageCount,
      required this.sha256Hash,
      this.coverPath,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['author'] = Variable<String>(author);
    map['file_path'] = Variable<String>(filePath);
    map['file_size'] = Variable<int>(fileSize);
    map['page_count'] = Variable<int>(pageCount);
    map['sha256_hash'] = Variable<String>(sha256Hash);
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BooksTableCompanion toCompanion(bool nullToAbsent) {
    return BooksTableCompanion(
      id: Value(id),
      title: Value(title),
      author: Value(author),
      filePath: Value(filePath),
      fileSize: Value(fileSize),
      pageCount: Value(pageCount),
      sha256Hash: Value(sha256Hash),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Book.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Book(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String>(json['author']),
      filePath: serializer.fromJson<String>(json['filePath']),
      fileSize: serializer.fromJson<int>(json['fileSize']),
      pageCount: serializer.fromJson<int>(json['pageCount']),
      sha256Hash: serializer.fromJson<String>(json['sha256Hash']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String>(author),
      'filePath': serializer.toJson<String>(filePath),
      'fileSize': serializer.toJson<int>(fileSize),
      'pageCount': serializer.toJson<int>(pageCount),
      'sha256Hash': serializer.toJson<String>(sha256Hash),
      'coverPath': serializer.toJson<String?>(coverPath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Book copyWith(
          {String? id,
          String? title,
          String? author,
          String? filePath,
          int? fileSize,
          int? pageCount,
          String? sha256Hash,
          Value<String?> coverPath = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Book(
        id: id ?? this.id,
        title: title ?? this.title,
        author: author ?? this.author,
        filePath: filePath ?? this.filePath,
        fileSize: fileSize ?? this.fileSize,
        pageCount: pageCount ?? this.pageCount,
        sha256Hash: sha256Hash ?? this.sha256Hash,
        coverPath: coverPath.present ? coverPath.value : this.coverPath,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Book copyWithCompanion(BooksTableCompanion data) {
    return Book(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      sha256Hash:
          data.sha256Hash.present ? data.sha256Hash.value : this.sha256Hash,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Book(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('filePath: $filePath, ')
          ..write('fileSize: $fileSize, ')
          ..write('pageCount: $pageCount, ')
          ..write('sha256Hash: $sha256Hash, ')
          ..write('coverPath: $coverPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, author, filePath, fileSize,
      pageCount, sha256Hash, coverPath, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Book &&
          other.id == this.id &&
          other.title == this.title &&
          other.author == this.author &&
          other.filePath == this.filePath &&
          other.fileSize == this.fileSize &&
          other.pageCount == this.pageCount &&
          other.sha256Hash == this.sha256Hash &&
          other.coverPath == this.coverPath &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BooksTableCompanion extends UpdateCompanion<Book> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> author;
  final Value<String> filePath;
  final Value<int> fileSize;
  final Value<int> pageCount;
  final Value<String> sha256Hash;
  final Value<String?> coverPath;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BooksTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.sha256Hash = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BooksTableCompanion.insert({
    required String id,
    required String title,
    required String author,
    required String filePath,
    required int fileSize,
    required int pageCount,
    required String sha256Hash,
    this.coverPath = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        author = Value(author),
        filePath = Value(filePath),
        fileSize = Value(fileSize),
        pageCount = Value(pageCount),
        sha256Hash = Value(sha256Hash),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Book> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? filePath,
    Expression<int>? fileSize,
    Expression<int>? pageCount,
    Expression<String>? sha256Hash,
    Expression<String>? coverPath,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (filePath != null) 'file_path': filePath,
      if (fileSize != null) 'file_size': fileSize,
      if (pageCount != null) 'page_count': pageCount,
      if (sha256Hash != null) 'sha256_hash': sha256Hash,
      if (coverPath != null) 'cover_path': coverPath,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BooksTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? author,
      Value<String>? filePath,
      Value<int>? fileSize,
      Value<int>? pageCount,
      Value<String>? sha256Hash,
      Value<String?>? coverPath,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return BooksTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      pageCount: pageCount ?? this.pageCount,
      sha256Hash: sha256Hash ?? this.sha256Hash,
      coverPath: coverPath ?? this.coverPath,
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
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (sha256Hash.present) {
      map['sha256_hash'] = Variable<String>(sha256Hash.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
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
    return (StringBuffer('BooksTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('filePath: $filePath, ')
          ..write('fileSize: $fileSize, ')
          ..write('pageCount: $pageCount, ')
          ..write('sha256Hash: $sha256Hash, ')
          ..write('coverPath: $coverPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTableTable extends SessionsTable
    with TableInfo<$SessionsTableTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _hostDeviceIdMeta =
      const VerificationMeta('hostDeviceId');
  @override
  late final GeneratedColumn<String> hostDeviceId = GeneratedColumn<String>(
      'host_device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES books (id) ON DELETE CASCADE'));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, title, hostDeviceId, bookId, status, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(Insertable<Session> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('host_device_id')) {
      context.handle(
          _hostDeviceIdMeta,
          hostDeviceId.isAcceptableOrUnknown(
              data['host_device_id']!, _hostDeviceIdMeta));
    } else if (isInserting) {
      context.missing(_hostDeviceIdMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      hostDeviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}host_device_id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $SessionsTableTable createAlias(String alias) {
    return $SessionsTableTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final String id;
  final String title;
  final String hostDeviceId;
  final String bookId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Session(
      {required this.id,
      required this.title,
      required this.hostDeviceId,
      required this.bookId,
      required this.status,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['host_device_id'] = Variable<String>(hostDeviceId);
    map['book_id'] = Variable<String>(bookId);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SessionsTableCompanion toCompanion(bool nullToAbsent) {
    return SessionsTableCompanion(
      id: Value(id),
      title: Value(title),
      hostDeviceId: Value(hostDeviceId),
      bookId: Value(bookId),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Session.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      hostDeviceId: serializer.fromJson<String>(json['hostDeviceId']),
      bookId: serializer.fromJson<String>(json['bookId']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'hostDeviceId': serializer.toJson<String>(hostDeviceId),
      'bookId': serializer.toJson<String>(bookId),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Session copyWith(
          {String? id,
          String? title,
          String? hostDeviceId,
          String? bookId,
          String? status,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Session(
        id: id ?? this.id,
        title: title ?? this.title,
        hostDeviceId: hostDeviceId ?? this.hostDeviceId,
        bookId: bookId ?? this.bookId,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Session copyWithCompanion(SessionsTableCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      hostDeviceId: data.hostDeviceId.present
          ? data.hostDeviceId.value
          : this.hostDeviceId,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('hostDeviceId: $hostDeviceId, ')
          ..write('bookId: $bookId, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, title, hostDeviceId, bookId, status, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.title == this.title &&
          other.hostDeviceId == this.hostDeviceId &&
          other.bookId == this.bookId &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SessionsTableCompanion extends UpdateCompanion<Session> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> hostDeviceId;
  final Value<String> bookId;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SessionsTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.hostDeviceId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsTableCompanion.insert({
    required String id,
    required String title,
    required String hostDeviceId,
    required String bookId,
    required String status,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        hostDeviceId = Value(hostDeviceId),
        bookId = Value(bookId),
        status = Value(status),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Session> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? hostDeviceId,
    Expression<String>? bookId,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (hostDeviceId != null) 'host_device_id': hostDeviceId,
      if (bookId != null) 'book_id': bookId,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? hostDeviceId,
      Value<String>? bookId,
      Value<String>? status,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return SessionsTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      hostDeviceId: hostDeviceId ?? this.hostDeviceId,
      bookId: bookId ?? this.bookId,
      status: status ?? this.status,
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
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (hostDeviceId.present) {
      map['host_device_id'] = Variable<String>(hostDeviceId.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
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
    return (StringBuffer('SessionsTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('hostDeviceId: $hostDeviceId, ')
          ..write('bookId: $bookId, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionMembersTableTable extends SessionMembersTable
    with TableInfo<$SessionMembersTableTable, SessionMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionMembersTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES sessions (id) ON DELETE CASCADE'));
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
      'role', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _joinedAtMeta =
      const VerificationMeta('joinedAt');
  @override
  late final GeneratedColumn<DateTime> joinedAt = GeneratedColumn<DateTime>(
      'joined_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _lastSeenAtMeta =
      const VerificationMeta('lastSeenAt');
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
      'last_seen_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sessionId,
        deviceId,
        displayName,
        role,
        joinedAt,
        lastSeenAt,
        status
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_members';
  @override
  VerificationContext validateIntegrity(Insertable<SessionMember> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
          _roleMeta, role.isAcceptableOrUnknown(data['role']!, _roleMeta));
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('joined_at')) {
      context.handle(_joinedAtMeta,
          joinedAt.isAcceptableOrUnknown(data['joined_at']!, _joinedAtMeta));
    } else if (isInserting) {
      context.missing(_joinedAtMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
          _lastSeenAtMeta,
          lastSeenAt.isAcceptableOrUnknown(
              data['last_seen_at']!, _lastSeenAtMeta));
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionMember(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name'])!,
      role: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}role'])!,
      joinedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}joined_at'])!,
      lastSeenAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_seen_at'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
    );
  }

  @override
  $SessionMembersTableTable createAlias(String alias) {
    return $SessionMembersTableTable(attachedDatabase, alias);
  }
}

class SessionMember extends DataClass implements Insertable<SessionMember> {
  final String id;
  final String sessionId;
  final String deviceId;
  final String displayName;
  final String role;
  final DateTime joinedAt;
  final DateTime lastSeenAt;
  final String status;
  const SessionMember(
      {required this.id,
      required this.sessionId,
      required this.deviceId,
      required this.displayName,
      required this.role,
      required this.joinedAt,
      required this.lastSeenAt,
      required this.status});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['device_id'] = Variable<String>(deviceId);
    map['display_name'] = Variable<String>(displayName);
    map['role'] = Variable<String>(role);
    map['joined_at'] = Variable<DateTime>(joinedAt);
    map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    map['status'] = Variable<String>(status);
    return map;
  }

  SessionMembersTableCompanion toCompanion(bool nullToAbsent) {
    return SessionMembersTableCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      deviceId: Value(deviceId),
      displayName: Value(displayName),
      role: Value(role),
      joinedAt: Value(joinedAt),
      lastSeenAt: Value(lastSeenAt),
      status: Value(status),
    );
  }

  factory SessionMember.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionMember(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      role: serializer.fromJson<String>(json['role']),
      joinedAt: serializer.fromJson<DateTime>(json['joinedAt']),
      lastSeenAt: serializer.fromJson<DateTime>(json['lastSeenAt']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'deviceId': serializer.toJson<String>(deviceId),
      'displayName': serializer.toJson<String>(displayName),
      'role': serializer.toJson<String>(role),
      'joinedAt': serializer.toJson<DateTime>(joinedAt),
      'lastSeenAt': serializer.toJson<DateTime>(lastSeenAt),
      'status': serializer.toJson<String>(status),
    };
  }

  SessionMember copyWith(
          {String? id,
          String? sessionId,
          String? deviceId,
          String? displayName,
          String? role,
          DateTime? joinedAt,
          DateTime? lastSeenAt,
          String? status}) =>
      SessionMember(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        deviceId: deviceId ?? this.deviceId,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        joinedAt: joinedAt ?? this.joinedAt,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        status: status ?? this.status,
      );
  SessionMember copyWithCompanion(SessionMembersTableCompanion data) {
    return SessionMember(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      role: data.role.present ? data.role.value : this.role,
      joinedAt: data.joinedAt.present ? data.joinedAt.value : this.joinedAt,
      lastSeenAt:
          data.lastSeenAt.present ? data.lastSeenAt.value : this.lastSeenAt,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionMember(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('deviceId: $deviceId, ')
          ..write('displayName: $displayName, ')
          ..write('role: $role, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, sessionId, deviceId, displayName, role, joinedAt, lastSeenAt, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMember &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.deviceId == this.deviceId &&
          other.displayName == this.displayName &&
          other.role == this.role &&
          other.joinedAt == this.joinedAt &&
          other.lastSeenAt == this.lastSeenAt &&
          other.status == this.status);
}

class SessionMembersTableCompanion extends UpdateCompanion<SessionMember> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> deviceId;
  final Value<String> displayName;
  final Value<String> role;
  final Value<DateTime> joinedAt;
  final Value<DateTime> lastSeenAt;
  final Value<String> status;
  final Value<int> rowid;
  const SessionMembersTableCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.role = const Value.absent(),
    this.joinedAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionMembersTableCompanion.insert({
    required String id,
    required String sessionId,
    required String deviceId,
    required String displayName,
    required String role,
    required DateTime joinedAt,
    required DateTime lastSeenAt,
    required String status,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sessionId = Value(sessionId),
        deviceId = Value(deviceId),
        displayName = Value(displayName),
        role = Value(role),
        joinedAt = Value(joinedAt),
        lastSeenAt = Value(lastSeenAt),
        status = Value(status);
  static Insertable<SessionMember> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? deviceId,
    Expression<String>? displayName,
    Expression<String>? role,
    Expression<DateTime>? joinedAt,
    Expression<DateTime>? lastSeenAt,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (deviceId != null) 'device_id': deviceId,
      if (displayName != null) 'display_name': displayName,
      if (role != null) 'role': role,
      if (joinedAt != null) 'joined_at': joinedAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionMembersTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? sessionId,
      Value<String>? deviceId,
      Value<String>? displayName,
      Value<String>? role,
      Value<DateTime>? joinedAt,
      Value<DateTime>? lastSeenAt,
      Value<String>? status,
      Value<int>? rowid}) {
    return SessionMembersTableCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      deviceId: deviceId ?? this.deviceId,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (joinedAt.present) {
      map['joined_at'] = Variable<DateTime>(joinedAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionMembersTableCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('deviceId: $deviceId, ')
          ..write('displayName: $displayName, ')
          ..write('role: $role, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionEventsTableTable extends SessionEventsTable
    with TableInfo<$SessionEventsTableTable, SessionEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionEventsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES sessions (id) ON DELETE CASCADE'));
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _eventTypeMeta =
      const VerificationMeta('eventType');
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
      'event_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sequenceNumberMeta =
      const VerificationMeta('sequenceNumber');
  @override
  late final GeneratedColumn<int> sequenceNumber = GeneratedColumn<int>(
      'sequence_number', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, sessionId, deviceId, eventType, payload, sequenceNumber, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_events';
  @override
  VerificationContext validateIntegrity(Insertable<SessionEvent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(_eventTypeMeta,
          eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta));
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('sequence_number')) {
      context.handle(
          _sequenceNumberMeta,
          sequenceNumber.isAcceptableOrUnknown(
              data['sequence_number']!, _sequenceNumberMeta));
    } else if (isInserting) {
      context.missing(_sequenceNumberMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionEvent(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      eventType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_type'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      sequenceNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sequence_number'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $SessionEventsTableTable createAlias(String alias) {
    return $SessionEventsTableTable(attachedDatabase, alias);
  }
}

class SessionEvent extends DataClass implements Insertable<SessionEvent> {
  final String id;
  final String sessionId;
  final String deviceId;
  final String eventType;
  final String payload;
  final int sequenceNumber;
  final DateTime createdAt;
  const SessionEvent(
      {required this.id,
      required this.sessionId,
      required this.deviceId,
      required this.eventType,
      required this.payload,
      required this.sequenceNumber,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['device_id'] = Variable<String>(deviceId);
    map['event_type'] = Variable<String>(eventType);
    map['payload'] = Variable<String>(payload);
    map['sequence_number'] = Variable<int>(sequenceNumber);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SessionEventsTableCompanion toCompanion(bool nullToAbsent) {
    return SessionEventsTableCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      deviceId: Value(deviceId),
      eventType: Value(eventType),
      payload: Value(payload),
      sequenceNumber: Value(sequenceNumber),
      createdAt: Value(createdAt),
    );
  }

  factory SessionEvent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionEvent(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      eventType: serializer.fromJson<String>(json['eventType']),
      payload: serializer.fromJson<String>(json['payload']),
      sequenceNumber: serializer.fromJson<int>(json['sequenceNumber']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'deviceId': serializer.toJson<String>(deviceId),
      'eventType': serializer.toJson<String>(eventType),
      'payload': serializer.toJson<String>(payload),
      'sequenceNumber': serializer.toJson<int>(sequenceNumber),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SessionEvent copyWith(
          {String? id,
          String? sessionId,
          String? deviceId,
          String? eventType,
          String? payload,
          int? sequenceNumber,
          DateTime? createdAt}) =>
      SessionEvent(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        deviceId: deviceId ?? this.deviceId,
        eventType: eventType ?? this.eventType,
        payload: payload ?? this.payload,
        sequenceNumber: sequenceNumber ?? this.sequenceNumber,
        createdAt: createdAt ?? this.createdAt,
      );
  SessionEvent copyWithCompanion(SessionEventsTableCompanion data) {
    return SessionEvent(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      payload: data.payload.present ? data.payload.value : this.payload,
      sequenceNumber: data.sequenceNumber.present
          ? data.sequenceNumber.value
          : this.sequenceNumber,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionEvent(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('deviceId: $deviceId, ')
          ..write('eventType: $eventType, ')
          ..write('payload: $payload, ')
          ..write('sequenceNumber: $sequenceNumber, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, sessionId, deviceId, eventType, payload, sequenceNumber, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionEvent &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.deviceId == this.deviceId &&
          other.eventType == this.eventType &&
          other.payload == this.payload &&
          other.sequenceNumber == this.sequenceNumber &&
          other.createdAt == this.createdAt);
}

class SessionEventsTableCompanion extends UpdateCompanion<SessionEvent> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> deviceId;
  final Value<String> eventType;
  final Value<String> payload;
  final Value<int> sequenceNumber;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SessionEventsTableCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.eventType = const Value.absent(),
    this.payload = const Value.absent(),
    this.sequenceNumber = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionEventsTableCompanion.insert({
    required String id,
    required String sessionId,
    required String deviceId,
    required String eventType,
    required String payload,
    required int sequenceNumber,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sessionId = Value(sessionId),
        deviceId = Value(deviceId),
        eventType = Value(eventType),
        payload = Value(payload),
        sequenceNumber = Value(sequenceNumber),
        createdAt = Value(createdAt);
  static Insertable<SessionEvent> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? deviceId,
    Expression<String>? eventType,
    Expression<String>? payload,
    Expression<int>? sequenceNumber,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (deviceId != null) 'device_id': deviceId,
      if (eventType != null) 'event_type': eventType,
      if (payload != null) 'payload': payload,
      if (sequenceNumber != null) 'sequence_number': sequenceNumber,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionEventsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? sessionId,
      Value<String>? deviceId,
      Value<String>? eventType,
      Value<String>? payload,
      Value<int>? sequenceNumber,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return SessionEventsTableCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      deviceId: deviceId ?? this.deviceId,
      eventType: eventType ?? this.eventType,
      payload: payload ?? this.payload,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
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
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (sequenceNumber.present) {
      map['sequence_number'] = Variable<int>(sequenceNumber.value);
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
    return (StringBuffer('SessionEventsTableCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('deviceId: $deviceId, ')
          ..write('eventType: $eventType, ')
          ..write('payload: $payload, ')
          ..write('sequenceNumber: $sequenceNumber, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTableTable extends OutboxTable
    with TableInfo<$OutboxTableTable, OutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES sessions (id) ON DELETE CASCADE'));
  static const VerificationMeta _messageTypeMeta =
      const VerificationMeta('messageType');
  @override
  late final GeneratedColumn<String> messageType = GeneratedColumn<String>(
      'message_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _retryCountMeta =
      const VerificationMeta('retryCount');
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
      'retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sessionId,
        messageType,
        payload,
        status,
        retryCount,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    }
    if (data.containsKey('message_type')) {
      context.handle(
          _messageTypeMeta,
          messageType.isAcceptableOrUnknown(
              data['message_type']!, _messageTypeMeta));
    } else if (isInserting) {
      context.missing(_messageTypeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
          _retryCountMeta,
          retryCount.isAcceptableOrUnknown(
              data['retry_count']!, _retryCountMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id']),
      messageType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_type'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      retryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}retry_count'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $OutboxTableTable createAlias(String alias) {
    return $OutboxTableTable(attachedDatabase, alias);
  }
}

class OutboxEntry extends DataClass implements Insertable<OutboxEntry> {
  final String id;
  final String? sessionId;
  final String messageType;
  final String payload;
  final String status;
  final int retryCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  const OutboxEntry(
      {required this.id,
      this.sessionId,
      required this.messageType,
      required this.payload,
      required this.status,
      required this.retryCount,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    map['message_type'] = Variable<String>(messageType);
    map['payload'] = Variable<String>(payload);
    map['status'] = Variable<String>(status);
    map['retry_count'] = Variable<int>(retryCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  OutboxTableCompanion toCompanion(bool nullToAbsent) {
    return OutboxTableCompanion(
      id: Value(id),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      messageType: Value(messageType),
      payload: Value(payload),
      status: Value(status),
      retryCount: Value(retryCount),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory OutboxEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEntry(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
      messageType: serializer.fromJson<String>(json['messageType']),
      payload: serializer.fromJson<String>(json['payload']),
      status: serializer.fromJson<String>(json['status']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String?>(sessionId),
      'messageType': serializer.toJson<String>(messageType),
      'payload': serializer.toJson<String>(payload),
      'status': serializer.toJson<String>(status),
      'retryCount': serializer.toJson<int>(retryCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  OutboxEntry copyWith(
          {String? id,
          Value<String?> sessionId = const Value.absent(),
          String? messageType,
          String? payload,
          String? status,
          int? retryCount,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      OutboxEntry(
        id: id ?? this.id,
        sessionId: sessionId.present ? sessionId.value : this.sessionId,
        messageType: messageType ?? this.messageType,
        payload: payload ?? this.payload,
        status: status ?? this.status,
        retryCount: retryCount ?? this.retryCount,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  OutboxEntry copyWithCompanion(OutboxTableCompanion data) {
    return OutboxEntry(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      messageType:
          data.messageType.present ? data.messageType.value : this.messageType,
      payload: data.payload.present ? data.payload.value : this.payload,
      status: data.status.present ? data.status.value : this.status,
      retryCount:
          data.retryCount.present ? data.retryCount.value : this.retryCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntry(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('messageType: $messageType, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, messageType, payload, status,
      retryCount, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEntry &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.messageType == this.messageType &&
          other.payload == this.payload &&
          other.status == this.status &&
          other.retryCount == this.retryCount &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class OutboxTableCompanion extends UpdateCompanion<OutboxEntry> {
  final Value<String> id;
  final Value<String?> sessionId;
  final Value<String> messageType;
  final Value<String> payload;
  final Value<String> status;
  final Value<int> retryCount;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const OutboxTableCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.messageType = const Value.absent(),
    this.payload = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxTableCompanion.insert({
    required String id,
    this.sessionId = const Value.absent(),
    required String messageType,
    required String payload,
    required String status,
    this.retryCount = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        messageType = Value(messageType),
        payload = Value(payload),
        status = Value(status),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<OutboxEntry> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? messageType,
    Expression<String>? payload,
    Expression<String>? status,
    Expression<int>? retryCount,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (messageType != null) 'message_type': messageType,
      if (payload != null) 'payload': payload,
      if (status != null) 'status': status,
      if (retryCount != null) 'retry_count': retryCount,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxTableCompanion copyWith(
      {Value<String>? id,
      Value<String?>? sessionId,
      Value<String>? messageType,
      Value<String>? payload,
      Value<String>? status,
      Value<int>? retryCount,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return OutboxTableCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      messageType: messageType ?? this.messageType,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
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
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (messageType.present) {
      map['message_type'] = Variable<String>(messageType.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
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
    return (StringBuffer('OutboxTableCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('messageType: $messageType, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingProgressTableTable extends ReadingProgressTable
    with TableInfo<$ReadingProgressTableTable, ReadingProgress> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingProgressTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES sessions (id) ON DELETE CASCADE'));
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES books (id) ON DELETE CASCADE'));
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _currentPageMeta =
      const VerificationMeta('currentPage');
  @override
  late final GeneratedColumn<int> currentPage = GeneratedColumn<int>(
      'current_page', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _totalPagesMeta =
      const VerificationMeta('totalPages');
  @override
  late final GeneratedColumn<int> totalPages = GeneratedColumn<int>(
      'total_pages', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _percentageMeta =
      const VerificationMeta('percentage');
  @override
  late final GeneratedColumn<double> percentage = GeneratedColumn<double>(
      'percentage', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sessionId,
        bookId,
        deviceId,
        currentPage,
        totalPages,
        percentage,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_progress';
  @override
  VerificationContext validateIntegrity(Insertable<ReadingProgress> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('current_page')) {
      context.handle(
          _currentPageMeta,
          currentPage.isAcceptableOrUnknown(
              data['current_page']!, _currentPageMeta));
    } else if (isInserting) {
      context.missing(_currentPageMeta);
    }
    if (data.containsKey('total_pages')) {
      context.handle(
          _totalPagesMeta,
          totalPages.isAcceptableOrUnknown(
              data['total_pages']!, _totalPagesMeta));
    } else if (isInserting) {
      context.missing(_totalPagesMeta);
    }
    if (data.containsKey('percentage')) {
      context.handle(
          _percentageMeta,
          percentage.isAcceptableOrUnknown(
              data['percentage']!, _percentageMeta));
    } else if (isInserting) {
      context.missing(_percentageMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReadingProgress map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingProgress(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      currentPage: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}current_page'])!,
      totalPages: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_pages'])!,
      percentage: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}percentage'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ReadingProgressTableTable createAlias(String alias) {
    return $ReadingProgressTableTable(attachedDatabase, alias);
  }
}

class ReadingProgress extends DataClass implements Insertable<ReadingProgress> {
  final String id;
  final String sessionId;
  final String bookId;
  final String deviceId;
  final int currentPage;
  final int totalPages;
  final double percentage;
  final DateTime updatedAt;
  const ReadingProgress(
      {required this.id,
      required this.sessionId,
      required this.bookId,
      required this.deviceId,
      required this.currentPage,
      required this.totalPages,
      required this.percentage,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['book_id'] = Variable<String>(bookId);
    map['device_id'] = Variable<String>(deviceId);
    map['current_page'] = Variable<int>(currentPage);
    map['total_pages'] = Variable<int>(totalPages);
    map['percentage'] = Variable<double>(percentage);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ReadingProgressTableCompanion toCompanion(bool nullToAbsent) {
    return ReadingProgressTableCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      bookId: Value(bookId),
      deviceId: Value(deviceId),
      currentPage: Value(currentPage),
      totalPages: Value(totalPages),
      percentage: Value(percentage),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReadingProgress.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingProgress(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      bookId: serializer.fromJson<String>(json['bookId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      currentPage: serializer.fromJson<int>(json['currentPage']),
      totalPages: serializer.fromJson<int>(json['totalPages']),
      percentage: serializer.fromJson<double>(json['percentage']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'bookId': serializer.toJson<String>(bookId),
      'deviceId': serializer.toJson<String>(deviceId),
      'currentPage': serializer.toJson<int>(currentPage),
      'totalPages': serializer.toJson<int>(totalPages),
      'percentage': serializer.toJson<double>(percentage),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ReadingProgress copyWith(
          {String? id,
          String? sessionId,
          String? bookId,
          String? deviceId,
          int? currentPage,
          int? totalPages,
          double? percentage,
          DateTime? updatedAt}) =>
      ReadingProgress(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        bookId: bookId ?? this.bookId,
        deviceId: deviceId ?? this.deviceId,
        currentPage: currentPage ?? this.currentPage,
        totalPages: totalPages ?? this.totalPages,
        percentage: percentage ?? this.percentage,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ReadingProgress copyWithCompanion(ReadingProgressTableCompanion data) {
    return ReadingProgress(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      currentPage:
          data.currentPage.present ? data.currentPage.value : this.currentPage,
      totalPages:
          data.totalPages.present ? data.totalPages.value : this.totalPages,
      percentage:
          data.percentage.present ? data.percentage.value : this.percentage,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgress(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('bookId: $bookId, ')
          ..write('deviceId: $deviceId, ')
          ..write('currentPage: $currentPage, ')
          ..write('totalPages: $totalPages, ')
          ..write('percentage: $percentage, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, bookId, deviceId, currentPage,
      totalPages, percentage, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingProgress &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.bookId == this.bookId &&
          other.deviceId == this.deviceId &&
          other.currentPage == this.currentPage &&
          other.totalPages == this.totalPages &&
          other.percentage == this.percentage &&
          other.updatedAt == this.updatedAt);
}

class ReadingProgressTableCompanion extends UpdateCompanion<ReadingProgress> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> bookId;
  final Value<String> deviceId;
  final Value<int> currentPage;
  final Value<int> totalPages;
  final Value<double> percentage;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ReadingProgressTableCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.currentPage = const Value.absent(),
    this.totalPages = const Value.absent(),
    this.percentage = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingProgressTableCompanion.insert({
    required String id,
    required String sessionId,
    required String bookId,
    required String deviceId,
    required int currentPage,
    required int totalPages,
    required double percentage,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sessionId = Value(sessionId),
        bookId = Value(bookId),
        deviceId = Value(deviceId),
        currentPage = Value(currentPage),
        totalPages = Value(totalPages),
        percentage = Value(percentage),
        updatedAt = Value(updatedAt);
  static Insertable<ReadingProgress> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? bookId,
    Expression<String>? deviceId,
    Expression<int>? currentPage,
    Expression<int>? totalPages,
    Expression<double>? percentage,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (bookId != null) 'book_id': bookId,
      if (deviceId != null) 'device_id': deviceId,
      if (currentPage != null) 'current_page': currentPage,
      if (totalPages != null) 'total_pages': totalPages,
      if (percentage != null) 'percentage': percentage,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingProgressTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? sessionId,
      Value<String>? bookId,
      Value<String>? deviceId,
      Value<int>? currentPage,
      Value<int>? totalPages,
      Value<double>? percentage,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ReadingProgressTableCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      bookId: bookId ?? this.bookId,
      deviceId: deviceId ?? this.deviceId,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      percentage: percentage ?? this.percentage,
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
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (currentPage.present) {
      map['current_page'] = Variable<int>(currentPage.value);
    }
    if (totalPages.present) {
      map['total_pages'] = Variable<int>(totalPages.value);
    }
    if (percentage.present) {
      map['percentage'] = Variable<double>(percentage.value);
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
    return (StringBuffer('ReadingProgressTableCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('bookId: $bookId, ')
          ..write('deviceId: $deviceId, ')
          ..write('currentPage: $currentPage, ')
          ..write('totalPages: $totalPages, ')
          ..write('percentage: $percentage, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ParticipantReadingTimeTableTable extends ParticipantReadingTimeTable
    with TableInfo<$ParticipantReadingTimeTableTable, ParticipantReadingTime> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ParticipantReadingTimeTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES sessions (id) ON DELETE CASCADE'));
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _totalSecondsMeta =
      const VerificationMeta('totalSeconds');
  @override
  late final GeneratedColumn<int> totalSeconds = GeneratedColumn<int>(
      'total_seconds', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastActiveAtMeta =
      const VerificationMeta('lastActiveAt');
  @override
  late final GeneratedColumn<DateTime> lastActiveAt = GeneratedColumn<DateTime>(
      'last_active_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, sessionId, deviceId, totalSeconds, lastActiveAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'participant_reading_time';
  @override
  VerificationContext validateIntegrity(
      Insertable<ParticipantReadingTime> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('total_seconds')) {
      context.handle(
          _totalSecondsMeta,
          totalSeconds.isAcceptableOrUnknown(
              data['total_seconds']!, _totalSecondsMeta));
    }
    if (data.containsKey('last_active_at')) {
      context.handle(
          _lastActiveAtMeta,
          lastActiveAt.isAcceptableOrUnknown(
              data['last_active_at']!, _lastActiveAtMeta));
    } else if (isInserting) {
      context.missing(_lastActiveAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ParticipantReadingTime map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ParticipantReadingTime(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      totalSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_seconds'])!,
      lastActiveAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_active_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ParticipantReadingTimeTableTable createAlias(String alias) {
    return $ParticipantReadingTimeTableTable(attachedDatabase, alias);
  }
}

class ParticipantReadingTime extends DataClass
    implements Insertable<ParticipantReadingTime> {
  final String id;
  final String sessionId;
  final String deviceId;
  final int totalSeconds;
  final DateTime lastActiveAt;
  final DateTime updatedAt;
  const ParticipantReadingTime(
      {required this.id,
      required this.sessionId,
      required this.deviceId,
      required this.totalSeconds,
      required this.lastActiveAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['device_id'] = Variable<String>(deviceId);
    map['total_seconds'] = Variable<int>(totalSeconds);
    map['last_active_at'] = Variable<DateTime>(lastActiveAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ParticipantReadingTimeTableCompanion toCompanion(bool nullToAbsent) {
    return ParticipantReadingTimeTableCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      deviceId: Value(deviceId),
      totalSeconds: Value(totalSeconds),
      lastActiveAt: Value(lastActiveAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ParticipantReadingTime.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ParticipantReadingTime(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      totalSeconds: serializer.fromJson<int>(json['totalSeconds']),
      lastActiveAt: serializer.fromJson<DateTime>(json['lastActiveAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'deviceId': serializer.toJson<String>(deviceId),
      'totalSeconds': serializer.toJson<int>(totalSeconds),
      'lastActiveAt': serializer.toJson<DateTime>(lastActiveAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ParticipantReadingTime copyWith(
          {String? id,
          String? sessionId,
          String? deviceId,
          int? totalSeconds,
          DateTime? lastActiveAt,
          DateTime? updatedAt}) =>
      ParticipantReadingTime(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        deviceId: deviceId ?? this.deviceId,
        totalSeconds: totalSeconds ?? this.totalSeconds,
        lastActiveAt: lastActiveAt ?? this.lastActiveAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ParticipantReadingTime copyWithCompanion(
      ParticipantReadingTimeTableCompanion data) {
    return ParticipantReadingTime(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      totalSeconds: data.totalSeconds.present
          ? data.totalSeconds.value
          : this.totalSeconds,
      lastActiveAt: data.lastActiveAt.present
          ? data.lastActiveAt.value
          : this.lastActiveAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ParticipantReadingTime(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('deviceId: $deviceId, ')
          ..write('totalSeconds: $totalSeconds, ')
          ..write('lastActiveAt: $lastActiveAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, sessionId, deviceId, totalSeconds, lastActiveAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ParticipantReadingTime &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.deviceId == this.deviceId &&
          other.totalSeconds == this.totalSeconds &&
          other.lastActiveAt == this.lastActiveAt &&
          other.updatedAt == this.updatedAt);
}

class ParticipantReadingTimeTableCompanion
    extends UpdateCompanion<ParticipantReadingTime> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> deviceId;
  final Value<int> totalSeconds;
  final Value<DateTime> lastActiveAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ParticipantReadingTimeTableCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.totalSeconds = const Value.absent(),
    this.lastActiveAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ParticipantReadingTimeTableCompanion.insert({
    required String id,
    required String sessionId,
    required String deviceId,
    this.totalSeconds = const Value.absent(),
    required DateTime lastActiveAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sessionId = Value(sessionId),
        deviceId = Value(deviceId),
        lastActiveAt = Value(lastActiveAt),
        updatedAt = Value(updatedAt);
  static Insertable<ParticipantReadingTime> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? deviceId,
    Expression<int>? totalSeconds,
    Expression<DateTime>? lastActiveAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (deviceId != null) 'device_id': deviceId,
      if (totalSeconds != null) 'total_seconds': totalSeconds,
      if (lastActiveAt != null) 'last_active_at': lastActiveAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ParticipantReadingTimeTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? sessionId,
      Value<String>? deviceId,
      Value<int>? totalSeconds,
      Value<DateTime>? lastActiveAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ParticipantReadingTimeTableCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      deviceId: deviceId ?? this.deviceId,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
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
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (totalSeconds.present) {
      map['total_seconds'] = Variable<int>(totalSeconds.value);
    }
    if (lastActiveAt.present) {
      map['last_active_at'] = Variable<DateTime>(lastActiveAt.value);
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
    return (StringBuffer('ParticipantReadingTimeTableCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('deviceId: $deviceId, ')
          ..write('totalSeconds: $totalSeconds, ')
          ..write('lastActiveAt: $lastActiveAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PageActivityTableTable extends PageActivityTable
    with TableInfo<$PageActivityTableTable, PageActivity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PageActivityTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES sessions (id) ON DELETE CASCADE'));
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES books (id) ON DELETE CASCADE'));
  static const VerificationMeta _pageNumberMeta =
      const VerificationMeta('pageNumber');
  @override
  late final GeneratedColumn<int> pageNumber = GeneratedColumn<int>(
      'page_number', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _durationSecondsMeta =
      const VerificationMeta('durationSeconds');
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
      'duration_seconds', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, sessionId, bookId, pageNumber, deviceId, durationSeconds, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'page_activity';
  @override
  VerificationContext validateIntegrity(Insertable<PageActivity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('page_number')) {
      context.handle(
          _pageNumberMeta,
          pageNumber.isAcceptableOrUnknown(
              data['page_number']!, _pageNumberMeta));
    } else if (isInserting) {
      context.missing(_pageNumberMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
          _durationSecondsMeta,
          durationSeconds.isAcceptableOrUnknown(
              data['duration_seconds']!, _durationSecondsMeta));
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PageActivity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PageActivity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      pageNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}page_number'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      durationSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_seconds'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $PageActivityTableTable createAlias(String alias) {
    return $PageActivityTableTable(attachedDatabase, alias);
  }
}

class PageActivity extends DataClass implements Insertable<PageActivity> {
  final String id;
  final String sessionId;
  final String bookId;
  final int pageNumber;
  final String deviceId;
  final int durationSeconds;
  final DateTime createdAt;
  const PageActivity(
      {required this.id,
      required this.sessionId,
      required this.bookId,
      required this.pageNumber,
      required this.deviceId,
      required this.durationSeconds,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['book_id'] = Variable<String>(bookId);
    map['page_number'] = Variable<int>(pageNumber);
    map['device_id'] = Variable<String>(deviceId);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PageActivityTableCompanion toCompanion(bool nullToAbsent) {
    return PageActivityTableCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      bookId: Value(bookId),
      pageNumber: Value(pageNumber),
      deviceId: Value(deviceId),
      durationSeconds: Value(durationSeconds),
      createdAt: Value(createdAt),
    );
  }

  factory PageActivity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PageActivity(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      bookId: serializer.fromJson<String>(json['bookId']),
      pageNumber: serializer.fromJson<int>(json['pageNumber']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'bookId': serializer.toJson<String>(bookId),
      'pageNumber': serializer.toJson<int>(pageNumber),
      'deviceId': serializer.toJson<String>(deviceId),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PageActivity copyWith(
          {String? id,
          String? sessionId,
          String? bookId,
          int? pageNumber,
          String? deviceId,
          int? durationSeconds,
          DateTime? createdAt}) =>
      PageActivity(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        bookId: bookId ?? this.bookId,
        pageNumber: pageNumber ?? this.pageNumber,
        deviceId: deviceId ?? this.deviceId,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        createdAt: createdAt ?? this.createdAt,
      );
  PageActivity copyWithCompanion(PageActivityTableCompanion data) {
    return PageActivity(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      pageNumber:
          data.pageNumber.present ? data.pageNumber.value : this.pageNumber,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PageActivity(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('bookId: $bookId, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('deviceId: $deviceId, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, sessionId, bookId, pageNumber, deviceId, durationSeconds, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PageActivity &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.bookId == this.bookId &&
          other.pageNumber == this.pageNumber &&
          other.deviceId == this.deviceId &&
          other.durationSeconds == this.durationSeconds &&
          other.createdAt == this.createdAt);
}

class PageActivityTableCompanion extends UpdateCompanion<PageActivity> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> bookId;
  final Value<int> pageNumber;
  final Value<String> deviceId;
  final Value<int> durationSeconds;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PageActivityTableCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.pageNumber = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PageActivityTableCompanion.insert({
    required String id,
    required String sessionId,
    required String bookId,
    required int pageNumber,
    required String deviceId,
    required int durationSeconds,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sessionId = Value(sessionId),
        bookId = Value(bookId),
        pageNumber = Value(pageNumber),
        deviceId = Value(deviceId),
        durationSeconds = Value(durationSeconds),
        createdAt = Value(createdAt);
  static Insertable<PageActivity> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? bookId,
    Expression<int>? pageNumber,
    Expression<String>? deviceId,
    Expression<int>? durationSeconds,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (bookId != null) 'book_id': bookId,
      if (pageNumber != null) 'page_number': pageNumber,
      if (deviceId != null) 'device_id': deviceId,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PageActivityTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? sessionId,
      Value<String>? bookId,
      Value<int>? pageNumber,
      Value<String>? deviceId,
      Value<int>? durationSeconds,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return PageActivityTableCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      bookId: bookId ?? this.bookId,
      pageNumber: pageNumber ?? this.pageNumber,
      deviceId: deviceId ?? this.deviceId,
      durationSeconds: durationSeconds ?? this.durationSeconds,
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
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (pageNumber.present) {
      map['page_number'] = Variable<int>(pageNumber.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
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
    return (StringBuffer('PageActivityTableCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('bookId: $bookId, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('deviceId: $deviceId, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTableTable extends MessagesTable
    with TableInfo<$MessagesTableTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES sessions (id) ON DELETE CASCADE'));
  static const VerificationMeta _senderIdMeta =
      const VerificationMeta('senderId');
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
      'sender_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _senderNameMeta =
      const VerificationMeta('senderName');
  @override
  late final GeneratedColumn<String> senderName = GeneratedColumn<String>(
      'sender_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _messageTypeMeta =
      const VerificationMeta('messageType');
  @override
  late final GeneratedColumn<String> messageType = GeneratedColumn<String>(
      'message_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, sessionId, senderId, senderName, content, messageType, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(Insertable<Message> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(_senderIdMeta,
          senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta));
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('sender_name')) {
      context.handle(
          _senderNameMeta,
          senderName.isAcceptableOrUnknown(
              data['sender_name']!, _senderNameMeta));
    } else if (isInserting) {
      context.missing(_senderNameMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('message_type')) {
      context.handle(
          _messageTypeMeta,
          messageType.isAcceptableOrUnknown(
              data['message_type']!, _messageTypeMeta));
    } else if (isInserting) {
      context.missing(_messageTypeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      senderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_id'])!,
      senderName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_name'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      messageType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_type'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $MessagesTableTable createAlias(String alias) {
    return $MessagesTableTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final String id;
  final String sessionId;
  final String senderId;
  final String senderName;
  final String content;
  final String messageType;
  final DateTime createdAt;
  const Message(
      {required this.id,
      required this.sessionId,
      required this.senderId,
      required this.senderName,
      required this.content,
      required this.messageType,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['sender_id'] = Variable<String>(senderId);
    map['sender_name'] = Variable<String>(senderName);
    map['content'] = Variable<String>(content);
    map['message_type'] = Variable<String>(messageType);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MessagesTableCompanion toCompanion(bool nullToAbsent) {
    return MessagesTableCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      senderId: Value(senderId),
      senderName: Value(senderName),
      content: Value(content),
      messageType: Value(messageType),
      createdAt: Value(createdAt),
    );
  }

  factory Message.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      senderId: serializer.fromJson<String>(json['senderId']),
      senderName: serializer.fromJson<String>(json['senderName']),
      content: serializer.fromJson<String>(json['content']),
      messageType: serializer.fromJson<String>(json['messageType']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'senderId': serializer.toJson<String>(senderId),
      'senderName': serializer.toJson<String>(senderName),
      'content': serializer.toJson<String>(content),
      'messageType': serializer.toJson<String>(messageType),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Message copyWith(
          {String? id,
          String? sessionId,
          String? senderId,
          String? senderName,
          String? content,
          String? messageType,
          DateTime? createdAt}) =>
      Message(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        senderId: senderId ?? this.senderId,
        senderName: senderName ?? this.senderName,
        content: content ?? this.content,
        messageType: messageType ?? this.messageType,
        createdAt: createdAt ?? this.createdAt,
      );
  Message copyWithCompanion(MessagesTableCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      senderName:
          data.senderName.present ? data.senderName.value : this.senderName,
      content: data.content.present ? data.content.value : this.content,
      messageType:
          data.messageType.present ? data.messageType.value : this.messageType,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('senderId: $senderId, ')
          ..write('senderName: $senderName, ')
          ..write('content: $content, ')
          ..write('messageType: $messageType, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, sessionId, senderId, senderName, content, messageType, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.senderId == this.senderId &&
          other.senderName == this.senderName &&
          other.content == this.content &&
          other.messageType == this.messageType &&
          other.createdAt == this.createdAt);
}

class MessagesTableCompanion extends UpdateCompanion<Message> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> senderId;
  final Value<String> senderName;
  final Value<String> content;
  final Value<String> messageType;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const MessagesTableCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.senderName = const Value.absent(),
    this.content = const Value.absent(),
    this.messageType = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesTableCompanion.insert({
    required String id,
    required String sessionId,
    required String senderId,
    required String senderName,
    required String content,
    required String messageType,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sessionId = Value(sessionId),
        senderId = Value(senderId),
        senderName = Value(senderName),
        content = Value(content),
        messageType = Value(messageType),
        createdAt = Value(createdAt);
  static Insertable<Message> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? senderId,
    Expression<String>? senderName,
    Expression<String>? content,
    Expression<String>? messageType,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (senderId != null) 'sender_id': senderId,
      if (senderName != null) 'sender_name': senderName,
      if (content != null) 'content': content,
      if (messageType != null) 'message_type': messageType,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? sessionId,
      Value<String>? senderId,
      Value<String>? senderName,
      Value<String>? content,
      Value<String>? messageType,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return MessagesTableCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
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
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (senderName.present) {
      map['sender_name'] = Variable<String>(senderName.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (messageType.present) {
      map['message_type'] = Variable<String>(messageType.value);
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
    return (StringBuffer('MessagesTableCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('senderId: $senderId, ')
          ..write('senderName: $senderName, ')
          ..write('content: $content, ')
          ..write('messageType: $messageType, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotesTableTable extends NotesTable
    with TableInfo<$NotesTableTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES books (id) ON DELETE CASCADE'));
  static const VerificationMeta _pageNumberMeta =
      const VerificationMeta('pageNumber');
  @override
  late final GeneratedColumn<int> pageNumber = GeneratedColumn<int>(
      'page_number', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _authorNameMeta =
      const VerificationMeta('authorName');
  @override
  late final GeneratedColumn<String> authorName = GeneratedColumn<String>(
      'author_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
      'color', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _positionXMeta =
      const VerificationMeta('positionX');
  @override
  late final GeneratedColumn<double> positionX = GeneratedColumn<double>(
      'position_x', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _positionYMeta =
      const VerificationMeta('positionY');
  @override
  late final GeneratedColumn<double> positionY = GeneratedColumn<double>(
      'position_y', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        bookId,
        pageNumber,
        deviceId,
        authorName,
        content,
        color,
        positionX,
        positionY,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(Insertable<Note> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('page_number')) {
      context.handle(
          _pageNumberMeta,
          pageNumber.isAcceptableOrUnknown(
              data['page_number']!, _pageNumberMeta));
    } else if (isInserting) {
      context.missing(_pageNumberMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('author_name')) {
      context.handle(
          _authorNameMeta,
          authorName.isAcceptableOrUnknown(
              data['author_name']!, _authorNameMeta));
    } else if (isInserting) {
      context.missing(_authorNameMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('position_x')) {
      context.handle(_positionXMeta,
          positionX.isAcceptableOrUnknown(data['position_x']!, _positionXMeta));
    }
    if (data.containsKey('position_y')) {
      context.handle(_positionYMeta,
          positionY.isAcceptableOrUnknown(data['position_y']!, _positionYMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      pageNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}page_number'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      authorName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author_name'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color'])!,
      positionX: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}position_x']),
      positionY: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}position_y']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $NotesTableTable createAlias(String alias) {
    return $NotesTableTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  final String id;
  final String bookId;
  final int pageNumber;
  final String deviceId;
  final String authorName;
  final String content;
  final String color;
  final double? positionX;
  final double? positionY;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Note(
      {required this.id,
      required this.bookId,
      required this.pageNumber,
      required this.deviceId,
      required this.authorName,
      required this.content,
      required this.color,
      this.positionX,
      this.positionY,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['page_number'] = Variable<int>(pageNumber);
    map['device_id'] = Variable<String>(deviceId);
    map['author_name'] = Variable<String>(authorName);
    map['content'] = Variable<String>(content);
    map['color'] = Variable<String>(color);
    if (!nullToAbsent || positionX != null) {
      map['position_x'] = Variable<double>(positionX);
    }
    if (!nullToAbsent || positionY != null) {
      map['position_y'] = Variable<double>(positionY);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  NotesTableCompanion toCompanion(bool nullToAbsent) {
    return NotesTableCompanion(
      id: Value(id),
      bookId: Value(bookId),
      pageNumber: Value(pageNumber),
      deviceId: Value(deviceId),
      authorName: Value(authorName),
      content: Value(content),
      color: Value(color),
      positionX: positionX == null && nullToAbsent
          ? const Value.absent()
          : Value(positionX),
      positionY: positionY == null && nullToAbsent
          ? const Value.absent()
          : Value(positionY),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Note.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      pageNumber: serializer.fromJson<int>(json['pageNumber']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      authorName: serializer.fromJson<String>(json['authorName']),
      content: serializer.fromJson<String>(json['content']),
      color: serializer.fromJson<String>(json['color']),
      positionX: serializer.fromJson<double?>(json['positionX']),
      positionY: serializer.fromJson<double?>(json['positionY']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'pageNumber': serializer.toJson<int>(pageNumber),
      'deviceId': serializer.toJson<String>(deviceId),
      'authorName': serializer.toJson<String>(authorName),
      'content': serializer.toJson<String>(content),
      'color': serializer.toJson<String>(color),
      'positionX': serializer.toJson<double?>(positionX),
      'positionY': serializer.toJson<double?>(positionY),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Note copyWith(
          {String? id,
          String? bookId,
          int? pageNumber,
          String? deviceId,
          String? authorName,
          String? content,
          String? color,
          Value<double?> positionX = const Value.absent(),
          Value<double?> positionY = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Note(
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        pageNumber: pageNumber ?? this.pageNumber,
        deviceId: deviceId ?? this.deviceId,
        authorName: authorName ?? this.authorName,
        content: content ?? this.content,
        color: color ?? this.color,
        positionX: positionX.present ? positionX.value : this.positionX,
        positionY: positionY.present ? positionY.value : this.positionY,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Note copyWithCompanion(NotesTableCompanion data) {
    return Note(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      pageNumber:
          data.pageNumber.present ? data.pageNumber.value : this.pageNumber,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      authorName:
          data.authorName.present ? data.authorName.value : this.authorName,
      content: data.content.present ? data.content.value : this.content,
      color: data.color.present ? data.color.value : this.color,
      positionX: data.positionX.present ? data.positionX.value : this.positionX,
      positionY: data.positionY.present ? data.positionY.value : this.positionY,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('deviceId: $deviceId, ')
          ..write('authorName: $authorName, ')
          ..write('content: $content, ')
          ..write('color: $color, ')
          ..write('positionX: $positionX, ')
          ..write('positionY: $positionY, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, bookId, pageNumber, deviceId, authorName,
      content, color, positionX, positionY, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.pageNumber == this.pageNumber &&
          other.deviceId == this.deviceId &&
          other.authorName == this.authorName &&
          other.content == this.content &&
          other.color == this.color &&
          other.positionX == this.positionX &&
          other.positionY == this.positionY &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class NotesTableCompanion extends UpdateCompanion<Note> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<int> pageNumber;
  final Value<String> deviceId;
  final Value<String> authorName;
  final Value<String> content;
  final Value<String> color;
  final Value<double?> positionX;
  final Value<double?> positionY;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const NotesTableCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.pageNumber = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.authorName = const Value.absent(),
    this.content = const Value.absent(),
    this.color = const Value.absent(),
    this.positionX = const Value.absent(),
    this.positionY = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotesTableCompanion.insert({
    required String id,
    required String bookId,
    required int pageNumber,
    required String deviceId,
    required String authorName,
    required String content,
    required String color,
    this.positionX = const Value.absent(),
    this.positionY = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        bookId = Value(bookId),
        pageNumber = Value(pageNumber),
        deviceId = Value(deviceId),
        authorName = Value(authorName),
        content = Value(content),
        color = Value(color),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Note> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<int>? pageNumber,
    Expression<String>? deviceId,
    Expression<String>? authorName,
    Expression<String>? content,
    Expression<String>? color,
    Expression<double>? positionX,
    Expression<double>? positionY,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (pageNumber != null) 'page_number': pageNumber,
      if (deviceId != null) 'device_id': deviceId,
      if (authorName != null) 'author_name': authorName,
      if (content != null) 'content': content,
      if (color != null) 'color': color,
      if (positionX != null) 'position_x': positionX,
      if (positionY != null) 'position_y': positionY,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotesTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? bookId,
      Value<int>? pageNumber,
      Value<String>? deviceId,
      Value<String>? authorName,
      Value<String>? content,
      Value<String>? color,
      Value<double?>? positionX,
      Value<double?>? positionY,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return NotesTableCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      pageNumber: pageNumber ?? this.pageNumber,
      deviceId: deviceId ?? this.deviceId,
      authorName: authorName ?? this.authorName,
      content: content ?? this.content,
      color: color ?? this.color,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
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
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (pageNumber.present) {
      map['page_number'] = Variable<int>(pageNumber.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (authorName.present) {
      map['author_name'] = Variable<String>(authorName.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (positionX.present) {
      map['position_x'] = Variable<double>(positionX.value);
    }
    if (positionY.present) {
      map['position_y'] = Variable<double>(positionY.value);
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
    return (StringBuffer('NotesTableCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('deviceId: $deviceId, ')
          ..write('authorName: $authorName, ')
          ..write('content: $content, ')
          ..write('color: $color, ')
          ..write('positionX: $positionX, ')
          ..write('positionY: $positionY, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KvsTableTable extends KvsTable with TableInfo<$KvsTableTable, KvsEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KvsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kvs';
  @override
  VerificationContext validateIntegrity(Insertable<KvsEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  KvsEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KvsEntry(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $KvsTableTable createAlias(String alias) {
    return $KvsTableTable(attachedDatabase, alias);
  }
}

class KvsEntry extends DataClass implements Insertable<KvsEntry> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const KvsEntry(
      {required this.key, required this.value, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  KvsTableCompanion toCompanion(bool nullToAbsent) {
    return KvsTableCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory KvsEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KvsEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  KvsEntry copyWith({String? key, String? value, DateTime? updatedAt}) =>
      KvsEntry(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  KvsEntry copyWithCompanion(KvsTableCompanion data) {
    return KvsEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KvsEntry(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KvsEntry &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class KvsTableCompanion extends UpdateCompanion<KvsEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const KvsTableCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KvsTableCompanion.insert({
    required String key,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value),
        updatedAt = Value(updatedAt);
  static Insertable<KvsEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KvsTableCompanion copyWith(
      {Value<String>? key,
      Value<String>? value,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return KvsTableCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
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
    return (StringBuffer('KvsTableCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DeviceProfileTableTable deviceProfileTable =
      $DeviceProfileTableTable(this);
  late final $BooksTableTable booksTable = $BooksTableTable(this);
  late final $SessionsTableTable sessionsTable = $SessionsTableTable(this);
  late final $SessionMembersTableTable sessionMembersTable =
      $SessionMembersTableTable(this);
  late final $SessionEventsTableTable sessionEventsTable =
      $SessionEventsTableTable(this);
  late final $OutboxTableTable outboxTable = $OutboxTableTable(this);
  late final $ReadingProgressTableTable readingProgressTable =
      $ReadingProgressTableTable(this);
  late final $ParticipantReadingTimeTableTable participantReadingTimeTable =
      $ParticipantReadingTimeTableTable(this);
  late final $PageActivityTableTable pageActivityTable =
      $PageActivityTableTable(this);
  late final $MessagesTableTable messagesTable = $MessagesTableTable(this);
  late final $NotesTableTable notesTable = $NotesTableTable(this);
  late final $KvsTableTable kvsTable = $KvsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        deviceProfileTable,
        booksTable,
        sessionsTable,
        sessionMembersTable,
        sessionEventsTable,
        outboxTable,
        readingProgressTable,
        participantReadingTimeTable,
        pageActivityTable,
        messagesTable,
        notesTable,
        kvsTable
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('books',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('sessions', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('sessions',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('session_members', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('sessions',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('session_events', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('sessions',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('outbox', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('sessions',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('reading_progress', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('books',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('reading_progress', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('sessions',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('participant_reading_time', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('sessions',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('page_activity', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('books',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('page_activity', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('sessions',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('messages', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('books',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('notes', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$DeviceProfileTableTableCreateCompanionBuilder
    = DeviceProfileTableCompanion Function({
  required String id,
  required String displayName,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$DeviceProfileTableTableUpdateCompanionBuilder
    = DeviceProfileTableCompanion Function({
  Value<String> id,
  Value<String> displayName,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$DeviceProfileTableTableFilterComposer
    extends Composer<_$AppDatabase, $DeviceProfileTableTable> {
  $$DeviceProfileTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$DeviceProfileTableTableOrderingComposer
    extends Composer<_$AppDatabase, $DeviceProfileTableTable> {
  $$DeviceProfileTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$DeviceProfileTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeviceProfileTableTable> {
  $$DeviceProfileTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DeviceProfileTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DeviceProfileTableTable,
    DeviceProfile,
    $$DeviceProfileTableTableFilterComposer,
    $$DeviceProfileTableTableOrderingComposer,
    $$DeviceProfileTableTableAnnotationComposer,
    $$DeviceProfileTableTableCreateCompanionBuilder,
    $$DeviceProfileTableTableUpdateCompanionBuilder,
    (
      DeviceProfile,
      BaseReferences<_$AppDatabase, $DeviceProfileTableTable, DeviceProfile>
    ),
    DeviceProfile,
    PrefetchHooks Function()> {
  $$DeviceProfileTableTableTableManager(
      _$AppDatabase db, $DeviceProfileTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeviceProfileTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeviceProfileTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeviceProfileTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> displayName = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DeviceProfileTableCompanion(
            id: id,
            displayName: displayName,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String displayName,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              DeviceProfileTableCompanion.insert(
            id: id,
            displayName: displayName,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DeviceProfileTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DeviceProfileTableTable,
    DeviceProfile,
    $$DeviceProfileTableTableFilterComposer,
    $$DeviceProfileTableTableOrderingComposer,
    $$DeviceProfileTableTableAnnotationComposer,
    $$DeviceProfileTableTableCreateCompanionBuilder,
    $$DeviceProfileTableTableUpdateCompanionBuilder,
    (
      DeviceProfile,
      BaseReferences<_$AppDatabase, $DeviceProfileTableTable, DeviceProfile>
    ),
    DeviceProfile,
    PrefetchHooks Function()>;
typedef $$BooksTableTableCreateCompanionBuilder = BooksTableCompanion Function({
  required String id,
  required String title,
  required String author,
  required String filePath,
  required int fileSize,
  required int pageCount,
  required String sha256Hash,
  Value<String?> coverPath,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$BooksTableTableUpdateCompanionBuilder = BooksTableCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> author,
  Value<String> filePath,
  Value<int> fileSize,
  Value<int> pageCount,
  Value<String> sha256Hash,
  Value<String?> coverPath,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$BooksTableTableReferences
    extends BaseReferences<_$AppDatabase, $BooksTableTable, Book> {
  $$BooksTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SessionsTableTable, List<Session>>
      _sessionsTableRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.sessionsTable,
              aliasName: $_aliasNameGenerator(
                  db.booksTable.id, db.sessionsTable.bookId));

  $$SessionsTableTableProcessedTableManager get sessionsTableRefs {
    final manager = $$SessionsTableTableTableManager($_db, $_db.sessionsTable)
        .filter((f) => f.bookId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sessionsTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ReadingProgressTableTable, List<ReadingProgress>>
      _readingProgressTableRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.readingProgressTable,
              aliasName: $_aliasNameGenerator(
                  db.booksTable.id, db.readingProgressTable.bookId));

  $$ReadingProgressTableTableProcessedTableManager
      get readingProgressTableRefs {
    final manager =
        $$ReadingProgressTableTableTableManager($_db, $_db.readingProgressTable)
            .filter((f) => f.bookId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_readingProgressTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$PageActivityTableTable, List<PageActivity>>
      _pageActivityTableRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.pageActivityTable,
              aliasName: $_aliasNameGenerator(
                  db.booksTable.id, db.pageActivityTable.bookId));

  $$PageActivityTableTableProcessedTableManager get pageActivityTableRefs {
    final manager =
        $$PageActivityTableTableTableManager($_db, $_db.pageActivityTable)
            .filter((f) => f.bookId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_pageActivityTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$NotesTableTable, List<Note>> _notesTableRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.notesTable,
          aliasName:
              $_aliasNameGenerator(db.booksTable.id, db.notesTable.bookId));

  $$NotesTableTableProcessedTableManager get notesTableRefs {
    final manager = $$NotesTableTableTableManager($_db, $_db.notesTable)
        .filter((f) => f.bookId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_notesTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$BooksTableTableFilterComposer
    extends Composer<_$AppDatabase, $BooksTableTable> {
  $$BooksTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fileSize => $composableBuilder(
      column: $table.fileSize, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pageCount => $composableBuilder(
      column: $table.pageCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sha256Hash => $composableBuilder(
      column: $table.sha256Hash, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverPath => $composableBuilder(
      column: $table.coverPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> sessionsTableRefs(
      Expression<bool> Function($$SessionsTableTableFilterComposer f) f) {
    final $$SessionsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.bookId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableFilterComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> readingProgressTableRefs(
      Expression<bool> Function($$ReadingProgressTableTableFilterComposer f)
          f) {
    final $$ReadingProgressTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.readingProgressTable,
        getReferencedColumn: (t) => t.bookId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReadingProgressTableTableFilterComposer(
              $db: $db,
              $table: $db.readingProgressTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> pageActivityTableRefs(
      Expression<bool> Function($$PageActivityTableTableFilterComposer f) f) {
    final $$PageActivityTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.pageActivityTable,
        getReferencedColumn: (t) => t.bookId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PageActivityTableTableFilterComposer(
              $db: $db,
              $table: $db.pageActivityTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> notesTableRefs(
      Expression<bool> Function($$NotesTableTableFilterComposer f) f) {
    final $$NotesTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.notesTable,
        getReferencedColumn: (t) => t.bookId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NotesTableTableFilterComposer(
              $db: $db,
              $table: $db.notesTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BooksTableTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTableTable> {
  $$BooksTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fileSize => $composableBuilder(
      column: $table.fileSize, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pageCount => $composableBuilder(
      column: $table.pageCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sha256Hash => $composableBuilder(
      column: $table.sha256Hash, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverPath => $composableBuilder(
      column: $table.coverPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$BooksTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTableTable> {
  $$BooksTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<String> get sha256Hash => $composableBuilder(
      column: $table.sha256Hash, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> sessionsTableRefs<T extends Object>(
      Expression<T> Function($$SessionsTableTableAnnotationComposer a) f) {
    final $$SessionsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.bookId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> readingProgressTableRefs<T extends Object>(
      Expression<T> Function($$ReadingProgressTableTableAnnotationComposer a)
          f) {
    final $$ReadingProgressTableTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.readingProgressTable,
            getReferencedColumn: (t) => t.bookId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$ReadingProgressTableTableAnnotationComposer(
                  $db: $db,
                  $table: $db.readingProgressTable,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> pageActivityTableRefs<T extends Object>(
      Expression<T> Function($$PageActivityTableTableAnnotationComposer a) f) {
    final $$PageActivityTableTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.pageActivityTable,
            getReferencedColumn: (t) => t.bookId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$PageActivityTableTableAnnotationComposer(
                  $db: $db,
                  $table: $db.pageActivityTable,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> notesTableRefs<T extends Object>(
      Expression<T> Function($$NotesTableTableAnnotationComposer a) f) {
    final $$NotesTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.notesTable,
        getReferencedColumn: (t) => t.bookId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NotesTableTableAnnotationComposer(
              $db: $db,
              $table: $db.notesTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BooksTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BooksTableTable,
    Book,
    $$BooksTableTableFilterComposer,
    $$BooksTableTableOrderingComposer,
    $$BooksTableTableAnnotationComposer,
    $$BooksTableTableCreateCompanionBuilder,
    $$BooksTableTableUpdateCompanionBuilder,
    (Book, $$BooksTableTableReferences),
    Book,
    PrefetchHooks Function(
        {bool sessionsTableRefs,
        bool readingProgressTableRefs,
        bool pageActivityTableRefs,
        bool notesTableRefs})> {
  $$BooksTableTableTableManager(_$AppDatabase db, $BooksTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> author = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<int> fileSize = const Value.absent(),
            Value<int> pageCount = const Value.absent(),
            Value<String> sha256Hash = const Value.absent(),
            Value<String?> coverPath = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BooksTableCompanion(
            id: id,
            title: title,
            author: author,
            filePath: filePath,
            fileSize: fileSize,
            pageCount: pageCount,
            sha256Hash: sha256Hash,
            coverPath: coverPath,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            required String author,
            required String filePath,
            required int fileSize,
            required int pageCount,
            required String sha256Hash,
            Value<String?> coverPath = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              BooksTableCompanion.insert(
            id: id,
            title: title,
            author: author,
            filePath: filePath,
            fileSize: fileSize,
            pageCount: pageCount,
            sha256Hash: sha256Hash,
            coverPath: coverPath,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$BooksTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {sessionsTableRefs = false,
              readingProgressTableRefs = false,
              pageActivityTableRefs = false,
              notesTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (sessionsTableRefs) db.sessionsTable,
                if (readingProgressTableRefs) db.readingProgressTable,
                if (pageActivityTableRefs) db.pageActivityTable,
                if (notesTableRefs) db.notesTable
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sessionsTableRefs)
                    await $_getPrefetchedData<Book, $BooksTableTable, Session>(
                        currentTable: table,
                        referencedTable: $$BooksTableTableReferences
                            ._sessionsTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BooksTableTableReferences(db, table, p0)
                                .sessionsTableRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.bookId == item.id),
                        typedResults: items),
                  if (readingProgressTableRefs)
                    await $_getPrefetchedData<Book, $BooksTableTable,
                            ReadingProgress>(
                        currentTable: table,
                        referencedTable: $$BooksTableTableReferences
                            ._readingProgressTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BooksTableTableReferences(db, table, p0)
                                .readingProgressTableRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.bookId == item.id),
                        typedResults: items),
                  if (pageActivityTableRefs)
                    await $_getPrefetchedData<Book, $BooksTableTable,
                            PageActivity>(
                        currentTable: table,
                        referencedTable: $$BooksTableTableReferences
                            ._pageActivityTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BooksTableTableReferences(db, table, p0)
                                .pageActivityTableRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.bookId == item.id),
                        typedResults: items),
                  if (notesTableRefs)
                    await $_getPrefetchedData<Book, $BooksTableTable, Note>(
                        currentTable: table,
                        referencedTable: $$BooksTableTableReferences
                            ._notesTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BooksTableTableReferences(db, table, p0)
                                .notesTableRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.bookId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$BooksTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BooksTableTable,
    Book,
    $$BooksTableTableFilterComposer,
    $$BooksTableTableOrderingComposer,
    $$BooksTableTableAnnotationComposer,
    $$BooksTableTableCreateCompanionBuilder,
    $$BooksTableTableUpdateCompanionBuilder,
    (Book, $$BooksTableTableReferences),
    Book,
    PrefetchHooks Function(
        {bool sessionsTableRefs,
        bool readingProgressTableRefs,
        bool pageActivityTableRefs,
        bool notesTableRefs})>;
typedef $$SessionsTableTableCreateCompanionBuilder = SessionsTableCompanion
    Function({
  required String id,
  required String title,
  required String hostDeviceId,
  required String bookId,
  required String status,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$SessionsTableTableUpdateCompanionBuilder = SessionsTableCompanion
    Function({
  Value<String> id,
  Value<String> title,
  Value<String> hostDeviceId,
  Value<String> bookId,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$SessionsTableTableReferences
    extends BaseReferences<_$AppDatabase, $SessionsTableTable, Session> {
  $$SessionsTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $BooksTableTable _bookIdTable(_$AppDatabase db) =>
      db.booksTable.createAlias(
          $_aliasNameGenerator(db.sessionsTable.bookId, db.booksTable.id));

  $$BooksTableTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<String>('book_id')!;

    final manager = $$BooksTableTableTableManager($_db, $_db.booksTable)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$SessionMembersTableTable, List<SessionMember>>
      _sessionMembersTableRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.sessionMembersTable,
              aliasName: $_aliasNameGenerator(
                  db.sessionsTable.id, db.sessionMembersTable.sessionId));

  $$SessionMembersTableTableProcessedTableManager get sessionMembersTableRefs {
    final manager = $$SessionMembersTableTableTableManager(
            $_db, $_db.sessionMembersTable)
        .filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_sessionMembersTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$SessionEventsTableTable, List<SessionEvent>>
      _sessionEventsTableRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.sessionEventsTable,
              aliasName: $_aliasNameGenerator(
                  db.sessionsTable.id, db.sessionEventsTable.sessionId));

  $$SessionEventsTableTableProcessedTableManager get sessionEventsTableRefs {
    final manager = $$SessionEventsTableTableTableManager(
            $_db, $_db.sessionEventsTable)
        .filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_sessionEventsTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$OutboxTableTable, List<OutboxEntry>>
      _outboxTableRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.outboxTable,
              aliasName: $_aliasNameGenerator(
                  db.sessionsTable.id, db.outboxTable.sessionId));

  $$OutboxTableTableProcessedTableManager get outboxTableRefs {
    final manager = $$OutboxTableTableTableManager($_db, $_db.outboxTable)
        .filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_outboxTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ReadingProgressTableTable, List<ReadingProgress>>
      _readingProgressTableRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.readingProgressTable,
              aliasName: $_aliasNameGenerator(
                  db.sessionsTable.id, db.readingProgressTable.sessionId));

  $$ReadingProgressTableTableProcessedTableManager
      get readingProgressTableRefs {
    final manager = $$ReadingProgressTableTableTableManager(
            $_db, $_db.readingProgressTable)
        .filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_readingProgressTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ParticipantReadingTimeTableTable,
      List<ParticipantReadingTime>> _participantReadingTimeTableRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.participantReadingTimeTable,
          aliasName: $_aliasNameGenerator(
              db.sessionsTable.id, db.participantReadingTimeTable.sessionId));

  $$ParticipantReadingTimeTableTableProcessedTableManager
      get participantReadingTimeTableRefs {
    final manager = $$ParticipantReadingTimeTableTableTableManager(
            $_db, $_db.participantReadingTimeTable)
        .filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult
        .readTableOrNull(_participantReadingTimeTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$PageActivityTableTable, List<PageActivity>>
      _pageActivityTableRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.pageActivityTable,
              aliasName: $_aliasNameGenerator(
                  db.sessionsTable.id, db.pageActivityTable.sessionId));

  $$PageActivityTableTableProcessedTableManager get pageActivityTableRefs {
    final manager = $$PageActivityTableTableTableManager(
            $_db, $_db.pageActivityTable)
        .filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_pageActivityTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$MessagesTableTable, List<Message>>
      _messagesTableRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.messagesTable,
              aliasName: $_aliasNameGenerator(
                  db.sessionsTable.id, db.messagesTable.sessionId));

  $$MessagesTableTableProcessedTableManager get messagesTableRefs {
    final manager = $$MessagesTableTableTableManager($_db, $_db.messagesTable)
        .filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_messagesTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$SessionsTableTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTableTable> {
  $$SessionsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get hostDeviceId => $composableBuilder(
      column: $table.hostDeviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$BooksTableTableFilterComposer get bookId {
    final $$BooksTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.booksTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableTableFilterComposer(
              $db: $db,
              $table: $db.booksTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> sessionMembersTableRefs(
      Expression<bool> Function($$SessionMembersTableTableFilterComposer f) f) {
    final $$SessionMembersTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.sessionMembersTable,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionMembersTableTableFilterComposer(
              $db: $db,
              $table: $db.sessionMembersTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> sessionEventsTableRefs(
      Expression<bool> Function($$SessionEventsTableTableFilterComposer f) f) {
    final $$SessionEventsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.sessionEventsTable,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionEventsTableTableFilterComposer(
              $db: $db,
              $table: $db.sessionEventsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> outboxTableRefs(
      Expression<bool> Function($$OutboxTableTableFilterComposer f) f) {
    final $$OutboxTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.outboxTable,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OutboxTableTableFilterComposer(
              $db: $db,
              $table: $db.outboxTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> readingProgressTableRefs(
      Expression<bool> Function($$ReadingProgressTableTableFilterComposer f)
          f) {
    final $$ReadingProgressTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.readingProgressTable,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReadingProgressTableTableFilterComposer(
              $db: $db,
              $table: $db.readingProgressTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> participantReadingTimeTableRefs(
      Expression<bool> Function(
              $$ParticipantReadingTimeTableTableFilterComposer f)
          f) {
    final $$ParticipantReadingTimeTableTableFilterComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.participantReadingTimeTable,
            getReferencedColumn: (t) => t.sessionId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$ParticipantReadingTimeTableTableFilterComposer(
                  $db: $db,
                  $table: $db.participantReadingTimeTable,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<bool> pageActivityTableRefs(
      Expression<bool> Function($$PageActivityTableTableFilterComposer f) f) {
    final $$PageActivityTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.pageActivityTable,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PageActivityTableTableFilterComposer(
              $db: $db,
              $table: $db.pageActivityTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> messagesTableRefs(
      Expression<bool> Function($$MessagesTableTableFilterComposer f) f) {
    final $$MessagesTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.messagesTable,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MessagesTableTableFilterComposer(
              $db: $db,
              $table: $db.messagesTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SessionsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTableTable> {
  $$SessionsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get hostDeviceId => $composableBuilder(
      column: $table.hostDeviceId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$BooksTableTableOrderingComposer get bookId {
    final $$BooksTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.booksTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableTableOrderingComposer(
              $db: $db,
              $table: $db.booksTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SessionsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTableTable> {
  $$SessionsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get hostDeviceId => $composableBuilder(
      column: $table.hostDeviceId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$BooksTableTableAnnotationComposer get bookId {
    final $$BooksTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.booksTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableTableAnnotationComposer(
              $db: $db,
              $table: $db.booksTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> sessionMembersTableRefs<T extends Object>(
      Expression<T> Function($$SessionMembersTableTableAnnotationComposer a)
          f) {
    final $$SessionMembersTableTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.sessionMembersTable,
            getReferencedColumn: (t) => t.sessionId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$SessionMembersTableTableAnnotationComposer(
                  $db: $db,
                  $table: $db.sessionMembersTable,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> sessionEventsTableRefs<T extends Object>(
      Expression<T> Function($$SessionEventsTableTableAnnotationComposer a) f) {
    final $$SessionEventsTableTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.sessionEventsTable,
            getReferencedColumn: (t) => t.sessionId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$SessionEventsTableTableAnnotationComposer(
                  $db: $db,
                  $table: $db.sessionEventsTable,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> outboxTableRefs<T extends Object>(
      Expression<T> Function($$OutboxTableTableAnnotationComposer a) f) {
    final $$OutboxTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.outboxTable,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OutboxTableTableAnnotationComposer(
              $db: $db,
              $table: $db.outboxTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> readingProgressTableRefs<T extends Object>(
      Expression<T> Function($$ReadingProgressTableTableAnnotationComposer a)
          f) {
    final $$ReadingProgressTableTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.readingProgressTable,
            getReferencedColumn: (t) => t.sessionId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$ReadingProgressTableTableAnnotationComposer(
                  $db: $db,
                  $table: $db.readingProgressTable,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> participantReadingTimeTableRefs<T extends Object>(
      Expression<T> Function(
              $$ParticipantReadingTimeTableTableAnnotationComposer a)
          f) {
    final $$ParticipantReadingTimeTableTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.participantReadingTimeTable,
            getReferencedColumn: (t) => t.sessionId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$ParticipantReadingTimeTableTableAnnotationComposer(
                  $db: $db,
                  $table: $db.participantReadingTimeTable,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> pageActivityTableRefs<T extends Object>(
      Expression<T> Function($$PageActivityTableTableAnnotationComposer a) f) {
    final $$PageActivityTableTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.pageActivityTable,
            getReferencedColumn: (t) => t.sessionId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$PageActivityTableTableAnnotationComposer(
                  $db: $db,
                  $table: $db.pageActivityTable,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> messagesTableRefs<T extends Object>(
      Expression<T> Function($$MessagesTableTableAnnotationComposer a) f) {
    final $$MessagesTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.messagesTable,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MessagesTableTableAnnotationComposer(
              $db: $db,
              $table: $db.messagesTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SessionsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SessionsTableTable,
    Session,
    $$SessionsTableTableFilterComposer,
    $$SessionsTableTableOrderingComposer,
    $$SessionsTableTableAnnotationComposer,
    $$SessionsTableTableCreateCompanionBuilder,
    $$SessionsTableTableUpdateCompanionBuilder,
    (Session, $$SessionsTableTableReferences),
    Session,
    PrefetchHooks Function(
        {bool bookId,
        bool sessionMembersTableRefs,
        bool sessionEventsTableRefs,
        bool outboxTableRefs,
        bool readingProgressTableRefs,
        bool participantReadingTimeTableRefs,
        bool pageActivityTableRefs,
        bool messagesTableRefs})> {
  $$SessionsTableTableTableManager(_$AppDatabase db, $SessionsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> hostDeviceId = const Value.absent(),
            Value<String> bookId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionsTableCompanion(
            id: id,
            title: title,
            hostDeviceId: hostDeviceId,
            bookId: bookId,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            required String hostDeviceId,
            required String bookId,
            required String status,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionsTableCompanion.insert(
            id: id,
            title: title,
            hostDeviceId: hostDeviceId,
            bookId: bookId,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$SessionsTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {bookId = false,
              sessionMembersTableRefs = false,
              sessionEventsTableRefs = false,
              outboxTableRefs = false,
              readingProgressTableRefs = false,
              participantReadingTimeTableRefs = false,
              pageActivityTableRefs = false,
              messagesTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (sessionMembersTableRefs) db.sessionMembersTable,
                if (sessionEventsTableRefs) db.sessionEventsTable,
                if (outboxTableRefs) db.outboxTable,
                if (readingProgressTableRefs) db.readingProgressTable,
                if (participantReadingTimeTableRefs)
                  db.participantReadingTimeTable,
                if (pageActivityTableRefs) db.pageActivityTable,
                if (messagesTableRefs) db.messagesTable
              ],
              addJoins: <
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
                      dynamic>>(state) {
                if (bookId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.bookId,
                    referencedTable:
                        $$SessionsTableTableReferences._bookIdTable(db),
                    referencedColumn:
                        $$SessionsTableTableReferences._bookIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sessionMembersTableRefs)
                    await $_getPrefetchedData<Session, $SessionsTableTable,
                            SessionMember>(
                        currentTable: table,
                        referencedTable: $$SessionsTableTableReferences
                            ._sessionMembersTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SessionsTableTableReferences(db, table, p0)
                                .sessionMembersTableRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.sessionId == item.id),
                        typedResults: items),
                  if (sessionEventsTableRefs)
                    await $_getPrefetchedData<Session, $SessionsTableTable,
                            SessionEvent>(
                        currentTable: table,
                        referencedTable: $$SessionsTableTableReferences
                            ._sessionEventsTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SessionsTableTableReferences(db, table, p0)
                                .sessionEventsTableRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.sessionId == item.id),
                        typedResults: items),
                  if (outboxTableRefs)
                    await $_getPrefetchedData<Session, $SessionsTableTable,
                            OutboxEntry>(
                        currentTable: table,
                        referencedTable: $$SessionsTableTableReferences
                            ._outboxTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SessionsTableTableReferences(db, table, p0)
                                .outboxTableRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.sessionId == item.id),
                        typedResults: items),
                  if (readingProgressTableRefs)
                    await $_getPrefetchedData<Session, $SessionsTableTable,
                            ReadingProgress>(
                        currentTable: table,
                        referencedTable: $$SessionsTableTableReferences
                            ._readingProgressTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SessionsTableTableReferences(db, table, p0)
                                .readingProgressTableRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.sessionId == item.id),
                        typedResults: items),
                  if (participantReadingTimeTableRefs)
                    await $_getPrefetchedData<Session, $SessionsTableTable,
                            ParticipantReadingTime>(
                        currentTable: table,
                        referencedTable: $$SessionsTableTableReferences
                            ._participantReadingTimeTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SessionsTableTableReferences(db, table, p0)
                                .participantReadingTimeTableRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.sessionId == item.id),
                        typedResults: items),
                  if (pageActivityTableRefs)
                    await $_getPrefetchedData<Session, $SessionsTableTable,
                            PageActivity>(
                        currentTable: table,
                        referencedTable: $$SessionsTableTableReferences
                            ._pageActivityTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SessionsTableTableReferences(db, table, p0)
                                .pageActivityTableRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.sessionId == item.id),
                        typedResults: items),
                  if (messagesTableRefs)
                    await $_getPrefetchedData<Session, $SessionsTableTable,
                            Message>(
                        currentTable: table,
                        referencedTable: $$SessionsTableTableReferences
                            ._messagesTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SessionsTableTableReferences(db, table, p0)
                                .messagesTableRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.sessionId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$SessionsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SessionsTableTable,
    Session,
    $$SessionsTableTableFilterComposer,
    $$SessionsTableTableOrderingComposer,
    $$SessionsTableTableAnnotationComposer,
    $$SessionsTableTableCreateCompanionBuilder,
    $$SessionsTableTableUpdateCompanionBuilder,
    (Session, $$SessionsTableTableReferences),
    Session,
    PrefetchHooks Function(
        {bool bookId,
        bool sessionMembersTableRefs,
        bool sessionEventsTableRefs,
        bool outboxTableRefs,
        bool readingProgressTableRefs,
        bool participantReadingTimeTableRefs,
        bool pageActivityTableRefs,
        bool messagesTableRefs})>;
typedef $$SessionMembersTableTableCreateCompanionBuilder
    = SessionMembersTableCompanion Function({
  required String id,
  required String sessionId,
  required String deviceId,
  required String displayName,
  required String role,
  required DateTime joinedAt,
  required DateTime lastSeenAt,
  required String status,
  Value<int> rowid,
});
typedef $$SessionMembersTableTableUpdateCompanionBuilder
    = SessionMembersTableCompanion Function({
  Value<String> id,
  Value<String> sessionId,
  Value<String> deviceId,
  Value<String> displayName,
  Value<String> role,
  Value<DateTime> joinedAt,
  Value<DateTime> lastSeenAt,
  Value<String> status,
  Value<int> rowid,
});

final class $$SessionMembersTableTableReferences extends BaseReferences<
    _$AppDatabase, $SessionMembersTableTable, SessionMember> {
  $$SessionMembersTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTableTable _sessionIdTable(_$AppDatabase db) =>
      db.sessionsTable.createAlias($_aliasNameGenerator(
          db.sessionMembersTable.sessionId, db.sessionsTable.id));

  $$SessionsTableTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableTableManager($_db, $_db.sessionsTable)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$SessionMembersTableTableFilterComposer
    extends Composer<_$AppDatabase, $SessionMembersTableTable> {
  $$SessionMembersTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get joinedAt => $composableBuilder(
      column: $table.joinedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  $$SessionsTableTableFilterComposer get sessionId {
    final $$SessionsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableFilterComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SessionMembersTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionMembersTableTable> {
  $$SessionMembersTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get joinedAt => $composableBuilder(
      column: $table.joinedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  $$SessionsTableTableOrderingComposer get sessionId {
    final $$SessionsTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableOrderingComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SessionMembersTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionMembersTableTable> {
  $$SessionMembersTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<DateTime> get joinedAt =>
      $composableBuilder(column: $table.joinedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  $$SessionsTableTableAnnotationComposer get sessionId {
    final $$SessionsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SessionMembersTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SessionMembersTableTable,
    SessionMember,
    $$SessionMembersTableTableFilterComposer,
    $$SessionMembersTableTableOrderingComposer,
    $$SessionMembersTableTableAnnotationComposer,
    $$SessionMembersTableTableCreateCompanionBuilder,
    $$SessionMembersTableTableUpdateCompanionBuilder,
    (SessionMember, $$SessionMembersTableTableReferences),
    SessionMember,
    PrefetchHooks Function({bool sessionId})> {
  $$SessionMembersTableTableTableManager(
      _$AppDatabase db, $SessionMembersTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionMembersTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionMembersTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionMembersTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sessionId = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<String> displayName = const Value.absent(),
            Value<String> role = const Value.absent(),
            Value<DateTime> joinedAt = const Value.absent(),
            Value<DateTime> lastSeenAt = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionMembersTableCompanion(
            id: id,
            sessionId: sessionId,
            deviceId: deviceId,
            displayName: displayName,
            role: role,
            joinedAt: joinedAt,
            lastSeenAt: lastSeenAt,
            status: status,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sessionId,
            required String deviceId,
            required String displayName,
            required String role,
            required DateTime joinedAt,
            required DateTime lastSeenAt,
            required String status,
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionMembersTableCompanion.insert(
            id: id,
            sessionId: sessionId,
            deviceId: deviceId,
            displayName: displayName,
            role: role,
            joinedAt: joinedAt,
            lastSeenAt: lastSeenAt,
            status: status,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$SessionMembersTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (sessionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sessionId,
                    referencedTable: $$SessionMembersTableTableReferences
                        ._sessionIdTable(db),
                    referencedColumn: $$SessionMembersTableTableReferences
                        ._sessionIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$SessionMembersTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SessionMembersTableTable,
    SessionMember,
    $$SessionMembersTableTableFilterComposer,
    $$SessionMembersTableTableOrderingComposer,
    $$SessionMembersTableTableAnnotationComposer,
    $$SessionMembersTableTableCreateCompanionBuilder,
    $$SessionMembersTableTableUpdateCompanionBuilder,
    (SessionMember, $$SessionMembersTableTableReferences),
    SessionMember,
    PrefetchHooks Function({bool sessionId})>;
typedef $$SessionEventsTableTableCreateCompanionBuilder
    = SessionEventsTableCompanion Function({
  required String id,
  required String sessionId,
  required String deviceId,
  required String eventType,
  required String payload,
  required int sequenceNumber,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$SessionEventsTableTableUpdateCompanionBuilder
    = SessionEventsTableCompanion Function({
  Value<String> id,
  Value<String> sessionId,
  Value<String> deviceId,
  Value<String> eventType,
  Value<String> payload,
  Value<int> sequenceNumber,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$SessionEventsTableTableReferences extends BaseReferences<
    _$AppDatabase, $SessionEventsTableTable, SessionEvent> {
  $$SessionEventsTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTableTable _sessionIdTable(_$AppDatabase db) =>
      db.sessionsTable.createAlias($_aliasNameGenerator(
          db.sessionEventsTable.sessionId, db.sessionsTable.id));

  $$SessionsTableTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableTableManager($_db, $_db.sessionsTable)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$SessionEventsTableTableFilterComposer
    extends Composer<_$AppDatabase, $SessionEventsTableTable> {
  $$SessionEventsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get eventType => $composableBuilder(
      column: $table.eventType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sequenceNumber => $composableBuilder(
      column: $table.sequenceNumber,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$SessionsTableTableFilterComposer get sessionId {
    final $$SessionsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableFilterComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SessionEventsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionEventsTableTable> {
  $$SessionEventsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eventType => $composableBuilder(
      column: $table.eventType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sequenceNumber => $composableBuilder(
      column: $table.sequenceNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$SessionsTableTableOrderingComposer get sessionId {
    final $$SessionsTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableOrderingComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SessionEventsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionEventsTableTable> {
  $$SessionEventsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get sequenceNumber => $composableBuilder(
      column: $table.sequenceNumber, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SessionsTableTableAnnotationComposer get sessionId {
    final $$SessionsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SessionEventsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SessionEventsTableTable,
    SessionEvent,
    $$SessionEventsTableTableFilterComposer,
    $$SessionEventsTableTableOrderingComposer,
    $$SessionEventsTableTableAnnotationComposer,
    $$SessionEventsTableTableCreateCompanionBuilder,
    $$SessionEventsTableTableUpdateCompanionBuilder,
    (SessionEvent, $$SessionEventsTableTableReferences),
    SessionEvent,
    PrefetchHooks Function({bool sessionId})> {
  $$SessionEventsTableTableTableManager(
      _$AppDatabase db, $SessionEventsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionEventsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionEventsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionEventsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sessionId = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<String> eventType = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<int> sequenceNumber = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionEventsTableCompanion(
            id: id,
            sessionId: sessionId,
            deviceId: deviceId,
            eventType: eventType,
            payload: payload,
            sequenceNumber: sequenceNumber,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sessionId,
            required String deviceId,
            required String eventType,
            required String payload,
            required int sequenceNumber,
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionEventsTableCompanion.insert(
            id: id,
            sessionId: sessionId,
            deviceId: deviceId,
            eventType: eventType,
            payload: payload,
            sequenceNumber: sequenceNumber,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$SessionEventsTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (sessionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sessionId,
                    referencedTable:
                        $$SessionEventsTableTableReferences._sessionIdTable(db),
                    referencedColumn: $$SessionEventsTableTableReferences
                        ._sessionIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$SessionEventsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SessionEventsTableTable,
    SessionEvent,
    $$SessionEventsTableTableFilterComposer,
    $$SessionEventsTableTableOrderingComposer,
    $$SessionEventsTableTableAnnotationComposer,
    $$SessionEventsTableTableCreateCompanionBuilder,
    $$SessionEventsTableTableUpdateCompanionBuilder,
    (SessionEvent, $$SessionEventsTableTableReferences),
    SessionEvent,
    PrefetchHooks Function({bool sessionId})>;
typedef $$OutboxTableTableCreateCompanionBuilder = OutboxTableCompanion
    Function({
  required String id,
  Value<String?> sessionId,
  required String messageType,
  required String payload,
  required String status,
  Value<int> retryCount,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$OutboxTableTableUpdateCompanionBuilder = OutboxTableCompanion
    Function({
  Value<String> id,
  Value<String?> sessionId,
  Value<String> messageType,
  Value<String> payload,
  Value<String> status,
  Value<int> retryCount,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$OutboxTableTableReferences
    extends BaseReferences<_$AppDatabase, $OutboxTableTable, OutboxEntry> {
  $$OutboxTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTableTable _sessionIdTable(_$AppDatabase db) =>
      db.sessionsTable.createAlias(
          $_aliasNameGenerator(db.outboxTable.sessionId, db.sessionsTable.id));

  $$SessionsTableTableProcessedTableManager? get sessionId {
    final $_column = $_itemColumn<String>('session_id');
    if ($_column == null) return null;
    final manager = $$SessionsTableTableTableManager($_db, $_db.sessionsTable)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$OutboxTableTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTableTable> {
  $$OutboxTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get messageType => $composableBuilder(
      column: $table.messageType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$SessionsTableTableFilterComposer get sessionId {
    final $$SessionsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableFilterComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$OutboxTableTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTableTable> {
  $$OutboxTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get messageType => $composableBuilder(
      column: $table.messageType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$SessionsTableTableOrderingComposer get sessionId {
    final $$SessionsTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableOrderingComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$OutboxTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTableTable> {
  $$OutboxTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get messageType => $composableBuilder(
      column: $table.messageType, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$SessionsTableTableAnnotationComposer get sessionId {
    final $$SessionsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$OutboxTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OutboxTableTable,
    OutboxEntry,
    $$OutboxTableTableFilterComposer,
    $$OutboxTableTableOrderingComposer,
    $$OutboxTableTableAnnotationComposer,
    $$OutboxTableTableCreateCompanionBuilder,
    $$OutboxTableTableUpdateCompanionBuilder,
    (OutboxEntry, $$OutboxTableTableReferences),
    OutboxEntry,
    PrefetchHooks Function({bool sessionId})> {
  $$OutboxTableTableTableManager(_$AppDatabase db, $OutboxTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> sessionId = const Value.absent(),
            Value<String> messageType = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxTableCompanion(
            id: id,
            sessionId: sessionId,
            messageType: messageType,
            payload: payload,
            status: status,
            retryCount: retryCount,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> sessionId = const Value.absent(),
            required String messageType,
            required String payload,
            required String status,
            Value<int> retryCount = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxTableCompanion.insert(
            id: id,
            sessionId: sessionId,
            messageType: messageType,
            payload: payload,
            status: status,
            retryCount: retryCount,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$OutboxTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (sessionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sessionId,
                    referencedTable:
                        $$OutboxTableTableReferences._sessionIdTable(db),
                    referencedColumn:
                        $$OutboxTableTableReferences._sessionIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$OutboxTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OutboxTableTable,
    OutboxEntry,
    $$OutboxTableTableFilterComposer,
    $$OutboxTableTableOrderingComposer,
    $$OutboxTableTableAnnotationComposer,
    $$OutboxTableTableCreateCompanionBuilder,
    $$OutboxTableTableUpdateCompanionBuilder,
    (OutboxEntry, $$OutboxTableTableReferences),
    OutboxEntry,
    PrefetchHooks Function({bool sessionId})>;
typedef $$ReadingProgressTableTableCreateCompanionBuilder
    = ReadingProgressTableCompanion Function({
  required String id,
  required String sessionId,
  required String bookId,
  required String deviceId,
  required int currentPage,
  required int totalPages,
  required double percentage,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ReadingProgressTableTableUpdateCompanionBuilder
    = ReadingProgressTableCompanion Function({
  Value<String> id,
  Value<String> sessionId,
  Value<String> bookId,
  Value<String> deviceId,
  Value<int> currentPage,
  Value<int> totalPages,
  Value<double> percentage,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$ReadingProgressTableTableReferences extends BaseReferences<
    _$AppDatabase, $ReadingProgressTableTable, ReadingProgress> {
  $$ReadingProgressTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTableTable _sessionIdTable(_$AppDatabase db) =>
      db.sessionsTable.createAlias($_aliasNameGenerator(
          db.readingProgressTable.sessionId, db.sessionsTable.id));

  $$SessionsTableTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableTableManager($_db, $_db.sessionsTable)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $BooksTableTable _bookIdTable(_$AppDatabase db) =>
      db.booksTable.createAlias($_aliasNameGenerator(
          db.readingProgressTable.bookId, db.booksTable.id));

  $$BooksTableTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<String>('book_id')!;

    final manager = $$BooksTableTableTableManager($_db, $_db.booksTable)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ReadingProgressTableTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingProgressTableTable> {
  $$ReadingProgressTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get currentPage => $composableBuilder(
      column: $table.currentPage, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalPages => $composableBuilder(
      column: $table.totalPages, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get percentage => $composableBuilder(
      column: $table.percentage, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$SessionsTableTableFilterComposer get sessionId {
    final $$SessionsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableFilterComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BooksTableTableFilterComposer get bookId {
    final $$BooksTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.booksTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableTableFilterComposer(
              $db: $db,
              $table: $db.booksTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReadingProgressTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingProgressTableTable> {
  $$ReadingProgressTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get currentPage => $composableBuilder(
      column: $table.currentPage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalPages => $composableBuilder(
      column: $table.totalPages, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get percentage => $composableBuilder(
      column: $table.percentage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$SessionsTableTableOrderingComposer get sessionId {
    final $$SessionsTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableOrderingComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BooksTableTableOrderingComposer get bookId {
    final $$BooksTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.booksTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableTableOrderingComposer(
              $db: $db,
              $table: $db.booksTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReadingProgressTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingProgressTableTable> {
  $$ReadingProgressTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get currentPage => $composableBuilder(
      column: $table.currentPage, builder: (column) => column);

  GeneratedColumn<int> get totalPages => $composableBuilder(
      column: $table.totalPages, builder: (column) => column);

  GeneratedColumn<double> get percentage => $composableBuilder(
      column: $table.percentage, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$SessionsTableTableAnnotationComposer get sessionId {
    final $$SessionsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BooksTableTableAnnotationComposer get bookId {
    final $$BooksTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.booksTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableTableAnnotationComposer(
              $db: $db,
              $table: $db.booksTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReadingProgressTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReadingProgressTableTable,
    ReadingProgress,
    $$ReadingProgressTableTableFilterComposer,
    $$ReadingProgressTableTableOrderingComposer,
    $$ReadingProgressTableTableAnnotationComposer,
    $$ReadingProgressTableTableCreateCompanionBuilder,
    $$ReadingProgressTableTableUpdateCompanionBuilder,
    (ReadingProgress, $$ReadingProgressTableTableReferences),
    ReadingProgress,
    PrefetchHooks Function({bool sessionId, bool bookId})> {
  $$ReadingProgressTableTableTableManager(
      _$AppDatabase db, $ReadingProgressTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingProgressTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingProgressTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingProgressTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sessionId = const Value.absent(),
            Value<String> bookId = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<int> currentPage = const Value.absent(),
            Value<int> totalPages = const Value.absent(),
            Value<double> percentage = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReadingProgressTableCompanion(
            id: id,
            sessionId: sessionId,
            bookId: bookId,
            deviceId: deviceId,
            currentPage: currentPage,
            totalPages: totalPages,
            percentage: percentage,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sessionId,
            required String bookId,
            required String deviceId,
            required int currentPage,
            required int totalPages,
            required double percentage,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ReadingProgressTableCompanion.insert(
            id: id,
            sessionId: sessionId,
            bookId: bookId,
            deviceId: deviceId,
            currentPage: currentPage,
            totalPages: totalPages,
            percentage: percentage,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ReadingProgressTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({sessionId = false, bookId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (sessionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sessionId,
                    referencedTable: $$ReadingProgressTableTableReferences
                        ._sessionIdTable(db),
                    referencedColumn: $$ReadingProgressTableTableReferences
                        ._sessionIdTable(db)
                        .id,
                  ) as T;
                }
                if (bookId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.bookId,
                    referencedTable:
                        $$ReadingProgressTableTableReferences._bookIdTable(db),
                    referencedColumn: $$ReadingProgressTableTableReferences
                        ._bookIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ReadingProgressTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $ReadingProgressTableTable,
        ReadingProgress,
        $$ReadingProgressTableTableFilterComposer,
        $$ReadingProgressTableTableOrderingComposer,
        $$ReadingProgressTableTableAnnotationComposer,
        $$ReadingProgressTableTableCreateCompanionBuilder,
        $$ReadingProgressTableTableUpdateCompanionBuilder,
        (ReadingProgress, $$ReadingProgressTableTableReferences),
        ReadingProgress,
        PrefetchHooks Function({bool sessionId, bool bookId})>;
typedef $$ParticipantReadingTimeTableTableCreateCompanionBuilder
    = ParticipantReadingTimeTableCompanion Function({
  required String id,
  required String sessionId,
  required String deviceId,
  Value<int> totalSeconds,
  required DateTime lastActiveAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ParticipantReadingTimeTableTableUpdateCompanionBuilder
    = ParticipantReadingTimeTableCompanion Function({
  Value<String> id,
  Value<String> sessionId,
  Value<String> deviceId,
  Value<int> totalSeconds,
  Value<DateTime> lastActiveAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$ParticipantReadingTimeTableTableReferences extends BaseReferences<
    _$AppDatabase, $ParticipantReadingTimeTableTable, ParticipantReadingTime> {
  $$ParticipantReadingTimeTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTableTable _sessionIdTable(_$AppDatabase db) =>
      db.sessionsTable.createAlias($_aliasNameGenerator(
          db.participantReadingTimeTable.sessionId, db.sessionsTable.id));

  $$SessionsTableTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableTableManager($_db, $_db.sessionsTable)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ParticipantReadingTimeTableTableFilterComposer
    extends Composer<_$AppDatabase, $ParticipantReadingTimeTableTable> {
  $$ParticipantReadingTimeTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalSeconds => $composableBuilder(
      column: $table.totalSeconds, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastActiveAt => $composableBuilder(
      column: $table.lastActiveAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$SessionsTableTableFilterComposer get sessionId {
    final $$SessionsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableFilterComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ParticipantReadingTimeTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ParticipantReadingTimeTableTable> {
  $$ParticipantReadingTimeTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalSeconds => $composableBuilder(
      column: $table.totalSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastActiveAt => $composableBuilder(
      column: $table.lastActiveAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$SessionsTableTableOrderingComposer get sessionId {
    final $$SessionsTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableOrderingComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ParticipantReadingTimeTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ParticipantReadingTimeTableTable> {
  $$ParticipantReadingTimeTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get totalSeconds => $composableBuilder(
      column: $table.totalSeconds, builder: (column) => column);

  GeneratedColumn<DateTime> get lastActiveAt => $composableBuilder(
      column: $table.lastActiveAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$SessionsTableTableAnnotationComposer get sessionId {
    final $$SessionsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ParticipantReadingTimeTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ParticipantReadingTimeTableTable,
    ParticipantReadingTime,
    $$ParticipantReadingTimeTableTableFilterComposer,
    $$ParticipantReadingTimeTableTableOrderingComposer,
    $$ParticipantReadingTimeTableTableAnnotationComposer,
    $$ParticipantReadingTimeTableTableCreateCompanionBuilder,
    $$ParticipantReadingTimeTableTableUpdateCompanionBuilder,
    (ParticipantReadingTime, $$ParticipantReadingTimeTableTableReferences),
    ParticipantReadingTime,
    PrefetchHooks Function({bool sessionId})> {
  $$ParticipantReadingTimeTableTableTableManager(
      _$AppDatabase db, $ParticipantReadingTimeTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ParticipantReadingTimeTableTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$ParticipantReadingTimeTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ParticipantReadingTimeTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sessionId = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<int> totalSeconds = const Value.absent(),
            Value<DateTime> lastActiveAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ParticipantReadingTimeTableCompanion(
            id: id,
            sessionId: sessionId,
            deviceId: deviceId,
            totalSeconds: totalSeconds,
            lastActiveAt: lastActiveAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sessionId,
            required String deviceId,
            Value<int> totalSeconds = const Value.absent(),
            required DateTime lastActiveAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ParticipantReadingTimeTableCompanion.insert(
            id: id,
            sessionId: sessionId,
            deviceId: deviceId,
            totalSeconds: totalSeconds,
            lastActiveAt: lastActiveAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ParticipantReadingTimeTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (sessionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sessionId,
                    referencedTable:
                        $$ParticipantReadingTimeTableTableReferences
                            ._sessionIdTable(db),
                    referencedColumn:
                        $$ParticipantReadingTimeTableTableReferences
                            ._sessionIdTable(db)
                            .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ParticipantReadingTimeTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $ParticipantReadingTimeTableTable,
        ParticipantReadingTime,
        $$ParticipantReadingTimeTableTableFilterComposer,
        $$ParticipantReadingTimeTableTableOrderingComposer,
        $$ParticipantReadingTimeTableTableAnnotationComposer,
        $$ParticipantReadingTimeTableTableCreateCompanionBuilder,
        $$ParticipantReadingTimeTableTableUpdateCompanionBuilder,
        (ParticipantReadingTime, $$ParticipantReadingTimeTableTableReferences),
        ParticipantReadingTime,
        PrefetchHooks Function({bool sessionId})>;
typedef $$PageActivityTableTableCreateCompanionBuilder
    = PageActivityTableCompanion Function({
  required String id,
  required String sessionId,
  required String bookId,
  required int pageNumber,
  required String deviceId,
  required int durationSeconds,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$PageActivityTableTableUpdateCompanionBuilder
    = PageActivityTableCompanion Function({
  Value<String> id,
  Value<String> sessionId,
  Value<String> bookId,
  Value<int> pageNumber,
  Value<String> deviceId,
  Value<int> durationSeconds,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$PageActivityTableTableReferences extends BaseReferences<
    _$AppDatabase, $PageActivityTableTable, PageActivity> {
  $$PageActivityTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTableTable _sessionIdTable(_$AppDatabase db) =>
      db.sessionsTable.createAlias($_aliasNameGenerator(
          db.pageActivityTable.sessionId, db.sessionsTable.id));

  $$SessionsTableTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableTableManager($_db, $_db.sessionsTable)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $BooksTableTable _bookIdTable(_$AppDatabase db) =>
      db.booksTable.createAlias(
          $_aliasNameGenerator(db.pageActivityTable.bookId, db.booksTable.id));

  $$BooksTableTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<String>('book_id')!;

    final manager = $$BooksTableTableTableManager($_db, $_db.booksTable)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$PageActivityTableTableFilterComposer
    extends Composer<_$AppDatabase, $PageActivityTableTable> {
  $$PageActivityTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pageNumber => $composableBuilder(
      column: $table.pageNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$SessionsTableTableFilterComposer get sessionId {
    final $$SessionsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableFilterComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BooksTableTableFilterComposer get bookId {
    final $$BooksTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.booksTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableTableFilterComposer(
              $db: $db,
              $table: $db.booksTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PageActivityTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PageActivityTableTable> {
  $$PageActivityTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pageNumber => $composableBuilder(
      column: $table.pageNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$SessionsTableTableOrderingComposer get sessionId {
    final $$SessionsTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableOrderingComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BooksTableTableOrderingComposer get bookId {
    final $$BooksTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.booksTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableTableOrderingComposer(
              $db: $db,
              $table: $db.booksTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PageActivityTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PageActivityTableTable> {
  $$PageActivityTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get pageNumber => $composableBuilder(
      column: $table.pageNumber, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SessionsTableTableAnnotationComposer get sessionId {
    final $$SessionsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BooksTableTableAnnotationComposer get bookId {
    final $$BooksTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.booksTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableTableAnnotationComposer(
              $db: $db,
              $table: $db.booksTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PageActivityTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PageActivityTableTable,
    PageActivity,
    $$PageActivityTableTableFilterComposer,
    $$PageActivityTableTableOrderingComposer,
    $$PageActivityTableTableAnnotationComposer,
    $$PageActivityTableTableCreateCompanionBuilder,
    $$PageActivityTableTableUpdateCompanionBuilder,
    (PageActivity, $$PageActivityTableTableReferences),
    PageActivity,
    PrefetchHooks Function({bool sessionId, bool bookId})> {
  $$PageActivityTableTableTableManager(
      _$AppDatabase db, $PageActivityTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PageActivityTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PageActivityTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PageActivityTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sessionId = const Value.absent(),
            Value<String> bookId = const Value.absent(),
            Value<int> pageNumber = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<int> durationSeconds = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PageActivityTableCompanion(
            id: id,
            sessionId: sessionId,
            bookId: bookId,
            pageNumber: pageNumber,
            deviceId: deviceId,
            durationSeconds: durationSeconds,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sessionId,
            required String bookId,
            required int pageNumber,
            required String deviceId,
            required int durationSeconds,
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PageActivityTableCompanion.insert(
            id: id,
            sessionId: sessionId,
            bookId: bookId,
            pageNumber: pageNumber,
            deviceId: deviceId,
            durationSeconds: durationSeconds,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$PageActivityTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({sessionId = false, bookId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (sessionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sessionId,
                    referencedTable:
                        $$PageActivityTableTableReferences._sessionIdTable(db),
                    referencedColumn: $$PageActivityTableTableReferences
                        ._sessionIdTable(db)
                        .id,
                  ) as T;
                }
                if (bookId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.bookId,
                    referencedTable:
                        $$PageActivityTableTableReferences._bookIdTable(db),
                    referencedColumn:
                        $$PageActivityTableTableReferences._bookIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$PageActivityTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PageActivityTableTable,
    PageActivity,
    $$PageActivityTableTableFilterComposer,
    $$PageActivityTableTableOrderingComposer,
    $$PageActivityTableTableAnnotationComposer,
    $$PageActivityTableTableCreateCompanionBuilder,
    $$PageActivityTableTableUpdateCompanionBuilder,
    (PageActivity, $$PageActivityTableTableReferences),
    PageActivity,
    PrefetchHooks Function({bool sessionId, bool bookId})>;
typedef $$MessagesTableTableCreateCompanionBuilder = MessagesTableCompanion
    Function({
  required String id,
  required String sessionId,
  required String senderId,
  required String senderName,
  required String content,
  required String messageType,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$MessagesTableTableUpdateCompanionBuilder = MessagesTableCompanion
    Function({
  Value<String> id,
  Value<String> sessionId,
  Value<String> senderId,
  Value<String> senderName,
  Value<String> content,
  Value<String> messageType,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$MessagesTableTableReferences
    extends BaseReferences<_$AppDatabase, $MessagesTableTable, Message> {
  $$MessagesTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTableTable _sessionIdTable(_$AppDatabase db) =>
      db.sessionsTable.createAlias($_aliasNameGenerator(
          db.messagesTable.sessionId, db.sessionsTable.id));

  $$SessionsTableTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableTableManager($_db, $_db.sessionsTable)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$MessagesTableTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTableTable> {
  $$MessagesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderName => $composableBuilder(
      column: $table.senderName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get messageType => $composableBuilder(
      column: $table.messageType, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$SessionsTableTableFilterComposer get sessionId {
    final $$SessionsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableFilterComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MessagesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTableTable> {
  $$MessagesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderName => $composableBuilder(
      column: $table.senderName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get messageType => $composableBuilder(
      column: $table.messageType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$SessionsTableTableOrderingComposer get sessionId {
    final $$SessionsTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableOrderingComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MessagesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTableTable> {
  $$MessagesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get senderName => $composableBuilder(
      column: $table.senderName, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get messageType => $composableBuilder(
      column: $table.messageType, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SessionsTableTableAnnotationComposer get sessionId {
    final $$SessionsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MessagesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MessagesTableTable,
    Message,
    $$MessagesTableTableFilterComposer,
    $$MessagesTableTableOrderingComposer,
    $$MessagesTableTableAnnotationComposer,
    $$MessagesTableTableCreateCompanionBuilder,
    $$MessagesTableTableUpdateCompanionBuilder,
    (Message, $$MessagesTableTableReferences),
    Message,
    PrefetchHooks Function({bool sessionId})> {
  $$MessagesTableTableTableManager(_$AppDatabase db, $MessagesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sessionId = const Value.absent(),
            Value<String> senderId = const Value.absent(),
            Value<String> senderName = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<String> messageType = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MessagesTableCompanion(
            id: id,
            sessionId: sessionId,
            senderId: senderId,
            senderName: senderName,
            content: content,
            messageType: messageType,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sessionId,
            required String senderId,
            required String senderName,
            required String content,
            required String messageType,
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              MessagesTableCompanion.insert(
            id: id,
            sessionId: sessionId,
            senderId: senderId,
            senderName: senderName,
            content: content,
            messageType: messageType,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$MessagesTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (sessionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sessionId,
                    referencedTable:
                        $$MessagesTableTableReferences._sessionIdTable(db),
                    referencedColumn:
                        $$MessagesTableTableReferences._sessionIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$MessagesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MessagesTableTable,
    Message,
    $$MessagesTableTableFilterComposer,
    $$MessagesTableTableOrderingComposer,
    $$MessagesTableTableAnnotationComposer,
    $$MessagesTableTableCreateCompanionBuilder,
    $$MessagesTableTableUpdateCompanionBuilder,
    (Message, $$MessagesTableTableReferences),
    Message,
    PrefetchHooks Function({bool sessionId})>;
typedef $$NotesTableTableCreateCompanionBuilder = NotesTableCompanion Function({
  required String id,
  required String bookId,
  required int pageNumber,
  required String deviceId,
  required String authorName,
  required String content,
  required String color,
  Value<double?> positionX,
  Value<double?> positionY,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$NotesTableTableUpdateCompanionBuilder = NotesTableCompanion Function({
  Value<String> id,
  Value<String> bookId,
  Value<int> pageNumber,
  Value<String> deviceId,
  Value<String> authorName,
  Value<String> content,
  Value<String> color,
  Value<double?> positionX,
  Value<double?> positionY,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$NotesTableTableReferences
    extends BaseReferences<_$AppDatabase, $NotesTableTable, Note> {
  $$NotesTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BooksTableTable _bookIdTable(_$AppDatabase db) =>
      db.booksTable.createAlias(
          $_aliasNameGenerator(db.notesTable.bookId, db.booksTable.id));

  $$BooksTableTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<String>('book_id')!;

    final manager = $$BooksTableTableTableManager($_db, $_db.booksTable)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$NotesTableTableFilterComposer
    extends Composer<_$AppDatabase, $NotesTableTable> {
  $$NotesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pageNumber => $composableBuilder(
      column: $table.pageNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get authorName => $composableBuilder(
      column: $table.authorName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get positionX => $composableBuilder(
      column: $table.positionX, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get positionY => $composableBuilder(
      column: $table.positionY, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$BooksTableTableFilterComposer get bookId {
    final $$BooksTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.booksTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableTableFilterComposer(
              $db: $db,
              $table: $db.booksTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$NotesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $NotesTableTable> {
  $$NotesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pageNumber => $composableBuilder(
      column: $table.pageNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get authorName => $composableBuilder(
      column: $table.authorName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get positionX => $composableBuilder(
      column: $table.positionX, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get positionY => $composableBuilder(
      column: $table.positionY, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$BooksTableTableOrderingComposer get bookId {
    final $$BooksTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.booksTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableTableOrderingComposer(
              $db: $db,
              $table: $db.booksTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$NotesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotesTableTable> {
  $$NotesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get pageNumber => $composableBuilder(
      column: $table.pageNumber, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get authorName => $composableBuilder(
      column: $table.authorName, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<double> get positionX =>
      $composableBuilder(column: $table.positionX, builder: (column) => column);

  GeneratedColumn<double> get positionY =>
      $composableBuilder(column: $table.positionY, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$BooksTableTableAnnotationComposer get bookId {
    final $$BooksTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.booksTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableTableAnnotationComposer(
              $db: $db,
              $table: $db.booksTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$NotesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NotesTableTable,
    Note,
    $$NotesTableTableFilterComposer,
    $$NotesTableTableOrderingComposer,
    $$NotesTableTableAnnotationComposer,
    $$NotesTableTableCreateCompanionBuilder,
    $$NotesTableTableUpdateCompanionBuilder,
    (Note, $$NotesTableTableReferences),
    Note,
    PrefetchHooks Function({bool bookId})> {
  $$NotesTableTableTableManager(_$AppDatabase db, $NotesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> bookId = const Value.absent(),
            Value<int> pageNumber = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<String> authorName = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<String> color = const Value.absent(),
            Value<double?> positionX = const Value.absent(),
            Value<double?> positionY = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NotesTableCompanion(
            id: id,
            bookId: bookId,
            pageNumber: pageNumber,
            deviceId: deviceId,
            authorName: authorName,
            content: content,
            color: color,
            positionX: positionX,
            positionY: positionY,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String bookId,
            required int pageNumber,
            required String deviceId,
            required String authorName,
            required String content,
            required String color,
            Value<double?> positionX = const Value.absent(),
            Value<double?> positionY = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              NotesTableCompanion.insert(
            id: id,
            bookId: bookId,
            pageNumber: pageNumber,
            deviceId: deviceId,
            authorName: authorName,
            content: content,
            color: color,
            positionX: positionX,
            positionY: positionY,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$NotesTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({bookId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (bookId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.bookId,
                    referencedTable:
                        $$NotesTableTableReferences._bookIdTable(db),
                    referencedColumn:
                        $$NotesTableTableReferences._bookIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$NotesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $NotesTableTable,
    Note,
    $$NotesTableTableFilterComposer,
    $$NotesTableTableOrderingComposer,
    $$NotesTableTableAnnotationComposer,
    $$NotesTableTableCreateCompanionBuilder,
    $$NotesTableTableUpdateCompanionBuilder,
    (Note, $$NotesTableTableReferences),
    Note,
    PrefetchHooks Function({bool bookId})>;
typedef $$KvsTableTableCreateCompanionBuilder = KvsTableCompanion Function({
  required String key,
  required String value,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$KvsTableTableUpdateCompanionBuilder = KvsTableCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$KvsTableTableFilterComposer
    extends Composer<_$AppDatabase, $KvsTableTable> {
  $$KvsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$KvsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $KvsTableTable> {
  $$KvsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$KvsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $KvsTableTable> {
  $$KvsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$KvsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $KvsTableTable,
    KvsEntry,
    $$KvsTableTableFilterComposer,
    $$KvsTableTableOrderingComposer,
    $$KvsTableTableAnnotationComposer,
    $$KvsTableTableCreateCompanionBuilder,
    $$KvsTableTableUpdateCompanionBuilder,
    (KvsEntry, BaseReferences<_$AppDatabase, $KvsTableTable, KvsEntry>),
    KvsEntry,
    PrefetchHooks Function()> {
  $$KvsTableTableTableManager(_$AppDatabase db, $KvsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KvsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KvsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KvsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              KvsTableCompanion(
            key: key,
            value: value,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              KvsTableCompanion.insert(
            key: key,
            value: value,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$KvsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $KvsTableTable,
    KvsEntry,
    $$KvsTableTableFilterComposer,
    $$KvsTableTableOrderingComposer,
    $$KvsTableTableAnnotationComposer,
    $$KvsTableTableCreateCompanionBuilder,
    $$KvsTableTableUpdateCompanionBuilder,
    (KvsEntry, BaseReferences<_$AppDatabase, $KvsTableTable, KvsEntry>),
    KvsEntry,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DeviceProfileTableTableTableManager get deviceProfileTable =>
      $$DeviceProfileTableTableTableManager(_db, _db.deviceProfileTable);
  $$BooksTableTableTableManager get booksTable =>
      $$BooksTableTableTableManager(_db, _db.booksTable);
  $$SessionsTableTableTableManager get sessionsTable =>
      $$SessionsTableTableTableManager(_db, _db.sessionsTable);
  $$SessionMembersTableTableTableManager get sessionMembersTable =>
      $$SessionMembersTableTableTableManager(_db, _db.sessionMembersTable);
  $$SessionEventsTableTableTableManager get sessionEventsTable =>
      $$SessionEventsTableTableTableManager(_db, _db.sessionEventsTable);
  $$OutboxTableTableTableManager get outboxTable =>
      $$OutboxTableTableTableManager(_db, _db.outboxTable);
  $$ReadingProgressTableTableTableManager get readingProgressTable =>
      $$ReadingProgressTableTableTableManager(_db, _db.readingProgressTable);
  $$ParticipantReadingTimeTableTableTableManager
      get participantReadingTimeTable =>
          $$ParticipantReadingTimeTableTableTableManager(
              _db, _db.participantReadingTimeTable);
  $$PageActivityTableTableTableManager get pageActivityTable =>
      $$PageActivityTableTableTableManager(_db, _db.pageActivityTable);
  $$MessagesTableTableTableManager get messagesTable =>
      $$MessagesTableTableTableManager(_db, _db.messagesTable);
  $$NotesTableTableTableManager get notesTable =>
      $$NotesTableTableTableManager(_db, _db.notesTable);
  $$KvsTableTableTableManager get kvsTable =>
      $$KvsTableTableTableManager(_db, _db.kvsTable);
}
