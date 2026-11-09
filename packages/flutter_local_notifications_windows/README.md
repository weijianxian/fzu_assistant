# Local Windows notification plugin

This is `flutter_local_notifications_windows` 4.0.0, included under its
original license. The app overrides the transitive package with this copy so
that C++ exceptions from notification registration and delivery cannot unwind
across Dart FFI and terminate the Windows process. Initialization and delivery
return failure to Dart; cancellation reports failure instead of silently
succeeding.

When upgrading the upstream package, carry these FFI boundary changes forward
and regenerate `lib/src/ffi/bindings.dart` if the native API changes.
