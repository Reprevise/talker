import 'dart:async';

import 'package:talker/talker.dart';
import 'package:talker_error_handler_core/talker_error_handler_core.dart';

class Talker implements TalkerInterface {
  Talker._();

  static final _talker = Talker._();
  static Talker get instance => _talker;

  late final _errorHandler = ErrorHandler()
    ..stream.listen((err) {
      _talkerStreamController.add(
        TalkerDataContainer(
          err.message,
          exception: err.exception,
          error: err.error,
          stackTrace: err.stackTrace,
          logLevel: err.errorLevel.loglevel,
        ),
      );
    });

  final _talkerStreamController =
      StreamController<TalkerDataInterface>.broadcast();

  @override
  Stream<TalkerDataInterface> get stream =>
      _talkerStreamController.stream.asBroadcastStream();

  TalkerObserversManager? _observersManager;

  void configure({List<TalkerObserver>? observers}) {
    if (observers != null && observers.isNotEmpty) {
      _observersManager = TalkerObserversManager(observers);
    }
  }

  @override
  void handle(ErrorContainer container) => _errorHandler.handle(container);

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
    final logData = TalkerDataContainer(
      message,
      logLevel: logLevel,
      additional: additional,
    );
    _talkerStreamController.add(logData);
    _observersManager?.onLog(logData);
  }
}
