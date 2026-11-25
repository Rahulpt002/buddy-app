import 'dart:async';

/// `ptr` frames from the agent (the laptop's mouse while it's on the phone):
/// {"k": "enter"|"move"|"down"|"up"|"scroll"|"leave", "x": 0..1, "y": 0..1, "dy": px}.
/// The controller adds them; [RemoteCursor] (lib/ui/remote_cursor.dart) draws and acts on them.
final remotePointer = StreamController<Map<String, dynamic>>.broadcast();
