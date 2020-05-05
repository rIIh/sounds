import 'dart:async';

import 'package:flutter/material.dart';

import '../android/android_encoder.dart';
import '../recording_disposition.dart';
import '../sound_recorder.dart';
import '../track.dart';
import '../util/ansi_color.dart';
import '../util/log.dart';
import '../util/recorded_audio.dart';
import 'recorder_playback_controller.dart' as controller;

typedef OnStart = void Function();
typedef OnProgress = void Function(RecordedAudio media);
typedef OnStop = void Function(RecordedAudio media);

/// The [requestPermissions] callback allows you to provide an
/// UI informing the user that we are about to ask for a permission.
///
typedef UIRequestPermission = Future<bool> Function(
    BuildContext context, Track track);

/// A UI for recording audio.
class SoundRecorderUI extends StatefulWidget {
  /// Callback to be notified when the recording stops
  final OnStop onStopped;

  /// Callback to be notified when the recording starts.
  final OnStart onStart;

  /// Stores and Tracks the recorded audio.
  final RecordedAudio audio;

  /// The [requestPermissions] callback allows you to request
  /// the necessary permissions to record a track.
  ///
  /// If [requestPermissions] is null then no permission checks
  /// will be performed.
  ///
  /// It is sometimes useful to explain to the user why we are asking
  /// for permission before showing the OSs permission request.
  /// This callback gives you the opportunity to display a suitable
  /// notice and then request permissions.
  ///
  /// Return [true] to indicate that the user has given permission
  /// to record and that you have made the necessary calls to
  /// grant those permissions.
  ///
  /// If [true] is returned the recording will proceed.
  /// If [false] is returned then recording will not start.
  ///
  /// This method will be called even if we have the necessary permissions
  /// as we make no checks.
  ///
  final UIRequestPermission requestPermissions;

  ///
  /// Records audio from the users microphone into the given media file.
  ///
  /// The user is presented with a UI that allows them to start/stop recording
  /// and provides some basic feed back on the volume as the recording
  ///  progresses.
  ///
  /// The [track] specifies the file we are recording to.
  /// At the moment the [track] must be constructued using [Track.fromPath] as
  /// recording to a databuffer is not currently supported.
  ///
  /// The [onStart] callback is called user starts recording. This method will
  /// be called each time the user clicks the 'record' button.
  ///
  /// The [onStopped] callback is called when the user stops recording. This
  /// method will be each time the user clicks the 'stop' button. It can
  /// also be called if the [stop] method is called.
  ///
  /// The [requestPermissions] callback allows you to request
  /// permissions just before they are required and if desired
  /// display your own dialog explaining why the permissions are required.
  ///
  /// If you do not provide [requestPermissions] then you must ensure
  /// that all required permissions are granted before the
  /// [SoundRecorderUI] widgets starts recording.
  ///
  ///
  /// ```dart
  ///   SoundRecorderIU(track,
  ///       informUser: (context, track)
  ///           {
  ///               // psuedo code
  ///               String reason;
  ///               if (!microphonePermission.granted)
  ///                 reason += 'please allow microphone';
  ///               if (!requestingStoragePermission.granted)
  ///                 reason += 'please allow storage';
  ///               if (Dialog.show(reason) == Dialog.OK)
  ///               {
  ///                 microphonePermission.request == granted;
  ///                 storagePermission.request == granted;
  ///                 return true;
  ///               }
  ///
  ///           });
  ///
  /// ```
  SoundRecorderUI(
    Track track, {
    this.onStart,
    this.onStopped,
    this.requestPermissions,
    Key key,
  })  : audio = RecordedAudio.toTrack(track),
        super(key: key);

  @override
  State<StatefulWidget> createState() {
    return SoundRecorderUIState();
  }
}

///
class SoundRecorderUIState extends State<SoundRecorderUI> {
  bool _isRecording = false;

  SoundRecorder _recorder;

