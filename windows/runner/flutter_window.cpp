#include "flutter_window.h"

#include <optional>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  // Only the app-owned Qwen child joins this job. Closing or crashing the app
  // releases the job handle and stops inference; unrelated processes are safe.
  qwen_job_ = CreateJobObjectW(nullptr, nullptr);
  if (qwen_job_) {
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if (!SetInformationJobObject(qwen_job_, JobObjectExtendedLimitInformation,
                                 &limits, sizeof(limits))) {
      CloseHandle(qwen_job_);
      qwen_job_ = nullptr;
    }
  }
  qwen_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "voc_mate/qwen_process",
      &flutter::StandardMethodCodec::GetInstance());
  qwen_channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() != "attach") {
      result->NotImplemented();
      return;
    }
    const auto* value = call.arguments();
    int64_t pid = 0;
    if (value) {
      if (const auto* small = std::get_if<int32_t>(value)) pid = *small;
      if (const auto* large = std::get_if<int64_t>(value)) pid = *large;
    }
    bool attached = false;
    if (qwen_job_ && pid > 0 && pid <= MAXDWORD) {
      HANDLE child = OpenProcess(PROCESS_SET_QUOTA | PROCESS_TERMINATE,
                                 FALSE, static_cast<DWORD>(pid));
      if (child) {
        attached = AssignProcessToJobObject(qwen_job_, child) != FALSE;
        CloseHandle(child);
      }
    }
    result->Success(flutter::EncodableValue(attached));
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  qwen_channel_ = nullptr;
  if (qwen_job_) {
    CloseHandle(qwen_job_);
    qwen_job_ = nullptr;
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

