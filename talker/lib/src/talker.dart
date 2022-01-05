import 'dart:async';

import 'package:talker/talker.dart';
import 'package:talker_error_handler/talker_error_handler.dart';

class Talker implements TalkerInterface {
  Talker._() {
    _settings = kDefaultTalkerSettings;
  }

  static final _talker = Talker._();
  static Talker get instance => _talker;

  TalkerObserversManager? _observersManager;
  late TalkerSettings _settings;

  final _fileManager = FileManager();
  final _history = <TalkerDataInterface>[];

  late final _logger = TalkerLogger();
  late final _errorHandler = ErrorHandler()
    ..stream.listen((details) {
      TalkerDataInterface? data;
      final err = details.error;
      final exception = details.exception;
      if (err != null) {
        data = TalkerError(
          err,
          message: details.message,
          stackTrace: details.stackTrace,
          logLevel: details.errorLevel?.loglevel ?? LogLevel.error,
        );
      } else if (exception != null) {
        data = TalkerException(
          exception,
          message: details.message,
          stackTrace: details.stackTrace,
          logLevel: details.errorLevel?.loglevel ?? LogLevel.error,
        );
      }

      if (data != null) {
        _talkerStreamController.add(data);
        _handleForOutputs(data);
        _logger.log(
          data.generateTextMessage(),
          logLevel: data.logLevel ?? LogLevel.debug,
        );
      }
    });

  final _talkerStreamController =
      StreamController<TalkerDataInterface>.broadcast();

  @override
  Stream<TalkerDataInterface> get stream =>
      _talkerStreamController.stream.asBroadcastStream();

  @override
  List<TalkerDataInterface> get history => _history;

  @override
  Future<void> configure({
    TalkerSettings? settings,
    List<TalkerObserver>? observers,
  }) async {
    if (settings != null) {
      _settings = settings;
    }

    if (observers != null && observers.isNotEmpty) {
      _observersManager = TalkerObserversManager(observers);
    }
  }

  @override
  void handle(
    String msg, [
    Object? exception,
    StackTrace? stackTrace,
    ErrorLevel? errorLevel,
  ]) {
    final container = _errorHandler.handle(
      msg,
      exception,
      stackTrace,
      errorLevel,
    );
    if (container != null) {
      _observersManager?.onError(container);
    }
  }

  @override
  void handleError(
    String msg, [
    Error? error,
    StackTrace? stackTrace,
    ErrorLevel? errorLevel,
  ]) {
    final errContainer =
        _errorHandler.handleError(msg, error, stackTrace, errorLevel);
    _observersManager?.onError(errContainer);
  }

  @override
  void handleException(
    String msg, [
    Exception? exception,
    StackTrace? stackTrace,
    ErrorLevel? errorLevel,
  ]) {
    final errContainer =
        _errorHandler.handleException(msg, exception, stackTrace, errorLevel);
    _observersManager?.onError(errContainer);
  }

  @override
  void log(
    String message,
    LogLevel logLevel, {
    Map<String, dynamic>? additional,
  }) {
    final logData = TalkerLog(
      message,
      logLevel: logLevel,
      additional: additional,
    );
    _talkerStreamController.add(logData);
    _observersManager?.onLog(logData);
    _handleForOutputs(logData);
    _logger.log(
      logData.generateTextMessage(),
      logLevel: logData.logLevel ?? LogLevel.debug,
    );
  }

  @override
  void cleanHistory() {
    if (_settings.useHistory) {
      _history.clear();
    }
  }

  void _handleForOutputs(TalkerDataInterface data) {
    _writeToHistory(data);
    _writeToFile(data);
  }

  void _writeToFile(TalkerDataInterface data) {
    if (_settings.writeToFile) {
      _fileManager.writeToLogFile(data.generateTextMessage());
    }
  }

  void _writeToHistory(TalkerDataInterface data) {
    if (_settings.useHistory) {
      if (_settings.maxHistoryItems <= _history.length) {
        _history.removeAt(0);
      }
      _history.add(data);
    }
  }
}
