// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, Transaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payeeUpiIdMeta = const VerificationMeta(
    'payeeUpiId',
  );
  @override
  late final GeneratedColumn<String> payeeUpiId = GeneratedColumn<String>(
    'payee_upi_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payeeNameMeta = const VerificationMeta(
    'payeeName',
  );
  @override
  late final GeneratedColumn<String> payeeName = GeneratedColumn<String>(
    'payee_name',
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
    defaultValue: const Constant('INR'),
  );
  static const VerificationMeta _transactionNoteMeta = const VerificationMeta(
    'transactionNote',
  );
  @override
  late final GeneratedColumn<String> transactionNote = GeneratedColumn<String>(
    'transaction_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transactionRefMeta = const VerificationMeta(
    'transactionRef',
  );
  @override
  late final GeneratedColumn<String> transactionRef = GeneratedColumn<String>(
    'transaction_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _upiTxnIdMeta = const VerificationMeta(
    'upiTxnId',
  );
  @override
  late final GeneratedColumn<String> upiTxnId = GeneratedColumn<String>(
    'upi_txn_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _approvalRefNoMeta = const VerificationMeta(
    'approvalRefNo',
  );
  @override
  late final GeneratedColumn<String> approvalRefNo = GeneratedColumn<String>(
    'approval_ref_no',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _responseCodeMeta = const VerificationMeta(
    'responseCode',
  );
  @override
  late final GeneratedColumn<String> responseCode = GeneratedColumn<String>(
    'response_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('INITIATED'),
  );
  static const VerificationMeta _paymentModeMeta = const VerificationMeta(
    'paymentMode',
  );
  @override
  late final GeneratedColumn<String> paymentMode = GeneratedColumn<String>(
    'payment_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qrTypeMeta = const VerificationMeta('qrType');
  @override
  late final GeneratedColumn<String> qrType = GeneratedColumn<String>(
    'qr_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _upiAppMeta = const VerificationMeta('upiApp');
  @override
  late final GeneratedColumn<String> upiApp = GeneratedColumn<String>(
    'upi_app',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _upiAppNameMeta = const VerificationMeta(
    'upiAppName',
  );
  @override
  late final GeneratedColumn<String> upiAppName = GeneratedColumn<String>(
    'upi_app_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Others'),
  );
<<<<<<< HEAD
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('DEBIT'),
  );
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
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
    payeeUpiId,
    payeeName,
    amount,
    currency,
    transactionNote,
    transactionRef,
    upiTxnId,
    approvalRefNo,
    responseCode,
    status,
    paymentMode,
    qrType,
    upiApp,
    upiAppName,
    category,
<<<<<<< HEAD
    direction,
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('payee_upi_id')) {
      context.handle(
        _payeeUpiIdMeta,
        payeeUpiId.isAcceptableOrUnknown(
          data['payee_upi_id']!,
          _payeeUpiIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payeeUpiIdMeta);
    }
    if (data.containsKey('payee_name')) {
      context.handle(
        _payeeNameMeta,
        payeeName.isAcceptableOrUnknown(data['payee_name']!, _payeeNameMeta),
      );
    } else if (isInserting) {
      context.missing(_payeeNameMeta);
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
    if (data.containsKey('transaction_note')) {
      context.handle(
        _transactionNoteMeta,
        transactionNote.isAcceptableOrUnknown(
          data['transaction_note']!,
          _transactionNoteMeta,
        ),
      );
    }
    if (data.containsKey('transaction_ref')) {
      context.handle(
        _transactionRefMeta,
        transactionRef.isAcceptableOrUnknown(
          data['transaction_ref']!,
          _transactionRefMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionRefMeta);
    }
    if (data.containsKey('upi_txn_id')) {
      context.handle(
        _upiTxnIdMeta,
        upiTxnId.isAcceptableOrUnknown(data['upi_txn_id']!, _upiTxnIdMeta),
      );
    }
    if (data.containsKey('approval_ref_no')) {
      context.handle(
        _approvalRefNoMeta,
        approvalRefNo.isAcceptableOrUnknown(
          data['approval_ref_no']!,
          _approvalRefNoMeta,
        ),
      );
    }
    if (data.containsKey('response_code')) {
      context.handle(
        _responseCodeMeta,
        responseCode.isAcceptableOrUnknown(
          data['response_code']!,
          _responseCodeMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('payment_mode')) {
      context.handle(
        _paymentModeMeta,
        paymentMode.isAcceptableOrUnknown(
          data['payment_mode']!,
          _paymentModeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paymentModeMeta);
    }
    if (data.containsKey('qr_type')) {
      context.handle(
        _qrTypeMeta,
        qrType.isAcceptableOrUnknown(data['qr_type']!, _qrTypeMeta),
      );
    }
    if (data.containsKey('upi_app')) {
      context.handle(
        _upiAppMeta,
        upiApp.isAcceptableOrUnknown(data['upi_app']!, _upiAppMeta),
      );
    }
    if (data.containsKey('upi_app_name')) {
      context.handle(
        _upiAppNameMeta,
        upiAppName.isAcceptableOrUnknown(
          data['upi_app_name']!,
          _upiAppNameMeta,
        ),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
<<<<<<< HEAD
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    }
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
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
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      payeeUpiId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payee_upi_id'],
      )!,
      payeeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payee_name'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      transactionNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_note'],
      ),
      transactionRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_ref'],
      )!,
      upiTxnId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}upi_txn_id'],
      ),
      approvalRefNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}approval_ref_no'],
      ),
      responseCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}response_code'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      paymentMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_mode'],
      )!,
      qrType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}qr_type'],
      ),
      upiApp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}upi_app'],
      ),
      upiAppName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}upi_app_name'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
<<<<<<< HEAD
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
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
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }
}