  ///
  SoundRecorderUIState() {
    _recorder = SoundRecorder();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    controller.registerRecorder(context, this);
    return _buildButtons();
  }

  Widget _buildButtons() {
    return Column(
      children: <Widget>[
        _buildMicrophone(),
        _buildStopButton(),
      ],
    );
  }

  ///
  Stream<RecordingDisposition> get dispositionStream =>
      _recorder.dispositionStream();

  static const _minDbCircle = 55;

  Widget _buildMicrophone() {
    return SizedBox(
        height: 120,
        width: 120,
        child: StreamBuilder<RecordingDisposition>(
            stream: _recorder.dispositionStream(),
            initialData: RecordingDisposition.zero(), // was START_DECIBELS
            builder: (_, streamData) {
              var disposition = streamData.data;
              var min = _minDbCircle;
              if (disposition.decibels == 0) min = 0;
              //      onRecorderProgress(context, this, disposition.duration);
              return Stack(alignment: Alignment.center, children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 20),
                  // + MIN_DB_CIRCLE so the animated circle is always a
                  // reasonable size (db ranges is typically 45 - 80db)
                  width: disposition.decibels + min,
                  height: disposition.decibels + min,
                  constraints: BoxConstraints(
                      maxHeight: 80.0 + min, maxWidth: 80.0 + min),
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: Colors.red),
                ),
                InkWell(onTap: _onRecord, child: Icon(Icons.mic, size: 60))
              ]);
            }));
  }

  Widget _buildStopButton() {
    return InkWell(
        onTap: _recorder.isRecording ? stop : _onRecord,
        child: Icon(
          _recorder.isRecording ? Icons.stop : Icons.play_circle_filled,
          size: 60,
          color: Colors.red,
        ));
  }

  void dispose() {
    _stop();
    super.dispose();
  }

  void _onRecord() {
    if (!_isRecording) {
      _requestPermission(context, widget.audio.track).then((accepted) async {
        if (accepted) {
          Log.e(green('started Recording to: '
              '${await (await widget.audio).track.identity})'));
          await _recorder.record(widget.audio.track,
              androidEncoder: AndroidEncoder.amrWbCodec);

          Log.d(widget.audio.track.identity);

          _isRecording = true;
          setState(() {});

          Log.d(green('started Recording to: '
              '${await (await widget.audio).track.identity})'));

          if (widget.onStart != null) {
            widget.onStart();
          }

          controller.onRecordingStarted(context);
        }
      });
    }
  }

  /// The [stop] methods stops the recording and calls
  /// the [onStopped] callback.
  ///
  void stop() {
    _stop();
    setState(() {});
  }

  void _stop() {
    if (_recorder.isRecording) {
      _isRecording = false;
      _recorder.stop().then<void>((_) async {
        // cause the  player to pick up the newly recorded file.
        setState(() {
          _updateDuration(_recorder.duration);

          if (widget.onStopped != null) {
            widget.onStopped(widget.audio);
          }

          controller.onRecordingStopped(context, _recorder.duration);
        });
      });
    }
  }

  /// as recording progresses we update the media's duration.
  void _updateDuration(Duration duration) {
    widget.audio.duration = _recorder.duration;
  }

  /// If requried displays the OSs permission UI to request
  /// permissions required for recording.
  ///
  Future<bool> _requestPermission(BuildContext context, Track track) async {
    var requesting = Completer<bool>();

    Future<bool> request;

    if (widget.requestPermissions != null) {
      /// ask the user before we actually ask the OS so
      /// the dev has a chance to inform the user as to why we need
      /// permissions.
      request = widget.requestPermissions(context, track);
    } else {
      request = Future.value(true);
    }

    request.then((granted) async {
      requesting.complete(granted);
    }).catchError((Object error) {
      Log.e("Error occured requesting permissions: $error");
      requesting.completeError(error);
    });

    return requesting.future;
  }
}
