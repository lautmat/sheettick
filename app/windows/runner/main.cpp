#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr const wchar_t kInstanceMutex[] =
    L"Local\\com.lmathieu.sheettick.single-instance";
constexpr const wchar_t kWindowClass[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr const wchar_t kWindowTitle[] = L"sheettick";

// Brings the running copy's window forward, even when it is hidden in the tray.
void ShowRunningInstance() {
  HWND window = ::FindWindowW(kWindowClass, kWindowTitle);
  if (window == nullptr) return;
  ::ShowWindow(window, ::IsIconic(window) ? SW_RESTORE : SW_SHOW);
  ::SetForegroundWindow(window);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // One copy per Windows user: copies would share the database, sync and
  // reminders. Windows releases the mutex when this process ends, even after a
  // crash. If it cannot be created, the app still starts.
  HANDLE instance_mutex = ::CreateMutexW(nullptr, FALSE, kInstanceMutex);
  if (instance_mutex != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    // A launch at Windows sign-in must not pop up a window.
    if (::wcsstr(command_line, L"--minimized") == nullptr) {
      ShowRunningInstance();
    }
    ::CloseHandle(instance_mutex);
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"sheettick", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