class Transaction extends DataClass implements Insertable<Transaction> {
  final String id;
  final String payeeUpiId;
  final String payeeName;
  final double amount;
  final String currency;
  final String? transactionNote;
  final String transactionRef;
  final String? upiTxnId;
  final String? approvalRefNo;
  final String? responseCode;
  final String status;
  final String paymentMode;
  final String? qrType;
  final String? upiApp;
  final String? upiAppName;
  final String category;
<<<<<<< HEAD
  final String direction;
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
  final DateTime createdAt;
  final DateTime updatedAt;
  const Transaction({
    required this.id,
    required this.payeeUpiId,
    required this.payeeName,
    required this.amount,
    required this.currency,
    this.transactionNote,
    required this.transactionRef,
    this.upiTxnId,
    this.approvalRefNo,
    this.responseCode,
    required this.status,
    required this.paymentMode,
    this.qrType,
    this.upiApp,
    this.upiAppName,
    required this.category,
<<<<<<< HEAD
    required this.direction,
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['payee_upi_id'] = Variable<String>(payeeUpiId);
    map['payee_name'] = Variable<String>(payeeName);
    map['amount'] = Variable<double>(amount);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || transactionNote != null) {
      map['transaction_note'] = Variable<String>(transactionNote);
    }
    map['transaction_ref'] = Variable<String>(transactionRef);
    if (!nullToAbsent || upiTxnId != null) {
      map['upi_txn_id'] = Variable<String>(upiTxnId);
    }
    if (!nullToAbsent || approvalRefNo != null) {
      map['approval_ref_no'] = Variable<String>(approvalRefNo);
    }
    if (!nullToAbsent || responseCode != null) {
      map['response_code'] = Variable<String>(responseCode);
    }
    map['status'] = Variable<String>(status);
    map['payment_mode'] = Variable<String>(paymentMode);
    if (!nullToAbsent || qrType != null) {
      map['qr_type'] = Variable<String>(qrType);
    }
    if (!nullToAbsent || upiApp != null) {
      map['upi_app'] = Variable<String>(upiApp);
    }
    if (!nullToAbsent || upiAppName != null) {
      map['upi_app_name'] = Variable<String>(upiAppName);
    }
    map['category'] = Variable<String>(category);
<<<<<<< HEAD
    map['direction'] = Variable<String>(direction);
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      payeeUpiId: Value(payeeUpiId),
      payeeName: Value(payeeName),
      amount: Value(amount),
      currency: Value(currency),
      transactionNote: transactionNote == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionNote),
      transactionRef: Value(transactionRef),
      upiTxnId: upiTxnId == null && nullToAbsent
          ? const Value.absent()
          : Value(upiTxnId),
      approvalRefNo: approvalRefNo == null && nullToAbsent
          ? const Value.absent()
          : Value(approvalRefNo),
      responseCode: responseCode == null && nullToAbsent
          ? const Value.absent()
          : Value(responseCode),
      status: Value(status),
      paymentMode: Value(paymentMode),
      qrType: qrType == null && nullToAbsent
          ? const Value.absent()
          : Value(qrType),
      upiApp: upiApp == null && nullToAbsent
          ? const Value.absent()
          : Value(upiApp),
      upiAppName: upiAppName == null && nullToAbsent
          ? const Value.absent()
          : Value(upiAppName),
      category: Value(category),
<<<<<<< HEAD
      direction: Value(direction),
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Transaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      id: serializer.fromJson<String>(json['id']),
      payeeUpiId: serializer.fromJson<String>(json['payeeUpiId']),
      payeeName: serializer.fromJson<String>(json['payeeName']),
      amount: serializer.fromJson<double>(json['amount']),
      currency: serializer.fromJson<String>(json['currency']),
      transactionNote: serializer.fromJson<String?>(json['transactionNote']),
      transactionRef: serializer.fromJson<String>(json['transactionRef']),
      upiTxnId: serializer.fromJson<String?>(json['upiTxnId']),
      approvalRefNo: serializer.fromJson<String?>(json['approvalRefNo']),
      responseCode: serializer.fromJson<String?>(json['responseCode']),
      status: serializer.fromJson<String>(json['status']),
      paymentMode: serializer.fromJson<String>(json['paymentMode']),
      qrType: serializer.fromJson<String?>(json['qrType']),
      upiApp: serializer.fromJson<String?>(json['upiApp']),
      upiAppName: serializer.fromJson<String?>(json['upiAppName']),
      category: serializer.fromJson<String>(json['category']),
<<<<<<< HEAD
      direction: serializer.fromJson<String>(json['direction']),
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'payeeUpiId': serializer.toJson<String>(payeeUpiId),
      'payeeName': serializer.toJson<String>(payeeName),
      'amount': serializer.toJson<double>(amount),
      'currency': serializer.toJson<String>(currency),
      'transactionNote': serializer.toJson<String?>(transactionNote),
      'transactionRef': serializer.toJson<String>(transactionRef),
      'upiTxnId': serializer.toJson<String?>(upiTxnId),
      'approvalRefNo': serializer.toJson<String?>(approvalRefNo),
      'responseCode': serializer.toJson<String?>(responseCode),
      'status': serializer.toJson<String>(status),
      'paymentMode': serializer.toJson<String>(paymentMode),
      'qrType': serializer.toJson<String?>(qrType),
      'upiApp': serializer.toJson<String?>(upiApp),
      'upiAppName': serializer.toJson<String?>(upiAppName),
      'category': serializer.toJson<String>(category),
<<<<<<< HEAD
      'direction': serializer.toJson<String>(direction),
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Transaction copyWith({
    String? id,
    String? payeeUpiId,
    String? payeeName,
    double? amount,
    String? currency,
    Value<String?> transactionNote = const Value.absent(),
    String? transactionRef,
    Value<String?> upiTxnId = const Value.absent(),
    Value<String?> approvalRefNo = const Value.absent(),
    Value<String?> responseCode = const Value.absent(),
    String? status,
    String? paymentMode,
    Value<String?> qrType = const Value.absent(),
    Value<String?> upiApp = const Value.absent(),
    Value<String?> upiAppName = const Value.absent(),
    String? category,
<<<<<<< HEAD
    String? direction,
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Transaction(
    id: id ?? this.id,
    payeeUpiId: payeeUpiId ?? this.payeeUpiId,
    payeeName: payeeName ?? this.payeeName,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    transactionNote: transactionNote.present
        ? transactionNote.value
        : this.transactionNote,
    transactionRef: transactionRef ?? this.transactionRef,
    upiTxnId: upiTxnId.present ? upiTxnId.value : this.upiTxnId,
    approvalRefNo: approvalRefNo.present
        ? approvalRefNo.value
        : this.approvalRefNo,
    responseCode: responseCode.present ? responseCode.value : this.responseCode,
    status: status ?? this.status,
    paymentMode: paymentMode ?? this.paymentMode,
    qrType: qrType.present ? qrType.value : this.qrType,
    upiApp: upiApp.present ? upiApp.value : this.upiApp,
    upiAppName: upiAppName.present ? upiAppName.value : this.upiAppName,
    category: category ?? this.category,
<<<<<<< HEAD
    direction: direction ?? this.direction,
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      id: data.id.present ? data.id.value : this.id,
      payeeUpiId: data.payeeUpiId.present
          ? data.payeeUpiId.value
          : this.payeeUpiId,
      payeeName: data.payeeName.present ? data.payeeName.value : this.payeeName,
      amount: data.amount.present ? data.amount.value : this.amount,
      currency: data.currency.present ? data.currency.value : this.currency,
      transactionNote: data.transactionNote.present
          ? data.transactionNote.value
          : this.transactionNote,
      transactionRef: data.transactionRef.present
          ? data.transactionRef.value
          : this.transactionRef,
      upiTxnId: data.upiTxnId.present ? data.upiTxnId.value : this.upiTxnId,
      approvalRefNo: data.approvalRefNo.present
          ? data.approvalRefNo.value
          : this.approvalRefNo,
      responseCode: data.responseCode.present
          ? data.responseCode.value
          : this.responseCode,
      status: data.status.present ? data.status.value : this.status,
      paymentMode: data.paymentMode.present
          ? data.paymentMode.value
          : this.paymentMode,
      qrType: data.qrType.present ? data.qrType.value : this.qrType,
      upiApp: data.upiApp.present ? data.upiApp.value : this.upiApp,
      upiAppName: data.upiAppName.present
          ? data.upiAppName.value
          : this.upiAppName,
      category: data.category.present ? data.category.value : this.category,
<<<<<<< HEAD
      direction: data.direction.present ? data.direction.value : this.direction,
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('payeeUpiId: $payeeUpiId, ')
          ..write('payeeName: $payeeName, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('transactionNote: $transactionNote, ')
          ..write('transactionRef: $transactionRef, ')
          ..write('upiTxnId: $upiTxnId, ')
          ..write('approvalRefNo: $approvalRefNo, ')
          ..write('responseCode: $responseCode, ')
          ..write('status: $status, ')
          ..write('paymentMode: $paymentMode, ')
          ..write('qrType: $qrType, ')
          ..write('upiApp: $upiApp, ')
          ..write('upiAppName: $upiAppName, ')
          ..write('category: $category, ')
<<<<<<< HEAD
          ..write('direction: $direction, ')
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    payeeUpiId,
    payeeName,
    amount,
    currency,
    transactionNote,
    transactionRef,
    upiTxnId,
    approvalRefNo,
    responseCode,
    status,
    paymentMode,
    qrType,
    upiApp,
    upiAppName,
    category,
<<<<<<< HEAD
    direction,
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.payeeUpiId == this.payeeUpiId &&
          other.payeeName == this.payeeName &&
          other.amount == this.amount &&
          other.currency == this.currency &&
          other.transactionNote == this.transactionNote &&
          other.transactionRef == this.transactionRef &&
          other.upiTxnId == this.upiTxnId &&
          other.approvalRefNo == this.approvalRefNo &&
          other.responseCode == this.responseCode &&
          other.status == this.status &&
          other.paymentMode == this.paymentMode &&
          other.qrType == this.qrType &&
          other.upiApp == this.upiApp &&
          other.upiAppName == this.upiAppName &&
          other.category == this.category &&
<<<<<<< HEAD
          other.direction == this.direction &&
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<String> id;
  final Value<String> payeeUpiId;
  final Value<String> payeeName;
  final Value<double> amount;
  final Value<String> currency;
  final Value<String?> transactionNote;
  final Value<String> transactionRef;
  final Value<String?> upiTxnId;
  final Value<String?> approvalRefNo;
  final Value<String?> responseCode;
  final Value<String> status;
  final Value<String> paymentMode;
  final Value<String?> qrType;
  final Value<String?> upiApp;
  final Value<String?> upiAppName;
  final Value<String> category;
<<<<<<< HEAD
  final Value<String> direction;
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.payeeUpiId = const Value.absent(),
    this.payeeName = const Value.absent(),
    this.amount = const Value.absent(),
    this.currency = const Value.absent(),
    this.transactionNote = const Value.absent(),
    this.transactionRef = const Value.absent(),
    this.upiTxnId = const Value.absent(),
    this.approvalRefNo = const Value.absent(),
    this.responseCode = const Value.absent(),
    this.status = const Value.absent(),
    this.paymentMode = const Value.absent(),
    this.qrType = const Value.absent(),
    this.upiApp = const Value.absent(),
    this.upiAppName = const Value.absent(),
    this.category = const Value.absent(),
<<<<<<< HEAD
    this.direction = const Value.absent(),
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionsCompanion.insert({
    required String id,
    required String payeeUpiId,
    required String payeeName,
    required double amount,
    this.currency = const Value.absent(),
    this.transactionNote = const Value.absent(),
    required String transactionRef,
    this.upiTxnId = const Value.absent(),
    this.approvalRefNo = const Value.absent(),
    this.responseCode = const Value.absent(),
    this.status = const Value.absent(),
    required String paymentMode,
    this.qrType = const Value.absent(),
    this.upiApp = const Value.absent(),
    this.upiAppName = const Value.absent(),
    this.category = const Value.absent(),
<<<<<<< HEAD
    this.direction = const Value.absent(),
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       payeeUpiId = Value(payeeUpiId),
       payeeName = Value(payeeName),
       amount = Value(amount),
       transactionRef = Value(transactionRef),
       paymentMode = Value(paymentMode);
  static Insertable<Transaction> custom({
    Expression<String>? id,
    Expression<String>? payeeUpiId,
    Expression<String>? payeeName,
    Expression<double>? amount,
    Expression<String>? currency,
    Expression<String>? transactionNote,
    Expression<String>? transactionRef,
    Expression<String>? upiTxnId,
    Expression<String>? approvalRefNo,
    Expression<String>? responseCode,
    Expression<String>? status,
    Expression<String>? paymentMode,
    Expression<String>? qrType,
    Expression<String>? upiApp,
    Expression<String>? upiAppName,
    Expression<String>? category,
<<<<<<< HEAD
    Expression<String>? direction,
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (payeeUpiId != null) 'payee_upi_id': payeeUpiId,
      if (payeeName != null) 'payee_name': payeeName,
      if (amount != null) 'amount': amount,
      if (currency != null) 'currency': currency,
      if (transactionNote != null) 'transaction_note': transactionNote,
      if (transactionRef != null) 'transaction_ref': transactionRef,
      if (upiTxnId != null) 'upi_txn_id': upiTxnId,
      if (approvalRefNo != null) 'approval_ref_no': approvalRefNo,
      if (responseCode != null) 'response_code': responseCode,
      if (status != null) 'status': status,
      if (paymentMode != null) 'payment_mode': paymentMode,
      if (qrType != null) 'qr_type': qrType,
      if (upiApp != null) 'upi_app': upiApp,
      if (upiAppName != null) 'upi_app_name': upiAppName,
      if (category != null) 'category': category,
<<<<<<< HEAD
      if (direction != null) 'direction': direction,
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? payeeUpiId,
    Value<String>? payeeName,
    Value<double>? amount,
    Value<String>? currency,
    Value<String?>? transactionNote,
    Value<String>? transactionRef,
    Value<String?>? upiTxnId,
    Value<String?>? approvalRefNo,
    Value<String?>? responseCode,
    Value<String>? status,
    Value<String>? paymentMode,
    Value<String?>? qrType,
    Value<String?>? upiApp,
    Value<String?>? upiAppName,
    Value<String>? category,
<<<<<<< HEAD
    Value<String>? direction,
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      payeeUpiId: payeeUpiId ?? this.payeeUpiId,
      payeeName: payeeName ?? this.payeeName,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      transactionNote: transactionNote ?? this.transactionNote,
      transactionRef: transactionRef ?? this.transactionRef,
      upiTxnId: upiTxnId ?? this.upiTxnId,
      approvalRefNo: approvalRefNo ?? this.approvalRefNo,
      responseCode: responseCode ?? this.responseCode,
      status: status ?? this.status,
      paymentMode: paymentMode ?? this.paymentMode,
      qrType: qrType ?? this.qrType,
      upiApp: upiApp ?? this.upiApp,
      upiAppName: upiAppName ?? this.upiAppName,
      category: category ?? this.category,
<<<<<<< HEAD
      direction: direction ?? this.direction,
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
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
    if (payeeUpiId.present) {
      map['payee_upi_id'] = Variable<String>(payeeUpiId.value);
    }
    if (payeeName.present) {
      map['payee_name'] = Variable<String>(payeeName.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (transactionNote.present) {
      map['transaction_note'] = Variable<String>(transactionNote.value);
    }
    if (transactionRef.present) {
      map['transaction_ref'] = Variable<String>(transactionRef.value);
    }
    if (upiTxnId.present) {
      map['upi_txn_id'] = Variable<String>(upiTxnId.value);
    }
    if (approvalRefNo.present) {
      map['approval_ref_no'] = Variable<String>(approvalRefNo.value);
    }
    if (responseCode.present) {
      map['response_code'] = Variable<String>(responseCode.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (paymentMode.present) {
      map['payment_mode'] = Variable<String>(paymentMode.value);
    }
    if (qrType.present) {
      map['qr_type'] = Variable<String>(qrType.value);
    }
    if (upiApp.present) {
      map['upi_app'] = Variable<String>(upiApp.value);
    }
    if (upiAppName.present) {
      map['upi_app_name'] = Variable<String>(upiAppName.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
<<<<<<< HEAD
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
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
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('payeeUpiId: $payeeUpiId, ')
          ..write('payeeName: $payeeName, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('transactionNote: $transactionNote, ')
          ..write('transactionRef: $transactionRef, ')
          ..write('upiTxnId: $upiTxnId, ')
          ..write('approvalRefNo: $approvalRefNo, ')
          ..write('responseCode: $responseCode, ')
          ..write('status: $status, ')
          ..write('paymentMode: $paymentMode, ')
          ..write('qrType: $qrType, ')
          ..write('upiApp: $upiApp, ')
          ..write('upiAppName: $upiAppName, ')
          ..write('category: $category, ')
<<<<<<< HEAD
          ..write('direction: $direction, ')
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PayeesTable extends Payees with TableInfo<$PayeesTable, Payee> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PayeesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _upiIdMeta = const VerificationMeta('upiId');
  @override
  late final GeneratedColumn<String> upiId = GeneratedColumn<String>(
    'upi_id',
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
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transactionCountMeta = const VerificationMeta(
    'transactionCount',
  );
  @override
  late final GeneratedColumn<int> transactionCount = GeneratedColumn<int>(
    'transaction_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastPaidAtMeta = const VerificationMeta(
    'lastPaidAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPaidAt = GeneratedColumn<DateTime>(
    'last_paid_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    upiId,
    name,
    phone,
    transactionCount,
    lastPaidAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payees';
  @override
  VerificationContext validateIntegrity(
    Insertable<Payee> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('upi_id')) {
      context.handle(
        _upiIdMeta,
        upiId.isAcceptableOrUnknown(data['upi_id']!, _upiIdMeta),
      );
    } else if (isInserting) {
      context.missing(_upiIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('transaction_count')) {
      context.handle(
        _transactionCountMeta,
        transactionCount.isAcceptableOrUnknown(
          data['transaction_count']!,
          _transactionCountMeta,
        ),
      );
    }
    if (data.containsKey('last_paid_at')) {
      context.handle(
        _lastPaidAtMeta,
        lastPaidAt.isAcceptableOrUnknown(
          data['last_paid_at']!,
          _lastPaidAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Payee map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Payee(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      upiId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}upi_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      transactionCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transaction_count'],
      )!,
      lastPaidAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_paid_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PayeesTable createAlias(String alias) {
    return $PayeesTable(attachedDatabase, alias);
  }
}

class Payee extends DataClass implements Insertable<Payee> {
  final String id;
  final String upiId;
  final String name;
  final String? phone;
  final int transactionCount;
  final DateTime? lastPaidAt;
  final DateTime createdAt;
  const Payee({
    required this.id,
    required this.upiId,
    required this.name,
    this.phone,
    required this.transactionCount,
    this.lastPaidAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['upi_id'] = Variable<String>(upiId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    map['transaction_count'] = Variable<int>(transactionCount);
    if (!nullToAbsent || lastPaidAt != null) {
      map['last_paid_at'] = Variable<DateTime>(lastPaidAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PayeesCompanion toCompanion(bool nullToAbsent) {
    return PayeesCompanion(
      id: Value(id),
      upiId: Value(upiId),
      name: Value(name),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      transactionCount: Value(transactionCount),
      lastPaidAt: lastPaidAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPaidAt),
      createdAt: Value(createdAt),
    );
  }

  factory Payee.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Payee(
      id: serializer.fromJson<String>(json['id']),
      upiId: serializer.fromJson<String>(json['upiId']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String?>(json['phone']),
      transactionCount: serializer.fromJson<int>(json['transactionCount']),
      lastPaidAt: serializer.fromJson<DateTime?>(json['lastPaidAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'upiId': serializer.toJson<String>(upiId),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String?>(phone),
      'transactionCount': serializer.toJson<int>(transactionCount),
      'lastPaidAt': serializer.toJson<DateTime?>(lastPaidAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Payee copyWith({
    String? id,
    String? upiId,
    String? name,
    Value<String?> phone = const Value.absent(),
    int? transactionCount,
    Value<DateTime?> lastPaidAt = const Value.absent(),
    DateTime? createdAt,
  }) => Payee(
    id: id ?? this.id,
    upiId: upiId ?? this.upiId,
    name: name ?? this.name,
    phone: phone.present ? phone.value : this.phone,
    transactionCount: transactionCount ?? this.transactionCount,
    lastPaidAt: lastPaidAt.present ? lastPaidAt.value : this.lastPaidAt,
    createdAt: createdAt ?? this.createdAt,
  );
  Payee copyWithCompanion(PayeesCompanion data) {
    return Payee(
      id: data.id.present ? data.id.value : this.id,
      upiId: data.upiId.present ? data.upiId.value : this.upiId,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      transactionCount: data.transactionCount.present
          ? data.transactionCount.value
          : this.transactionCount,
      lastPaidAt: data.lastPaidAt.present
          ? data.lastPaidAt.value
          : this.lastPaidAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Payee(')
          ..write('id: $id, ')
          ..write('upiId: $upiId, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('transactionCount: $transactionCount, ')
          ..write('lastPaidAt: $lastPaidAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    upiId,
    name,
    phone,
    transactionCount,
    lastPaidAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Payee &&
          other.id == this.id &&
          other.upiId == this.upiId &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.transactionCount == this.transactionCount &&
          other.lastPaidAt == this.lastPaidAt &&
          other.createdAt == this.createdAt);
}

class PayeesCompanion extends UpdateCompanion<Payee> {
  final Value<String> id;
  final Value<String> upiId;
  final Value<String> name;
  final Value<String?> phone;
  final Value<int> transactionCount;
  final Value<DateTime?> lastPaidAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PayeesCompanion({
    this.id = const Value.absent(),
    this.upiId = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.transactionCount = const Value.absent(),
    this.lastPaidAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PayeesCompanion.insert({
    required String id,
    required String upiId,
    required String name,
    this.phone = const Value.absent(),
    this.transactionCount = const Value.absent(),
    this.lastPaidAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       upiId = Value(upiId),
       name = Value(name);
  static Insertable<Payee> custom({
    Expression<String>? id,
    Expression<String>? upiId,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<int>? transactionCount,
    Expression<DateTime>? lastPaidAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (upiId != null) 'upi_id': upiId,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (transactionCount != null) 'transaction_count': transactionCount,
      if (lastPaidAt != null) 'last_paid_at': lastPaidAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PayeesCompanion copyWith({
    Value<String>? id,
    Value<String>? upiId,
    Value<String>? name,
    Value<String?>? phone,
    Value<int>? transactionCount,
    Value<DateTime?>? lastPaidAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PayeesCompanion(
      id: id ?? this.id,
      upiId: upiId ?? this.upiId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      transactionCount: transactionCount ?? this.transactionCount,
      lastPaidAt: lastPaidAt ?? this.lastPaidAt,
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
    if (upiId.present) {
      map['upi_id'] = Variable<String>(upiId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (transactionCount.present) {
      map['transaction_count'] = Variable<int>(transactionCount.value);
    }
    if (lastPaidAt.present) {
      map['last_paid_at'] = Variable<DateTime>(lastPaidAt.value);
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
    return (StringBuffer('PayeesCompanion(')
          ..write('id: $id, ')
          ..write('upiId: $upiId, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('transactionCount: $transactionCount, ')
          ..write('lastPaidAt: $lastPaidAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BudgetsTable extends Budgets with TableInfo<$BudgetsTable, Budget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<int> month = GeneratedColumn<int>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _limitAmountMeta = const VerificationMeta(
    'limitAmount',
  );
  @override
  late final GeneratedColumn<double> limitAmount = GeneratedColumn<double>(
    'limit_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    year,
    month,
    limitAmount,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<Budget> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    } else if (isInserting) {
      context.missing(_yearMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('limit_amount')) {
      context.handle(
        _limitAmountMeta,
        limitAmount.isAcceptableOrUnknown(
          data['limit_amount']!,
          _limitAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_limitAmountMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Budget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Budget(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}month'],
      )!,
      limitAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}limit_amount'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BudgetsTable createAlias(String alias) {
    return $BudgetsTable(attachedDatabase, alias);
  }
}

class Budget extends DataClass implements Insertable<Budget> {
  final String id;
  final int year;
  final int month;
  final double limitAmount;
  final DateTime createdAt;
  const Budget({
    required this.id,
    required this.year,
    required this.month,
    required this.limitAmount,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['year'] = Variable<int>(year);
    map['month'] = Variable<int>(month);
    map['limit_amount'] = Variable<double>(limitAmount);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BudgetsCompanion toCompanion(bool nullToAbsent) {
    return BudgetsCompanion(
      id: Value(id),
      year: Value(year),
      month: Value(month),
      limitAmount: Value(limitAmount),
      createdAt: Value(createdAt),
    );
  }

  factory Budget.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Budget(
      id: serializer.fromJson<String>(json['id']),
      year: serializer.fromJson<int>(json['year']),
      month: serializer.fromJson<int>(json['month']),
      limitAmount: serializer.fromJson<double>(json['limitAmount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'year': serializer.toJson<int>(year),
      'month': serializer.toJson<int>(month),
      'limitAmount': serializer.toJson<double>(limitAmount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Budget copyWith({
    String? id,
    int? year,
    int? month,
    double? limitAmount,
    DateTime? createdAt,
  }) => Budget(
    id: id ?? this.id,
    year: year ?? this.year,
    month: month ?? this.month,
    limitAmount: limitAmount ?? this.limitAmount,
    createdAt: createdAt ?? this.createdAt,
  );
  Budget copyWithCompanion(BudgetsCompanion data) {
    return Budget(
      id: data.id.present ? data.id.value : this.id,
      year: data.year.present ? data.year.value : this.year,
      month: data.month.present ? data.month.value : this.month,
      limitAmount: data.limitAmount.present
          ? data.limitAmount.value
          : this.limitAmount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Budget(')
          ..write('id: $id, ')
          ..write('year: $year, ')
          ..write('month: $month, ')
          ..write('limitAmount: $limitAmount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, year, month, limitAmount, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Budget &&
          other.id == this.id &&
          other.year == this.year &&
          other.month == this.month &&
          other.limitAmount == this.limitAmount &&
          other.createdAt == this.createdAt);
}

class BudgetsCompanion extends UpdateCompanion<Budget> {
  final Value<String> id;
  final Value<int> year;
  final Value<int> month;
  final Value<double> limitAmount;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const BudgetsCompanion({
    this.id = const Value.absent(),
    this.year = const Value.absent(),
    this.month = const Value.absent(),
    this.limitAmount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BudgetsCompanion.insert({
    required String id,
    required int year,
    required int month,
    required double limitAmount,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       year = Value(year),
       month = Value(month),
       limitAmount = Value(limitAmount);
  static Insertable<Budget> custom({
    Expression<String>? id,
    Expression<int>? year,
    Expression<int>? month,
    Expression<double>? limitAmount,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (year != null) 'year': year,
      if (month != null) 'month': month,
      if (limitAmount != null) 'limit_amount': limitAmount,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BudgetsCompanion copyWith({
    Value<String>? id,
    Value<int>? year,
    Value<int>? month,
    Value<double>? limitAmount,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return BudgetsCompanion(
      id: id ?? this.id,
      year: year ?? this.year,
      month: month ?? this.month,
      limitAmount: limitAmount ?? this.limitAmount,
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
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (month.present) {
      map['month'] = Variable<int>(month.value);
    }
    if (limitAmount.present) {
      map['limit_amount'] = Variable<double>(limitAmount.value);
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
    return (StringBuffer('BudgetsCompanion(')
          ..write('id: $id, ')
          ..write('year: $year, ')
          ..write('month: $month, ')
          ..write('limitAmount: $limitAmount, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $PayeesTable payees = $PayeesTable(this);
  late final $BudgetsTable budgets = $BudgetsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    transactions,
    payees,
    budgets,
  ];
}

typedef $$TransactionsTableCreateCompanionBuilder =
    TransactionsCompanion Function({
      required String id,
      required String payeeUpiId,
      required String payeeName,
      required double amount,
      Value<String> currency,
      Value<String?> transactionNote,
      required String transactionRef,
      Value<String?> upiTxnId,
      Value<String?> approvalRefNo,
      Value<String?> responseCode,
      Value<String> status,
      required String paymentMode,
      Value<String?> qrType,
      Value<String?> upiApp,
      Value<String?> upiAppName,
      Value<String> category,
<<<<<<< HEAD
      Value<String> direction,
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$TransactionsTableUpdateCompanionBuilder =
    TransactionsCompanion Function({
      Value<String> id,
      Value<String> payeeUpiId,
      Value<String> payeeName,
      Value<double> amount,
      Value<String> currency,
      Value<String?> transactionNote,
      Value<String> transactionRef,
      Value<String?> upiTxnId,
      Value<String?> approvalRefNo,
      Value<String?> responseCode,
      Value<String> status,
      Value<String> paymentMode,
      Value<String?> qrType,
      Value<String?> upiApp,
      Value<String?> upiAppName,
      Value<String> category,
<<<<<<< HEAD
      Value<String> direction,
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
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

  ColumnFilters<String> get payeeUpiId => $composableBuilder(
    column: $table.payeeUpiId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payeeName => $composableBuilder(
    column: $table.payeeName,
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

  ColumnFilters<String> get transactionNote => $composableBuilder(
    column: $table.transactionNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transactionRef => $composableBuilder(
    column: $table.transactionRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get upiTxnId => $composableBuilder(
    column: $table.upiTxnId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get approvalRefNo => $composableBuilder(
    column: $table.approvalRefNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get responseCode => $composableBuilder(
    column: $table.responseCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentMode => $composableBuilder(
    column: $table.paymentMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get qrType => $composableBuilder(
    column: $table.qrType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get upiApp => $composableBuilder(
    column: $table.upiApp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get upiAppName => $composableBuilder(
    column: $table.upiAppName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

<<<<<<< HEAD
  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
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

  ColumnOrderings<String> get payeeUpiId => $composableBuilder(
    column: $table.payeeUpiId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payeeName => $composableBuilder(
    column: $table.payeeName,
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

  ColumnOrderings<String> get transactionNote => $composableBuilder(
    column: $table.transactionNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transactionRef => $composableBuilder(
    column: $table.transactionRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get upiTxnId => $composableBuilder(
    column: $table.upiTxnId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get approvalRefNo => $composableBuilder(
    column: $table.approvalRefNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get responseCode => $composableBuilder(
    column: $table.responseCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentMode => $composableBuilder(
    column: $table.paymentMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get qrType => $composableBuilder(
    column: $table.qrType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get upiApp => $composableBuilder(
    column: $table.upiApp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get upiAppName => $composableBuilder(
    column: $table.upiAppName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

<<<<<<< HEAD
  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get payeeUpiId => $composableBuilder(
    column: $table.payeeUpiId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payeeName =>
      $composableBuilder(column: $table.payeeName, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get transactionNote => $composableBuilder(
    column: $table.transactionNote,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transactionRef => $composableBuilder(
    column: $table.transactionRef,
    builder: (column) => column,
  );

  GeneratedColumn<String> get upiTxnId =>
      $composableBuilder(column: $table.upiTxnId, builder: (column) => column);

  GeneratedColumn<String> get approvalRefNo => $composableBuilder(
    column: $table.approvalRefNo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get responseCode => $composableBuilder(
    column: $table.responseCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get paymentMode => $composableBuilder(
    column: $table.paymentMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get qrType =>
      $composableBuilder(column: $table.qrType, builder: (column) => column);

  GeneratedColumn<String> get upiApp =>
      $composableBuilder(column: $table.upiApp, builder: (column) => column);

  GeneratedColumn<String> get upiAppName => $composableBuilder(
    column: $table.upiAppName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

<<<<<<< HEAD
  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionsTable,
          Transaction,
          $$TransactionsTableFilterComposer,
          $$TransactionsTableOrderingComposer,
          $$TransactionsTableAnnotationComposer,
          $$TransactionsTableCreateCompanionBuilder,
          $$TransactionsTableUpdateCompanionBuilder,
          (
            Transaction,
            BaseReferences<_$AppDatabase, $TransactionsTable, Transaction>,
          ),
          Transaction,
          PrefetchHooks Function()
        > {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> payeeUpiId = const Value.absent(),
                Value<String> payeeName = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String?> transactionNote = const Value.absent(),
                Value<String> transactionRef = const Value.absent(),
                Value<String?> upiTxnId = const Value.absent(),
                Value<String?> approvalRefNo = const Value.absent(),
                Value<String?> responseCode = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> paymentMode = const Value.absent(),
                Value<String?> qrType = const Value.absent(),
                Value<String?> upiApp = const Value.absent(),
                Value<String?> upiAppName = const Value.absent(),
                Value<String> category = const Value.absent(),
<<<<<<< HEAD
                Value<String> direction = const Value.absent(),
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                payeeUpiId: payeeUpiId,
                payeeName: payeeName,
                amount: amount,
                currency: currency,
                transactionNote: transactionNote,
                transactionRef: transactionRef,
                upiTxnId: upiTxnId,
                approvalRefNo: approvalRefNo,
                responseCode: responseCode,
                status: status,
                paymentMode: paymentMode,
                qrType: qrType,
                upiApp: upiApp,
                upiAppName: upiAppName,
                category: category,
<<<<<<< HEAD
                direction: direction,
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String payeeUpiId,
                required String payeeName,
                required double amount,
                Value<String> currency = const Value.absent(),
                Value<String?> transactionNote = const Value.absent(),
                required String transactionRef,
                Value<String?> upiTxnId = const Value.absent(),
                Value<String?> approvalRefNo = const Value.absent(),
                Value<String?> responseCode = const Value.absent(),
                Value<String> status = const Value.absent(),
                required String paymentMode,
                Value<String?> qrType = const Value.absent(),
                Value<String?> upiApp = const Value.absent(),
                Value<String?> upiAppName = const Value.absent(),
                Value<String> category = const Value.absent(),
<<<<<<< HEAD
                Value<String> direction = const Value.absent(),
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                payeeUpiId: payeeUpiId,
                payeeName: payeeName,
                amount: amount,
                currency: currency,
                transactionNote: transactionNote,
                transactionRef: transactionRef,
                upiTxnId: upiTxnId,
                approvalRefNo: approvalRefNo,
                responseCode: responseCode,
                status: status,
                paymentMode: paymentMode,
                qrType: qrType,
                upiApp: upiApp,
                upiAppName: upiAppName,
                category: category,
<<<<<<< HEAD
                direction: direction,
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionsTable,
      Transaction,
      $$TransactionsTableFilterComposer,
      $$TransactionsTableOrderingComposer,
      $$TransactionsTableAnnotationComposer,
      $$TransactionsTableCreateCompanionBuilder,
      $$TransactionsTableUpdateCompanionBuilder,
      (
        Transaction,
        BaseReferences<_$AppDatabase, $TransactionsTable, Transaction>,
      ),
      Transaction,
      PrefetchHooks Function()
    >;
typedef $$PayeesTableCreateCompanionBuilder =
    PayeesCompanion Function({
      required String id,
      required String upiId,
      required String name,
      Value<String?> phone,
      Value<int> transactionCount,
      Value<DateTime?> lastPaidAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$PayeesTableUpdateCompanionBuilder =
    PayeesCompanion Function({
      Value<String> id,
      Value<String> upiId,
      Value<String> name,
      Value<String?> phone,
      Value<int> transactionCount,
      Value<DateTime?> lastPaidAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$PayeesTableFilterComposer
    extends Composer<_$AppDatabase, $PayeesTable> {
  $$PayeesTableFilterComposer({
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

  ColumnFilters<String> get upiId => $composableBuilder(
    column: $table.upiId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get transactionCount => $composableBuilder(
    column: $table.transactionCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPaidAt => $composableBuilder(
    column: $table.lastPaidAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PayeesTableOrderingComposer
    extends Composer<_$AppDatabase, $PayeesTable> {
  $$PayeesTableOrderingComposer({
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

  ColumnOrderings<String> get upiId => $composableBuilder(
    column: $table.upiId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get transactionCount => $composableBuilder(
    column: $table.transactionCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPaidAt => $composableBuilder(
    column: $table.lastPaidAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PayeesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PayeesTable> {
  $$PayeesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get upiId =>
      $composableBuilder(column: $table.upiId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<int> get transactionCount => $composableBuilder(
    column: $table.transactionCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastPaidAt => $composableBuilder(
    column: $table.lastPaidAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PayeesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PayeesTable,
          Payee,
          $$PayeesTableFilterComposer,
          $$PayeesTableOrderingComposer,
          $$PayeesTableAnnotationComposer,
          $$PayeesTableCreateCompanionBuilder,
          $$PayeesTableUpdateCompanionBuilder,
          (Payee, BaseReferences<_$AppDatabase, $PayeesTable, Payee>),
          Payee,
          PrefetchHooks Function()
        > {
  $$PayeesTableTableManager(_$AppDatabase db, $PayeesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PayeesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PayeesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PayeesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> upiId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<int> transactionCount = const Value.absent(),
                Value<DateTime?> lastPaidAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PayeesCompanion(
                id: id,
                upiId: upiId,
                name: name,
                phone: phone,
                transactionCount: transactionCount,
                lastPaidAt: lastPaidAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String upiId,
                required String name,
                Value<String?> phone = const Value.absent(),
                Value<int> transactionCount = const Value.absent(),
                Value<DateTime?> lastPaidAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PayeesCompanion.insert(
                id: id,
                upiId: upiId,
                name: name,
                phone: phone,
                transactionCount: transactionCount,
                lastPaidAt: lastPaidAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PayeesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PayeesTable,
      Payee,
      $$PayeesTableFilterComposer,
      $$PayeesTableOrderingComposer,
      $$PayeesTableAnnotationComposer,
      $$PayeesTableCreateCompanionBuilder,
      $$PayeesTableUpdateCompanionBuilder,
      (Payee, BaseReferences<_$AppDatabase, $PayeesTable, Payee>),
      Payee,
      PrefetchHooks Function()
    >;
typedef $$BudgetsTableCreateCompanionBuilder =
    BudgetsCompanion Function({
      required String id,
      required int year,
      required int month,
      required double limitAmount,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$BudgetsTableUpdateCompanionBuilder =
    BudgetsCompanion Function({
      Value<String> id,
      Value<int> year,
      Value<int> month,
      Value<double> limitAmount,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$BudgetsTableFilterComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableFilterComposer({
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

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get limitAmount => $composableBuilder(
    column: $table.limitAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BudgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableOrderingComposer({
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

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get limitAmount => $composableBuilder(
    column: $table.limitAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BudgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<double> get limitAmount => $composableBuilder(
    column: $table.limitAmount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BudgetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BudgetsTable,
          Budget,
          $$BudgetsTableFilterComposer,
          $$BudgetsTableOrderingComposer,
          $$BudgetsTableAnnotationComposer,
          $$BudgetsTableCreateCompanionBuilder,
          $$BudgetsTableUpdateCompanionBuilder,
          (Budget, BaseReferences<_$AppDatabase, $BudgetsTable, Budget>),
          Budget,
          PrefetchHooks Function()
        > {
  $$BudgetsTableTableManager(_$AppDatabase db, $BudgetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> year = const Value.absent(),
                Value<int> month = const Value.absent(),
                Value<double> limitAmount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetsCompanion(
                id: id,
                year: year,
                month: month,
                limitAmount: limitAmount,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int year,
                required int month,
                required double limitAmount,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetsCompanion.insert(
                id: id,
                year: year,
                month: month,
                limitAmount: limitAmount,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BudgetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BudgetsTable,
      Budget,
      $$BudgetsTableFilterComposer,
      $$BudgetsTableOrderingComposer,
      $$BudgetsTableAnnotationComposer,
      $$BudgetsTableCreateCompanionBuilder,
      $$BudgetsTableUpdateCompanionBuilder,
      (Budget, BaseReferences<_$AppDatabase, $BudgetsTable, Budget>),
      Budget,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$PayeesTableTableManager get payees =>
      $$PayeesTableTableManager(_db, _db.payees);
  $$BudgetsTableTableManager get budgets =>
      $$BudgetsTableTableManager(_db, _db.budgets);
}
