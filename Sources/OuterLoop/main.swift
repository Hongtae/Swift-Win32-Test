// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import WinSDK


makeWindow()

Task { @MainActor in
    var count = 0
    var lastUpdate = Date.now

    while true {
        // This loop stops when the window enters a modal state, until the modal state exits!
        count += 1
        let now = Date.now
        let interval = now.timeIntervalSince(lastUpdate)
        lastUpdate = now

        print("Running main loop... (count: \(count), interval: \(interval) seconds)")

        do {
            // Simulate some work in the main loop
            try await Task.sleep(for: .milliseconds(200))
        } catch {
            print("Error in main loop: \(error)")
            break
        }
    }
}

let timerProc: TIMERPROC = { (_: HWND?, elapse: UINT, timerId: UINT_PTR, _: DWORD) in
    processRunLoop()
}
SetTimer(nil, 0, UINT(USER_TIMER_MINIMUM), timerProc)

var msg = MSG()
mainLoop: while true {
    while PeekMessageW(&msg, nil, 0, 0, UINT(PM_REMOVE)) {
        if msg.message == UINT(WM_QUIT) {
            break mainLoop
        }
        TranslateMessage(&msg)
        DispatchMessageW(&msg)
    }
    processRunLoop()
    WaitMessage()
}

func processRunLoop() {
    while true {
        let next = RunLoop.main.limitDate(forMode: .default)
        let s = next?.timeIntervalSinceNow ?? 1.0
        if s > 0.0 {
            break
        }
    }
}

func makeWindow() {
    OleInitialize(nil)

    let windowClass = "MyWindowClass"
    let atom: ATOM? = windowClass.withCString(encodedAs: UTF16.self) {
        className in

        let IDC_ARROW: UnsafePointer<WCHAR> = UnsafePointer<WCHAR>(bitPattern: 32512)!
        let IDI_APPLICATION: UnsafePointer<WCHAR> = UnsafePointer<WCHAR>(bitPattern: 32512)!

        var wc = WNDCLASSEXW(
            cbSize: UINT(MemoryLayout<WNDCLASSEXW>.size),
            style: UINT(CS_OWNDC),
            lpfnWndProc: { (hWnd, uMsg, wParam, lParam) -> LRESULT in windowProc(hWnd, uMsg, wParam, lParam) },
            cbClsExtra: 0,
            cbWndExtra: 0,
            hInstance: GetModuleHandleW(nil),
            hIcon: LoadIconW(nil, IDI_APPLICATION),
            hCursor: LoadCursorW(nil, IDC_ARROW),
            hbrBackground: HBRUSH(bitPattern: Int(COLOR_WINDOW + 1)),
            lpszMenuName: nil,
            lpszClassName: className,
            hIconSm: nil)

        return RegisterClassExW(&wc)
    }
    assert(atom != nil, "RegisterClassExW failed.")

    let dwStyle = DWORD(WS_OVERLAPPEDWINDOW)
    let dwStyleEx: DWORD = 0
    let name = "WindowTest (Drag me with the mouse for a long enough time.)"

    let hWnd = name.withCString(encodedAs: UTF16.self) { title in
        windowClass.withCString(encodedAs: UTF16.self) { className in
            CreateWindowExW(dwStyleEx, className, title, dwStyle,
                CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
            nil, nil, GetModuleHandleW(nil), nil)
        }
    }
    assert(hWnd != nil, "CreateWindowExW failed.")

    ShowWindow(hWnd, SW_SHOW)
    SetActiveWindow(hWnd)
}

func windowProc(_ hWnd: HWND?, _ uMsg: UINT, _ wParam: WPARAM, _ lParam: LPARAM) -> LRESULT {
    switch uMsg {
    case UINT(WM_DESTROY):
        PostQuitMessage(0)
        Task { @MainActor in
            exit(0)
        }
        return 0
    case UINT(WM_PAINT):
        var ps = PAINTSTRUCT()
        BeginPaint(hWnd, &ps)
        EndPaint(hWnd, &ps)
        return 0
    default:
        break
    }
    return DefWindowProcW(hWnd, uMsg, wParam, lParam)
}
